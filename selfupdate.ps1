# This script is part of the Cake bootstrapper
# To run this script from the web:
# $GithubApiToken = $env:GITHUB_API_TOKEN
# $authheaders = @{ Authorization = "token $GithubApiToken"; Accept="application/vnd.github.v3.raw"}
# $SelfUpdateUri = "https://api.github.com/repos/PowerFarmingNZ/PowerShell-BuildTools/contents/Bootstrap/selfupdate.ps1"
# Invoke-WebRequest -Uri $SelfUpdateUri -OutFile ".\selfupdate.ps1" -Headers $authheaders
# .\selfupdate.ps1

$GithubApiToken = $env:GITHUB_API_TOKEN
$owner = "PowerFarmingNZ"
$repo = "PowerShell-BuildTools"
$SelfUpdateBaseUri = "https://api.github.com/repos/$owner/$repo/contents"
$authheaders = @{ Authorization = "token $GithubApiToken"; Accept="application/vnd.github.v3.raw"}

#Log in test
# $authheaders = @{ Authorization = "token $GithubApiToken"; Accept="application/vnd.github.v3.raw"}
# $testauth = Invoke-WebRequest -Uri $SelfUpdateBaseUri -Headers $authheaders
# $files = ConvertFrom-Json $testauth.Content
# $files | ?{ $_.url -match "boot" }
# $testauth = Invoke-WebRequest -Uri "$($SelfUpdateBaseUri)/Bootstrap/" -Headers $authheaders
# $files = ConvertFrom-Json $testauth.Content

# Bootstrap cake files also
if(!(Test-Path ./build.cake)) 
{
    $SelfUpdateUri = "$($SelfUpdateBaseUri)/Bootstrap/build.cake"
    Invoke-WebRequest -Uri $SelfUpdateUri -OutFile ".\build.cake" -Headers $authheaders
}
if(!(Test-Path ./project.cake)) 
{
    $SelfUpdateUri = "$($SelfUpdateBaseUri)/Bootstrap/project.cake"
    Invoke-WebRequest -Uri $SelfUpdateUri -OutFile ".\project.cake" -Headers $authheaders
}

# Self-self-update, will be run next time the self update is called
$SelfUpdateUri = "$($SelfUpdateBaseUri)/Bootstrap/selfupdate.ps1"
Invoke-WebRequest -Uri $SelfUpdateUri -OutFile ".\selfupdate.user.ps1" -Headers $authheaders
if((Test-Path ".\selfupdate.user.ps1") -and (Get-Content .\selfupdate.user.ps1 | Select-String "Cake bootstrapper" -Quiet)) {
        Move-Item .\selfupdate.user.ps1 .\selfupdate.ps1 -force
} else {
    throw "There was a critical issue running the SelfUpdateBootstrap"
}

$SelfUpdateUri = "$($SelfUpdateBaseUri)/Bootstrap/build.ps1"
Write-Host "Bootstrapping"
Invoke-WebRequest -Uri $SelfUpdateUri -OutFile ".\build.ps1" -Headers $authheaders
