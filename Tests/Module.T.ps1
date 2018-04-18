. $PSScriptRoot\_InitializeTests.ps1

Describe 'Module Manifest Tests' {
    It 'Passes Test-ModuleManifest' {
        Test-ModuleManifest -Path $ModuleManifestPath | Should Not BeNullOrEmpty
        $? | Should Be $true
    }
}

Describe 'PSScriptAnalyzer Rules' -Tag 'Meta' {
	$analysis = Invoke-ScriptAnalyzer -Path $ProjectRoot -Recurse
	$scriptAnalyzerRules = Get-ScriptAnalyzerRule
	forEach ($rule in $scriptAnalyzerRules) {
		It "Should pass $rule" {
			If (($analysis) -and ($analysis.RuleName -contains $rule)) {
				$analysis | Where-Object RuleName -EQ $rule -OutVariable failures | Out-Default
				$failures.Count | Should Be 0
			}
		}
	}
}
