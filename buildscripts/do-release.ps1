#!/bin/pwsh
param([string]$ReleaseVersion, [switch]$IncrementMajor, [switch]$IncrementMinor, [switch]$IncrementPatch, [switch]$FinaliseRelease, $Interactive=$true, [switch]$Force) 
#TODO: Allow increments other than patch?

function Get-GitReleasesFromTags {
    $tags = $(git tag)
    $releaseTags = ($tags -match "[vV]?(\d+(\.\d+){1,3}).*")
    $releases = @()
    $releaseTags | ForEach-Object {
        $tag = $_
        $releaseVersion = [version]$tag
        $releases = $releases + $releaseVersion
    }
    $releases
}

function Get-GitFlowConfig ([string] $VariableMatch) {
    $cfg = $(git flow config)
    $cfgItem = $cfg | Where-Object { $_ -match $VariableMatch }
    ($cfgItem -Split ":" | Select-Object -l 1).Trim()
}

function Get-GitFlowVersionTagPrefix {
    Get-GitFlowConfig -VariableMatch "Version tag prefix"
}

function Get-GitFlowReleaseBranchPrefix {
    Get-GitFlowConfig -VariableMatch "Release branch prefix"
}

function Get-GitFlowNewReleaseVersion ([string]$ReleaseVersion) {
    # Find release version or use supplied
    [version]$finalVersion = "0.0.0"
    try {
        # Get latest from git tags
        if(!($ReleaseVersion)) {
            $releases = Get-GitReleasesFromTags
            $lastRelease = $releases | Select-Object -l 1

            # Remember to increment version number, default patch/build
            if($IncrementMajor) {
                $finalVersion = [version]"$($lastRelease.Major+1).0.0"
            } elseif($IncrementMinor) {
                $finalVersion = [version]"$($lastRelease.Major).$($lastRelease.Minor+1).0"
            } else {
                $finalVersion = [version]"$($lastRelease.Major).$($lastRelease.Minor).$($lastRelease.Build+1)"
            }
            Write-Host "Using git version '$finalVersion' based on supplied preferences (last release version '$lastRelease')"

        } else {
            Write-Host "Using supplied version '$ReleaseVersion'"
            [version]$finalVersion = $ReleaseVersion
        }
    } catch {
        throw "Could not detect a valid version (using version text '$ReleaseVersion') - please manually suggest a version to use"
    }
    $finalVersion
}

function Invoke-ReadKey {
    if($global:Interactive) {
        Write-Host "Hit any key to continue"
        [console]::ReadKey($true)
    }
}

function Invoke-RunProcessCatchErrors ([string]$Command, [switch]$ThrowOnErrors, [switch]$IgnoreErrors) {
    try {
        $expressionResult = Invoke-Expression "$Command 2>&1"
        if(($test | Where-Object { $_.writeErrorStream }) -and $ThrowOnErrors) {
            $stack = $test | Where-Object { $_.writeErrorStream }
            throw $stack
        }
        if($IgnoreErrors) {
            $expressionResult | Where-Object { !($_.writeErrorStream) }
        }
        else {
            $expressionResult
        }
    }  Catch [System.Management.Automation.RemoteException] {
        if($ThrowOnErrors) {
            Write-Error ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
            Write-Error ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
            throw "Exception in run process, and throw on errors was enabled"
        } elseif(!($IgnoreErrors)) {
            Write-Warning ($_.Exception | Format-List -Force | Out-String) -ErrorAction Continue
            Write-Warning ($_.InvocationInfo | Format-List -Force | Out-String) -ErrorAction Continue
        }
    }
}

function Invoke-GitFlowInit ([switch]$Force) {

    $initialised = $(git flow config)

    if(!($initialised) -or $Force) {

        # Default branches
        $out = Invoke-RunProcessCatchErrors -Command "git symbolic-ref HEAD refs/heads/master"
        $out = Invoke-RunProcessCatchErrors -Command "git commit --allow-empty --quiet -m ""GitFlow Init"" "
        $out = Invoke-RunProcessCatchErrors -Command "git branch --no-track develop master"
        $out = Invoke-RunProcessCatchErrors -Command "git checkout -q develop"

        # Normally:
        if($Force) {
            $out = Invoke-RunProcessCatchErrors -Command "git flow init -d -f" -ThrowOnErrors
        } else {
            $out = Invoke-RunProcessCatchErrors -Command "git flow init -d" -ThrowOnErrors
        }

        # Manually update defaults
        $out = Invoke-RunProcessCatchErrors -Command "git config gitflow.branch.master master"
        $out = Invoke-RunProcessCatchErrors -Command "git config gitflow.branch.develop develop"
        #$out = Invoke-RunProcessCatchErrors -Command "git symbolic-ref HEAD refs/heads/master"

        $out = Invoke-RunProcessCatchErrors -Command "git config gitflow.prefix.feature feature/"
        $out = Invoke-RunProcessCatchErrors -Command "git config gitflow.prefix.bugfix bugfix/"

        $out = Invoke-RunProcessCatchErrors -Command "git config gitflow.prefix.release release/"
        $out = Invoke-RunProcessCatchErrors -Command "git config gitflow.prefix.hotfix hotfix/"
        $out = Invoke-RunProcessCatchErrors -Command "git config gitflow.prefix.support support/"
        $out = Invoke-RunProcessCatchErrors -Command "git config gitflow.prefix.versiontag v"

    }
}

function Invoke-GitFlowRelease ([string]$ReleaseVersion, [switch]$IncrementMajor, [switch]$IncrementMinor, [switch]$IncrementPatch, [switch]$FinaliseRelease, $Interactive=$true, [switch]$Force) 
{

    Invoke-GitFlowInit

    # Remove "no release" as error
    $currentRelease = Invoke-RunProcessCatchErrors -Command "git flow release" -IgnoreErrors
    if($currentRelease -match "^No release branches"){
        $currentRelease = ""
    } else {
		$currentRelease = $currentRelease.Trim("* ")
    }
    if($currentRelease -and !($FinaliseRelease)) {
        throw "Cannot continue, exisiting release '$currentRelease' and we're not fnalising.  If this release is no longer required, use command 'git flow release delete $currentRelease' otherwise run with param -FinaliseRelease"
    }

    $branches = $(git branch)
    $currentBranch = $(git rev-parse --abbrev-ref HEAD)
    $workingStatus = $(git status -s)

    if($workingStatus) {
        Write-Error "Found changed files in working dir, cannot continue"
        Write-Error "$workingStatus"
        throw "Failing due to changed files in workspace"
    }

    if($currentBranch -notmatch "develop" -and $currentBranch -notmatch "master") {
        Write-Warning "Script will change to develop branch, break now if you don't wish this to happen"
        $quiet = Invoke-ReadKey
    }

    if($FinaliseRelease) {
        $finalVersion = $currentRelease
        Write-Warning "Script will now finalise release '$finalVersion'"
        Write-Host "Hit a key to action this release"
        $quiet = Invoke-ReadKey

        # Use gitflow helpers
        Write-Host "Finishing release '$finalVersion'"
        #Invoke-RunProcessCatchErrors -Command "git flow release finish ""$ReleaseVersion"" " -ThrowOnErrors
        # NOTE: THIS IS INTERACTIVE BY DEFAULT AS IT ASKS FOR RELEASE NOTES
        if($Interactive) {
            git flow release finish "$ReleaseVersion" --nobackmerge
        } else {
            $defaultMessage = "Release $ReleaseVersion"
            Invoke-RunProcessCatchErrors -Command "git flow release finish ""$ReleaseVersion"" --nobackmerge --message ""$defaultMessage"" " -ThrowOnErrors
        }

        # Manual
        # Invoke-RunProcessCatchErrors -Command "git tag -a $ReleaseVersion -m ""Release $ReleaseVersion"" " -ThrowOnErrors
        # Invoke-RunProcessCatchErrors -Command "git checkout master" -ThrowOnErrors
        # Invoke-RunProcessCatchErrors -Command "git merge release/$ReleaseVersion" -ThrowOnErrors

        Write-Host "Hit a key to push this release"
        $quiet = Invoke-ReadKey
        Write-Host "Pushing release '$finalVersion'"
        Invoke-RunProcessCatchErrors -Command "git push -v --progress --tags ""origin"" " -ThrowOnErrors
        Invoke-RunProcessCatchErrors -Command "git push -v --progress --tags ""origin"" master:master" -ThrowOnErrors

        Write-Host "Hit a key to clean this release"
        $quiet = Invoke-ReadKey
        Invoke-RunProcessCatchErrors -Command "git flow release delete $ReleaseVersion" -ThrowOnErrors
        Invoke-RunProcessCatchErrors -Command "git checkout master" -ThrowOnErrors

        Write-Host "Release $ReleaseVersion has been finalised."
    } else {
        [version]$finalVersion = Get-GitFlowNewReleaseVersion -ReleaseVersion $ReleaseVersion
        if($finalVersion -eq "0.0.0") {
            throw "Error finding correct version for release, please manually specify using -ReleaseVersion"
        }
    
        Write-Warning "Script will now set up release '$finalVersion'"
        
        Write-Host "Hit a key to action this release"
        $quiet = Invoke-ReadKey

        #TODO: Prefix?
        $ReleaseVersion = "$finalVersion"
        $versPrefix = Get-GitFlowVersionTagPrefix
        $releasePrefix = Get-GitFlowReleaseBranchPrefix
        $releaseBranchName = "$($releasePrefix)$($versPrefix)$($ReleaseVersion)"

        Invoke-RunProcessCatchErrors -Command "git checkout develop" -ThrowOnErrors
        Invoke-RunProcessCatchErrors -Command "git pull" -ThrowOnErrors
        Invoke-RunProcessCatchErrors -Command "git flow release start $ReleaseVersion" -ThrowOnErrors
        Invoke-RunProcessCatchErrors -Command "git push -v --progress --tags ""origin"" $releaseBranchName" -ThrowOnErrors
    }
}

Invoke-GitFlowRelease -ReleaseVersion $ReleaseVersion -IncrementMajor:$IncrementMajor -IncrementMinor:$IncrementMinor -IncrementPatch:$IncrementPatch -FinaliseRelease:$FinaliseRelease -Interactive:$Interactive -Force:$Force

# SIG # Begin signature block
# MIII5wYJKoZIhvcNAQcCoIII2DCCCNQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQU5bxZGQ60/TX1gNDxqTLQsOd3
# mGCgggY1MIIGMTCCBRmgAwIBAgIKYf5LqwAAAAACwjANBgkqhkiG9w0BAQUFADBt
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
# AgEVMCMGCSqGSIb3DQEJBDEWBBRqWLv958W/FBjfF8do2Dpe/PzRszANBgkqhkiG
# 9w0BAQEFAASCAQA8MtXYzeKshJhiZ+4mfqx6g6H095Gb6VABCJPbMzpmAmRcO+oJ
# bYDvOdjPIzrkY/gVUGkBARPYphXVD5vFojoVN+3Dr9L5mfl2TZpr/6jkJNeTTu0G
# RwrVNeEHUJbEXTNX3hDsqQ879QN91bww5uIyO0XuGKrD0EgKDxe8wxtzuc29BMpK
# N+UY/Er1h882Srbivyqx6Z8nhCkZNzGGeggWn2hfUxn7d9W1Y+MiOwVIHppN6q9B
# 0JXxiF62wt6s2Pt0sKmUTZvZOOpWam9sNkV07VY6LPT74CGMgMUepNAjGRHy5Orr
# M+LTvckZmRmWaIkPUpEFmIrwXjEZKpjpgXko
# SIG # End signature block
