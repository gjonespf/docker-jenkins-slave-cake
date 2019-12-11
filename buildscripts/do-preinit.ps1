#!/usr/bin/pwsh

#===============
# Functions
#===============
function Get-GitCurrentBranchVSTS {
    $currentBranch = ""
    if($env:BUILD_SOURCEBRANCHNAME) {
        Write-Host "Get-GitCurrentBranchVSTS - Got VSTS Source Branch: $($env:BUILD_SOURCEBRANCHNAME)"
        $currentBranch = $env:BUILD_SOURCEBRANCHNAME

        if($env:BUILD_SOURCEBRANCH) {
            $currentBranch = $env:BUILD_SOURCEBRANCH.substring($env:BUILD_SOURCEBRANCH.indexOf('/', 5) + 1)
            Write-Host "Get-GitCurrentBranchVSTS - Set to env BUILD_SOURCEBRANCH: $($currentBranch)"
        }
        if($env:SOURCEBRANCHFULLNAME) {
            $currentBranch = $env:SOURCEBRANCHFULLNAME
            Write-Host "Get-GitCurrentBranchVSTS - Set to env SOURCEBRANCHFULLNAME: $($currentBranch)"
        }
    }
    if($env:SYSTEM_PULLREQUEST_SOURCEBRANCH)
    {
        $prSrc = $($env:SYSTEM_PULLREQUEST_SOURCEBRANCH)
        $prSrc = $prSrc -replace "refs/heads/", ""
        
        Write-Host "Get-GitCurrentBranchVSTS - Got VSTS PR Source Branch: $prSrc"
        $currentBranch = $prSrc
    }
    $currentBranch
}

function Get-GitCurrentBranch {
    # Default git
    $currentBranch = (git symbolic-ref --short HEAD)

    # DevOps jiggery pokery
    $devopsBranch = Get-GitCurrentBranchVSTS
    if($devopsBranch) {
        $currentBranch = $devopsBranch
    }

    

    $currentBranch
}

function Get-GitLocalBranches {
    (git branch) | % { $_.TrimStart() -replace "\*[^\w]*","" }
}

function Get-GitRemoteBranches {
    (git branch --all) | % { $_.TrimStart() } | ?{ $_ -match "remotes/" }
}

function Remove-GitLocalBranches($CurrentBranch) {
    $branches = Get-GitLocalBranches
    foreach($branchname in $branches | ?{ $_ -notmatch "^\*" -and $_ -notmatch "$CurrentBranch" -and $_ -notmatch "master" -and $_ -notmatch "develop" }) {
        git branch -D $branchname.TrimStart()
    }
    #git remote update origin
    #git remote prune origin 
    git prune
    git fetch --prune
    git remote prune origin
}

function Invoke-GitFetchGitflowBranches($CurrentBranch) {
    Write-Host "Attempting to fetch GitFlow branches if missing"
    git fetch origin master
    git fetch origin develop
    git fetch origin $CurrentBranch
    git checkout master
    git pull
    git checkout develop
    git pull
    git checkout $CurrentBranch -f
    git pull
}

function Invoke-GitFetchRemoteBranches($CurrentBranch) {
    Write-Host "Attempting to fetch remote branches if missing"
    $remotes = Get-GitRemoteBranches
    $locals = Get-GitLocalBranches
    foreach($remote in $remotes) {
        $local = $remote -replace "remotes/origin/",""
        if($locals -notcontains $local) {
            git checkout $remote --track
            git pull
        }
    }
    git checkout $CurrentBranch -f
    git pull
}

function Add-PathToSearchPath ($NewPath) {
    $pathSeparator=[IO.Path]::PathSeparator
    if($NewPath) {
        $currentPath = [Environment]::GetEnvironmentVariable('PATH')
        $currentPath = "$($currentPath)$($pathSeparator)$(($NewPath).Path)"
        # Dedup
        $currentPath = (($currentPath -Split $pathSeparator | Select-Object -Unique) -join $pathSeparator)
        [Environment]::SetEnvironmentVariable('PATH', $currentPath, [EnvironmentVariableTarget]::Process)
    } else {
        Write-Warning "Couldn't resolve NewPath path correctly"
    }
}

function Install-NugetCaching() {
    # Enable nuget caching
    if($env:HTTP_PROXY) {
        $nuget = Get-Command nuget -ErrorAction SilentlyContinue
        if($nuget)
        {
            Write-Host "Setting Nuget proxy to '$env:HTTP_PROXY'"
            & $nuget config -set http_proxy=$env:HTTP_PROXY
        }
        else {
            Write-Host "Couldn't find nuget to set cache"
        }
    }
}

function Clear-GitversionCache() {
    # GitVersion Issues with PR builds mean clearing cache between builds is worth doing
    if(Test-Path ".git/gitversion_cache") {
        Remove-Item -Recurse .git/gitversion_cache/* -ErrorAction SilentlyContinue | Out-Null
    }
    
    # Make sure we get new tool versions each build
    if(Test-Path "tools/packages.config.md5sum") {
        Remove-Item "tools/packages.config.md5sum"
        Get-ChildItem "tools/" -Exclude "tools/packages.config" -Hidden -Recurse | Remove-Item -Force
        Remove-Item "tools/*" -Recurse -Exclude "tools/packages.config"
    }
}

function Invoke-PreauthSetup($CurrentBranch, [switch]$FetchAllBranches) {
    # TODO: Git fetch for gitversion issues
    # TODO: Module?
    try
    {
        if($env:GITUSER) 
        {
            Write-Host "GITUSER found, using preauth setup"
$preauthScript = @"
#!/usr/bin/pwsh
Write-Host "username=$($env:GITUSER)"
Write-Host "password=$($env:GITKEY)"
"@
            if($IsLinux) {
                $preauthScript = $preauthScript.Replace("`r`n","`n")
            }
            $preauthScript | Out-File -Encoding ASCII preauth.ps1
            $authPath = (Resolve-Path "./preauth.ps1").Path
            # git config --local --add core.askpass $authPath
            git config --local --add credential.helper $authPath
            if($IsLinux) {
                chmod a+x $authPath
            }
            # git config --local --add core.askpass "pwsh -Command { ./tmp/pre.ps1 -GitAuth } "
        } else {
            Write-Warning "No gituser found, pre fetch will fail if repo is private"
        }
        Write-Host "Using current branch: $CurrentBranch"
        Remove-GitLocalBranches -CurrentBranch $CurrentBranch
        Invoke-GitFetchGitflowBranches -CurrentBranch $CurrentBranch
        if($FetchAllBranches) {
            Invoke-GitFetchRemoteBranches -CurrentBranch $CurrentBranch
        }

        Write-Host "Current branches:"
        git branch --all
    }
    catch {

    } finally {
        # Remove askpass config
        if($env:GITUSER) {
            # git config --local --unset-all core.askpass 
            git config --local --unset-all credential.helper
        }
        if(Test-Path ./preauth.ps1) {
            rm ./preauth.ps1
        }
    }
}

# TODO: Make this param/variable in project.json somehow?
function Invoke-NugetSourcesSetup()
{
    $nuget = Get-Command nuget -ErrorAction SilentlyContinue
    $pfRepoUrl = "$($env:LocalNugetServerUrl)"
    $pfRepoApiKey = "$($env:LocalNugetApiKey)"
    $pfRepoUser = "$($env:LocalNugetUserName)"
    $pfRepoPassword = "$($env:LocalNugetPassword)"

    # TODO: Handle xplat nuget (mono?)
    # if($IsLinux)
    # {
    #     $linkExists = Get-ChildItem ~/.nuget/ -ErrorAction SilentlyContinue | ?{ $_.LinkType -eq "SymbolicLink" -and $_.BaseName -eq "NuGet" }
    #     if(!$linkExists -and (Test-Path ~/.config/NuGet/))
    #     {
    #         # Fix issues with mono/dotnet configs in
    #         # cat ~/.config/NuGet/NuGet.Config
    #         # cat ~/.nuget/NuGet/NuGet.Config
    #         # https://github.com/NuGet/Home/issues/4413
    #         Remove-Item ~/.nuget/NuGet -Recurse -ErrorAction SilentlyContinue
    #         ln -s ~/.config/NuGet/ ~/.nuget/NuGet/
    #         Remove-Item ~/.nuget/NuGet/nuget.config -ErrorAction SilentlyContinue
    #     }
    # }

    if($nuget)
    {
        Write-Host "Checking Nuget sources '$pfRepoUrl'"

        if($pfRepoApiKey) {
            Write-Host "Setting PowerFarming.Nuget repo"
            nuget sources add -Name "PowerFarming Nuget" -source "$pfRepoUrl"
            #nuget setapikey "$pfRepoApiKey" -Source "$pfRepoUrl"
        } else {
            Write-Host "Credentials were missing, couldn't set up PowerFarming.Nuget Nuget Source Authentication"
        }
        # Needed if running Windows auth
        if($pfRepoUser) {
            Write-Host "Setting PowerFarming.Nuget repo user and password override"
            nuget sources update -Name "PowerFarming Nuget" -UserName "$pfRepoUser" -Password "$pfRepoPassword"
        }
    }

    # Try without override
    if($IsLinux -and $false) {
        # Set cake config var to main nuget one
        if(Test-Path "~/.config/NuGet/NuGet.Config") {
            Write-Host "Setting Cake nuget.config override"
            $env:CAKE_NUGET_CONFIGFILE = (Resolve-Path "~/.config/NuGet/NuGet.Config").Path
        }
    }

    $psRepo = Get-Command Get-PSRepository -ErrorAction SilentlyContinue
    $enablePSRepo = $false
    if($psRepo -and $enablePSRepo)
    {
        $psGallery = Get-PSRepository -Name "PSGallery"
        if($psGallery -and $psGallery.InstallationPolicy -ne "Trusted") {
            Write-Host "Trusting PSGallery PSRepository"
            Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
        }

        # TODO: Set Authentication?
        $pfRepo = Get-PSRepository -Name "PowerFarming.Nuget" -ErrorAction SilentlyContinue
        if(!$pfRepo) {
            Write-Host "Registering PowerFarming.Nuget PSRepository"
            Register-PSRepository -Name "PowerFarming.Nuget" -SourceLocation "$pfRepoUrl"
            $pfRepo = Get-PSRepository -Name "PowerFarming.Nuget" -ErrorAction SilentlyContinue
        }
        if($pfRepo -and $pfRepo.InstallationPolicy -ne "Trusted") {
            Write-Host "Trusting PowerFarming.Nuget PSRepository"
            Set-PSRepository -Name "PowerFarming.Nuget" -InstallationPolicy Trusted
        }
        if($pfRepoApiKey) {
            $password = "$pfRepoApiKey" | ConvertTo-SecureString -asPlainText -Force
            $apiCreds = New-Object System.Management.Automation.PSCredential("apikey",$password)
            Set-PSRepository -Name "PowerFarming.Nuget" -Credential $apiCreds
        } else {
            Write-Host "Credentials were missing, couldn't set up PowerFarming.Nuget PSRepository Authentication"
        }
    }
}

function Invoke-CakeBootstrap() {
    if(Get-Command "dotnet-cake" -ErrorAction SilentlyContinue) {
        Write-Host "Running cake core bootstrap"
        dotnet-cake setup.cake --bootstrap
    }
}

function Install-PrePrerequisites {

    # Take advantage of .net core 3 for tools
    if(Get-Command dotnet -ErrorAction SilentlyContinue) {
        $dotnetVers = [Version](dotnet --version)
        if($dotnetVers.Major -ge 3) {
            & dotnet tool restore
        }
    }

    if(!(Get-Command nuget -ErrorAction SilentlyContinue)) {
        if($IsLinux) {
            $monoExists = Get-Command mono -ErrorAction SilentlyContinue
            if($monoExists) {
                wget https://dist.nuget.org/win-x86-commandline/latest/nuget.exe
                $nugetPath = Resolve-Path "./nuget.exe"
            # Set up helper script to handle calling nuget via mono
$nugetScript = @"
#!/bin/sh
$($monoExists.Path) $($nugetPath.Path) $@
"@
                $nugetScript = $nugetScript.Replace("`r`n","`n")
                $nugetScript | Out-File -Encoding ASCII ./nuget
                chmod a+x ./nuget
            } else {
                Write-Error "Nuget and mono not found, build will likely fail"
            }
        } else {
            # Possibly install via choco?
        }
    }
}

# Currently setting up hacky shims because dotnet tool is a pita
function Install-Helpers {

    $pwshExists = Get-Command pwsh -ErrorAction SilentlyContinue
    
}

#===============
# Main
#===============

# Useful missing vars
& "$PSScriptRoot/set-base-params.ps1"
$currentBranch = Get-GitCurrentBranch
$env:BRANCH_NAME=$env:GITBRANCH=$currentBranch
$isVSTSNode = $env:VSTS_AGENT
$isJenkinsNode = $env:JENKINS_HOME


# TODO: Handle xplat helper links for cake, gitversion?

# Default path adjustments
$toolPath = Resolve-Path "." -ErrorAction SilentlyContinue
Add-PathToSearchPath -NewPath $toolPath.Path
New-Item -Path .dotnet/tools -ItemType Directory | Out-Null
$toolPath = Resolve-Path ".dotnet/tools" -ErrorAction SilentlyContinue
Add-PathToSearchPath -NewPath $toolPath.Path

Install-PrePrerequisites
Install-Helpers

Install-NugetCaching
Clear-GitversionCache
# These are set up as part of the build.dntool.ps1 now...
# Install-DotnetBuildTools

if(!($isVSTSNode) -and !($isJenkinsNode)) {
    Invoke-PreauthSetup -FetchAllBranches:($isJenkinsNode) -CurrentBranch $currentBranch
} else {
    # Testing
    Invoke-PreauthSetup -FetchAllBranches:$false -CurrentBranch $currentBranch
}

Invoke-NugetSourcesSetup

# Nuget auth errors, ignore for now
# Invoke-CakeBootstrap

# SIG # Begin signature block
# MIII5wYJKoZIhvcNAQcCoIII2DCCCNQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUvarlKR/R4ffTg3OkLP/f8rfl
# QCegggY1MIIGMTCCBRmgAwIBAgIKYf5LqwAAAAACwjANBgkqhkiG9w0BAQUFADBt
# MRIwEAYKCZImiZPyLGQBGRYCbnoxEjAQBgoJkiaJk/IsZAEZFgJjbzEcMBoGCgmS
# JomT8ixkARkWDHBvd2VyZmFybWluZzElMCMGA1UEAxMccG93ZXJmYXJtaW5nLVBG
# TlotU1JWLTAyOC1DQTAeFw0xOTAyMTMwNDIxNTJaFw0yMDAyMTMwNDIxNTJaMIGo
# MRIwEAYKCZImiZPyLGQBGRYCbnoxEjAQBgoJkiaJk/IsZAEZFgJjbzEcMBoGCgmS
# JomT8ixkARkWDHBvd2VyZmFybWluZzEeMBwGA1UECxMVTmV3IFplYWxhbmQgV2hv
# bGVzYWxlMQswCQYDVQQLEwJJVDEVMBMGA1UECxMMU3RhZmYgQWRtaW5zMRwwGgYD
# VQQDDBNBZG1pbiB8IEdhdmluIEpvbmVzMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAu9tcCzOM8SPtfYncaoBuRDWH1w3yhGUcfUdBWzGMWgslfrxEDZPd
# 3pEg80kKH0InzkiuVHwQYvSzfeOTD+eCvt3Qp5Lfb2n6yxZkJNu56VMYkB6ArRsI
# h2USYmrMd7DeNxZgcZMljnrfh2UdzybPZbcZm0AaSr9A2HFP5Iot12NWAA1UmSEa
# hNTq2SGPBuqaierVoWrETldAxhWKwdn1UiVEbDskMcZ2WTUEBUsAlCEW/ZqhGsww
# ATcm5tHz/7xqX15j7r+eCzqOGpHBB9NB/eBk8rki4GSwtaydbe4dfxVlh4dIcZNC
# 7i/bPf85Yzb0dAXxMYr77XZbCGAZcUkMrQIDAQABo4IClTCCApEwJQYJKwYBBAGC
# NxQCBBgeFgBDAG8AZABlAFMAaQBnAG4AaQBuAGcwCwYDVR0PBAQDAgeAMBMGA1Ud
# JQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBRaW+4O0YIwZIgjx01XkpL/b/rgkjAf
# BgNVHSMEGDAWgBTDKX3ixQYwhJKqfUODbUNBL5OTgTCB6QYDVR0fBIHhMIHeMIHb
# oIHYoIHVhoHSbGRhcDovLy9DTj1wb3dlcmZhcm1pbmctUEZOWi1TUlYtMDI4LUNB
# LENOPVBGTlotU1JWLTAyOCxDTj1DRFAsQ049UHVibGljJTIwS2V5JTIwU2Vydmlj
# ZXMsQ049U2VydmljZXMsQ049Q29uZmlndXJhdGlvbixEQz1wb3dlcmZhcm1pbmcs
# REM9Y28sREM9bno/Y2VydGlmaWNhdGVSZXZvY2F0aW9uTGlzdD9iYXNlP29iamVj
# dENsYXNzPWNSTERpc3RyaWJ1dGlvblBvaW50MIHYBggrBgEFBQcBAQSByzCByDCB
# xQYIKwYBBQUHMAKGgbhsZGFwOi8vL0NOPXBvd2VyZmFybWluZy1QRk5aLVNSVi0w
# MjgtQ0EsQ049QUlBLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZp
# Y2VzLENOPUNvbmZpZ3VyYXRpb24sREM9cG93ZXJmYXJtaW5nLERDPWNvLERDPW56
# P2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0aW9uQXV0
# aG9yaXR5MD8GA1UdEQQ4MDagNAYKKwYBBAGCNxQCA6AmDCRhZG1pbi5nYXZpbi5q
# b25lc0Bwb3dlcmZhcm1pbmcuY28ubnowDQYJKoZIhvcNAQEFBQADggEBAHFQmVNg
# E6up95QxHQAhxfQ+pVwwuEXT6NGSp/HbTSmi7JCwdv8AOijZp+OyPSnzkuVD3UYZ
# JYIIE7Vj0hCAoougxzQYFMIwYctZpahQ//I+kvQpVC6xALDwY04AYYYMG5Wf8ORg
# 1+6YlYDpsiD4PlOuEtUs4ZdzT+d2tzbaxXcdYk7vVnLX16RLZyu+jPpJ/5bK5sKr
# mgun+Rp6/oPXwcYahIl+anjmvJ/5lX47KdE7oJCM9MNUtnztZOG/NJoKSENU8YC0
# tVaWJUMRHZtmYlZ9kBDG3HEyPeGKNIlGgEwyAXfPREjAHcwxVJThMEijrpr01PSA
# AYD7FbSD6VrlKLoxggIcMIICGAIBATB7MG0xEjAQBgoJkiaJk/IsZAEZFgJuejES
# MBAGCgmSJomT8ixkARkWAmNvMRwwGgYKCZImiZPyLGQBGRYMcG93ZXJmYXJtaW5n
# MSUwIwYDVQQDExxwb3dlcmZhcm1pbmctUEZOWi1TUlYtMDI4LUNBAgph/kurAAAA
# AALCMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAAMBkGCSqG
# SIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3
# AgEVMCMGCSqGSIb3DQEJBDEWBBR5mT62F3IiPxQ/os8KrIqS0aJ/EjANBgkqhkiG
# 9w0BAQEFAASCAQBWKLws3bNjfqWJmIn/ZvehbVYljsE2MvezP8rrha1bTAUdins3
# 8slp9Tp06W2TdPEo+SHN1c91Vyr/9kOAVz4Auv5vA+KNXD5cySmxOj16Ne+FtALD
# L4VVwSjT8C+EUYWNwAzTkKGdP9yqMZq1VHLMJ89AkJYtrCHB8y+qp7E3up3oujuN
# SI8la57CvGYPkl8kjRqoZJ+K80Dx6fzxNp/rqZTZSuuMQZFsObACgVjJgd//FhTU
# sGVYAJp62f/rMzbX5mTvJWV7u9DieRT5yZTXi8jloOxMeQqY9vrrVPE1wYDb4OKi
# fDCacRhJdJuxQF5YYWxWnTjfSDvzi4fMxfN8
# SIG # End signature block
