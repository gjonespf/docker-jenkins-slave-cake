param(
    [switch]$UseLocal,
    [string]$DefaultProjectTemplate = "docker-publicweb-template-v2",
    [string]$DefaultUrl = "https://github.com/PowerFarmingNZ/docker-publicweb-template-v2",
    $AllProjectBase = "../.."
    ) 

$pwd = $PSScriptRoot
if($AllProjectBase -match "\.") {
    $allBase = Resolve-Path "$pwd/$AllProjectBase"
} else {
    $allBase = Resolve-Path "$AllProjectBase"
}

Push-Location
$templatePath = "$allBase/$DefaultProjectTemplate"
if(!(Test-Path $templatePath)) {
    Write-Warning "Pulling missing template from ""$DefaultUrl"" using git"
    cd $allBase
}

$templateDir = Resolve-Path "$templatePath"
if(!(Test-Path $templateDir)) {
    throw "Getting latest teplate was unsuccessful"
} else {
    Write-Information "Running latest template update"
    cd $templateDir
    # TODO: Possibly work on system for pinning?
    git pull
    . $templateDir/buildscripts/do-template-update.ps1 $pwd
}

Pop-Location


