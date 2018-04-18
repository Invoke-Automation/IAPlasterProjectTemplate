Describe 'Meta Tests' {
    It 'Should have a correct Plaster Manifest' {
        {Test-PlasterManifest} | Should -Not -Throw
    }
}
