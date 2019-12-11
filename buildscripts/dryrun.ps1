Param (
    [Parameter(Mandatory=$false,ValueFromPipeline=$true)] 
    [switch] $NoBuild
)

$root = $PSScriptRoot
if(!$root) {
    $root = Resolve-Path ".."
}

function Create-DefaultConfig ($RootPath) {

    $hostname = $(hostname)
    $sefilepath = $RootPath + "/Deployment/SiteEnvironment.$hostname.json"
    if(-not (Test-Path $sefilepath)) {
        Copy-Item "$RootPath/SiteEnvironment.json" $sefilepath
    }
    (Resolve-Path $sefilepath).Path
}

$sefilepath = Create-DefaultConfig -RootPath $root
$sedata =  Get-Content $sefilepath | ConvertFrom-Json
if(-not $sedata -or $sedata.DockerDC -match "#") {
    throw "Config not set, please update: $sefilepath"
}
$gitversionJson = $(gitversion)
$gitversion = $gitversionJson | ConvertFrom-Json
$imagefullname = "$($sedata.DOCKER_BASE_REGISTRY)/$($sedata.ApplicationDockerRepo)/$($sedata.ApplicationDockerImageName)"
$imagetag=$($gitversion.LegacySemVerPadded)
$imagefullnametag = "$($imagefullname):$imagetag"

if(-not $NoBuild) {
    .\build.ps1 -target buildpackage
}

$successfulTag=$(docker image ls --filter "reference=$imagefullnametag" -q)
if($successfulTag) {
    Write-Information "Got a successfully tagged image, let's use it: $imagefullnametag"
    $env:BUILD_TAG = $imagetag
} else {
    Write-Error "Expected image tagged with full path: $imagefullnametag"
    throw "Build did not tag expected version, please confirm successful build and tag (do a build and check for errors / confirm docker images tags)"
}

# Grab version, use BUILD_TAG?
Push-Location

./Deployment/dopostdeploy.ps1 -SiteEnvFile $sefilepath

Pop-Location

