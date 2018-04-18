# Ensure everything works in the most strict mode.
Set-StrictMode -Version Latest

if ($env:APPVEYOR) {
	$RepoRoot = $env:APPVEYOR_BUILD_FOLDER
} else {
	$RepoRoot = $PSScriptRoot
}
$ModuleName = '<%=$PLASTER_PARAM_ModuleName%>'
$ModulePath = Join-Path $RepoRoot $ModuleName
$PublicFunctionsPath = Join-Path $ModulePath 'Public'
$DocsPath = Join-Path $RepoRoot 'docs'
$DocsLocale = 'en-US'
$ModuleManifestPath = Join-Path $ModulePath "$ModuleName.psd1"
$LocalBuildPath = Join-Path $RepoRoot 'build'

Add-BuildTask ShowAppVeyorDebug {
	Write-Build Gray
	Write-Build Gray ('Project name:               {0}' -f $env:APPVEYOR_PROJECT_NAME)
	Write-Build Gray ('Project root:               {0}' -f $env:APPVEYOR_BUILD_FOLDER)
	Write-Build Gray ('Repo name:                  {0}' -f $env:APPVEYOR_REPO_NAME)
	Write-Build Gray ('Branch:                     {0}' -f $env:APPVEYOR_REPO_BRANCH)
	Write-Build Gray ('Commit:                     {0}' -f $env:APPVEYOR_REPO_COMMIT)
	Write-Build Gray ('  - Author:                 {0}' -f $env:APPVEYOR_REPO_COMMIT_AUTHOR)
	Write-Build Gray ('  - Time:                   {0}' -f $env:APPVEYOR_REPO_COMMIT_TIMESTAMP)
	Write-Build Gray ('  - Message:                {0}' -f $env:APPVEYOR_REPO_COMMIT_MESSAGE)
	Write-Build Gray ('  - Extended message:       {0}' -f $env:APPVEYOR_REPO_COMMIT_MESSAGE_EXTENDED)
	Write-Build Gray ('Pull request number:        {0}' -f $env:APPVEYOR_PULL_REQUEST_NUMBER)
	Write-Build Gray ('Pull request title:         {0}' -f $env:APPVEYOR_PULL_REQUEST_TITLE)
	Write-Build Gray ('AppVeyor build ID:          {0}' -f $env:APPVEYOR_BUILD_ID)
	Write-Build Gray ('AppVeyor build number:      {0}' -f $env:APPVEYOR_BUILD_NUMBER)
	Write-Build Gray ('AppVeyor build version:     {0}' -f $env:APPVEYOR_BUILD_VERSION)
	Write-Build Gray ('AppVeyor job ID:            {0}' -f $env:APPVEYOR_JOB_ID)
	Write-Build Gray ('Build triggered from tag?   {0}' -f $env:APPVEYOR_REPO_TAG)
	Write-Build Gray ('  - Tag name:               {0}' -f $env:APPVEYOR_REPO_TAG_NAME)
	Write-Build Gray ('PowerShell version:         {0}' -f $PSVersionTable.PSVersion.ToString())
	Write-Build Gray
}

Add-BuildTask GetVersion {
	# Into dev increment build
	# Into release increment build
	# Into master don't increment build
	# Local don't
	if (Test-Path $ModuleManifestPath) {
		$manifest = Test-ModuleManifest -Path $ModuleManifestPath
		[System.Version]$version = $manifest.Version
		if ($env:APPVEYOR) {
			if (($env:APPVEYOR_REPO_BRANCH -like "release/*") -or ($env:APPVEYOR_REPO_BRANCH -like "dev*")) {
				# Write-Host "Old Version: $version"
				$env:version = New-Object -TypeName System.Version -ArgumentList ($version.Major, $version.Minor, ($version.Build + 1 ))
				# Write-Host "New Version: $env:version"
				Try {
					# Update the manifest with the new version value and fix the weird string replace bug
					$functionList = ((Get-ChildItem -Path $PublicFunctionsPath -Recurse -Filter "*.ps1").BaseName)
					Update-ModuleManifest -Path $ModuleManifestPath -ModuleVersion $env:version -FunctionsToExport $functionList
					(Get-Content -Path $ModuleManifestPath) -replace "PSGet_$ModuleName", "$ModuleName" | Set-Content -Path $ModuleManifestPath
					(Get-Content -Path $ModuleManifestPath) -replace 'NewManifest', "$ModuleName" | Set-Content -Path $ModuleManifestPath
					(Get-Content -Path $ModuleManifestPath) -replace 'FunctionsToExport = ', 'FunctionsToExport = @(' | Set-Content -Path $ModuleManifestPath -Force
					(Get-Content -Path $ModuleManifestPath) -replace "$($functionList[-1])'", "$($functionList[-1])')" | Set-Content -Path $ModuleManifestPath -Force
				} catch {
					throw $_
				}
				# Set AppVeyor version
				try {
					Update-AppveyorBuild -Version $env:version
				} catch {
					throw $_
				}
			}
		}
	} else {
		throw 'Versioning requires Module Manifest'
	}
}

Add-BuildTask PesterTests {
	try {
		$testResultsFile = "$RepoRoot\TestResult.xml"
		$result = Invoke-Pester -OutputFormat NUnitXml -OutputFile $testResultsFile -PassThru
		if ($env:APPVEYOR) {
			(New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)", (Resolve-Path $testResultsFile))
		}
		Remove-Item $testResultsFile -Force
		GetVersion ($result.FailedCount -eq 0) "$($result.FailedCount) Pester test(s) failed."
	} catch {
		throw
	}
}

Add-BuildTask UpdateDocs {
	# Check docs folder
	if (-not (Test-Path $DocsPath)){
		try{
			New-Item -Path $DocsPath -ItemType Directory
		} catch {
			throw 'could not create docs folder'
		}
	}
	# Check project structure
	if (-not ((Test-Path $DocsPath) -and (Test-Path $ModulePath))) {
		throw "Repository structure does not look OK"
	} else {
		if (Get-Module -ListAvailable -Name platyPS) {
			# Import modules
			Import-Module platyPS
			Import-Module $modulePath -Force

			# Generate markdown for new cmdlets
			New-MarkdownHelp -Module $ModuleName -OutputFolder $docsPath -Locale $DocsLocale -UseFullTypeName -ErrorAction SilentlyContinue | Out-Null
			# Update markdown for existing cmdlets
			Update-MarkdownHelp -Path $docsPath -UseFullTypeName | Out-Null
			# Generate external help
			New-ExternalHelp -Path $docsPath -OutputPath (Join-Path -Path $modulePath -ChildPath $DocsLocale) -Force | Out-Null
		} else {
			throw "You require the platyPS module to generate new documentation"
		}
	}
}

Add-BuildTask StandardBuild PesterTests, UpdateDocs

Add-BuildTask AppVeyorBuild -If ($env:APPVEYOR) StandardBuild

Add-BuildTask AppVeyorPublish -If ($env:APPVEYOR) {
	# Publish Module to PSGallery
	if($env:APPVEYOR_REPO_BRANCH -like 'master'){
		# Only the master branch gets published
		Try {
			Publish-Module -Path $ModulePath -NuGetApiKey $env:NuGetApiKey -ErrorAction 'Stop'
			Write-Host "$ModuleName PowerShell Module version $env:version published to the PowerShell Gallery." -ForegroundColor Cyan
		} Catch {
			Write-Warning "Publishing update $env:version to the PowerShell Gallery failed."
			throw $_
		}
	} else {
		Write-Host 'Only the master branch gets published' -ForegroundColor Cyan
	}
}

Add-BuildTask LocalBuild -If (!$env:APPVEYOR) StandardBuild, {
    $BuildFolderName = ('{0}\{1}' -f $ModuleName, (Test-ModuleManifest -Path $ModuleManifestPath).Version)
    $BuildFolderPath = (Join-Path $LocalBuildPath $BuildFolderName)
    if(Test-Path $BuildFolderPath) {
        Remove-Item $BuildFolderPath -Force -Recurse
    }
	$BuildFolder = New-Item -Path $LocalBuildPath -Name $BuildFolderName -ItemType Directory
	Copy-Item -Path (Join-Path $RepoRoot "$ModuleName\*") -Destination $BuildFolder -Recurse
}

Add-BuildTask LocalPublishToPSGallery -If (!$env:APPVEYOR) LocalBuild, {
	Publish-Module -Path $ModulePath -NuGetApiKey (Get-Content '.\PSGallery.secret')
}

Add-BuildTask . LocalBuild
