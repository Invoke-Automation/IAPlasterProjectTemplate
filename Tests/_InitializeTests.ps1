$ModuleName = '<%=$PLASTER_PARAM_ModuleName%>'
$TestsFolder = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $TestsFolder
$ModuleRoot = Join-Path $ProjectRoot $ModuleName

if(!(Get-Module $ModuleName)){
	Import-Module $ModuleRoot -Force
}
