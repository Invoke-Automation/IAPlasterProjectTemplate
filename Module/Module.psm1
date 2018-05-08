# Load Module settings file
try {
	$script:SETTINGS = (Get-Content (Join-Path $PSScriptRoot 'Settings.json') | ConvertFrom-Json)
} catch {
	throw 'Could not load settings.json file.'
}

# Get public and private function defenition files.
# Sort to make sure files that start with '_' get loaded first
$Private = @(Get-ChildItem -Path $PSScriptRoot\Private -Recurse -Filter "*.ps1") | Sort-Object Name
$Public = @(Get-ChildItem -Path $PSScriptRoot\Public -Recurse -Filter "*.ps1") | Sort-Object Name

# Dots source the private files
foreach ($import in $Private) {
	try {
		. $import.fullName
		Write-Verbose -Message ("Imported private function {0}" -f $import.fullName)
	} catch {
		Write-Error -Message ("Failed to import private function {0}: {1}" -f $import.fullName, $_)
	}
}
# Dots source the public files
foreach ($import in $Public) {
	try {
		. $import.fullName
		Write-Verbose -Message ("Imported public function {0}" -f $import.fullName)
	} catch {
		Write-Error -Message ("Failed to import public function {0}: {1}" -f $import.fullName, $_)
	}
}

Export-ModuleMember -Function $Public.BaseName