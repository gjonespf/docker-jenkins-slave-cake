[CmdletBinding()]
Param(
    # Can me either path to a single PSD1 file, or path to recurse for all PSD1 files to affect
    [string]$ManifestFilePath,
    [Parameter(Position=0,Mandatory=$false,ValueFromRemainingArguments=$true)]
    [string[]]$ScriptArgs
)

Import-Module PowerShellGet

# Assumes version file is already built
function Get-CurrentVersionDetails {
    $versionFile = "./BuildVersion.json"
    $versionJson = Get-Content $versionFile
    $versionData = $versionJson | ConvertFrom-Json
    $versionData
}

function Update-PSModuleManifest {
    Param(
        # Can me either path to a single PSD1 file, or path to recurse for all PSD1 files to affect
        [string]$ManifestFilePath
    )

    Write-Output "Processing manifest: $ManifestFilePath"

    $moduleManifest = Test-ModuleManifest $ManifestFilePath -ErrorAction SilentlyContinue
    if(!($moduleManifest)) {
        Write-Warning "Could not successfully load manifest for path: $ManifestFilePath"
        return
    }
    $versionData = Get-CurrentVersionDetails

    $oldVersion = $moduleManifest.Version
    $oldSemver = $oldVersion
    
    # Validate the PrivateData
    if($null -eq $moduleManifest.PrivateData) {
        $moduleManifest.PrivateData = @{
            PSData = @{

            }
        }
    }

    if($moduleManifest.PrivateData.PSData.Prerelease) { $oldSemver = "$oldSemver-$($moduleManifest.PrivateData.PSData.Prerelease.TrimStart("-"))" }
    Write-Output "Old Version: $oldVersion - semver $oldSemver"

    $newVersion = $versionData.Version
    $newSemver = $versionData.SemVersion
    Write-Output "New Version: $newVersion - semver $newSemver"

    $prereleaseTag = $versionData.SemVersion -replace $versionData.Version, ""
    $privateData = $moduleManifest.PrivateData
    $privateData.PSData.Prerelease = $prereleaseTag

    # FIXME: Update-ModuleManifest issues
    # https://github.com/PowerShell/PowerShellGet/issues/294#
    #$privateData.PSData.SemVersion = $versionData.SemVersion
    #$privateData.PSData.InformationalVersion = $versionData.InformationalVersion
    #$privateData.PSData.BranchName = $versionData.BranchName

    $Name = $moduleManifest.CompanyName
    #$functionList = ((Get-ChildItem -Path .\$TemplatePowerShellModule\Public).BaseName)
    $splat = @{
        'Path'              = $ManifestFilePath
        'ModuleVersion'     = $newVersion
        'Copyright'         = "(c) 2015-$( (Get-Date).Year ) $Name. All rights reserved."
        'PrivateData'       = $privateData.PSData
        'Prerelease'        = $privateData.Prerelease
    }
    #$splat
    Update-ModuleManifest @splat
}

$ManifestFilePathList = @()

# Default to looking for all PSD1 files under path...
$files = Get-ChildItem -Path $ManifestFilePath -Filter "*.psd1" -Recurse
$ManifestFilePathList = $ManifestFilePathList + ($files | Select-Object -ExpandProperty FullName)

foreach($filePath in $ManifestFilePathList) {
    Update-PSModuleManifest -ManifestFilePath $filePath
}



# SIG # Begin signature block
# MIII5wYJKoZIhvcNAQcCoIII2DCCCNQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUBZ5+bPlXaZrRE0m6e3xk+2UJ
# 3CmgggY1MIIGMTCCBRmgAwIBAgIKYf5LqwAAAAACwjANBgkqhkiG9w0BAQUFADBt
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
# AgEVMCMGCSqGSIb3DQEJBDEWBBSCQUyR6cYiyelDt2DUYKors2e1bjANBgkqhkiG
# 9w0BAQEFAASCAQAwApmtNWSScJGBCx6sqTILhTF0Wt9KJHh34F+58/F9G9YlzRvj
# baBujld2BahIZLmrXfqeotZyAooyxtbi/FkYABsY8lH7p6AvOS7PjGA0nMQEidM7
# 4wSGFvpmvWAxSPtjxYWJrOaheeCchrlHOhDNDK96652WH/bjxcCVrrePHjoRIWlf
# jCdS176ALqdcsnnmiVrq4hQCIAxsL+CPUyod7xLy0AJRPif3n4ia+w/5LrW7GRyp
# mA55zQfxVfpjHSoTxxqJudyg5lJrdEysfKWAHBEiPYG7vf0Kueg55W8OhX1bGsTP
# JGiq1/djrpBiDXZo9hhhx1cMk4M/4ZlUm+Nh
# SIG # End signature block
