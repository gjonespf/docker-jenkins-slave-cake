
# https://github.com/Microsoft/azure-pipelines-tasks/issues/8193
# https://github.com/Microsoft/azure-pipelines-agent/issues/838

# In summary: VSO/ADOps does some weird stuff with variables/branches that we need to pull into line
# Examples:
# SourceBranch:

$isRunningInVSTS=$env:VSTS_AGENT

# Some verbosity
if($true)
{
    Write-Host "Variables:"
    
    Write-Host "BUILD_REPOSITORY_URI:               $($env:BUILD_REPOSITORY_URI)"
    Write-Host "BUILD_SOURCEBRANCH:                 $($env:BUILD_SOURCEBRANCH)"
    Write-Host "BUILD_SOURCEBRANCHNAME:             $($env:BUILD_SOURCEBRANCHNAME)"
    Write-Host "SYSTEM_PULLREQUEST_PULLREQUESTID:   $($env:SYSTEM_PULLREQUEST_PULLREQUESTID)"
    Write-Host "SYSTEM_PULLREQUEST_SOURCEBRANCH:    $($env:SYSTEM_PULLREQUEST_SOURCEBRANCH)"
    Write-Host "BUILD_DEFINITIONNAME:               $($env:BUILD_DEFINITIONNAME)"
    Write-Host "BUILD_REASON:                       $($env:BUILD_REASON)"
    Write-Host "BUILD_REQUESTEDFOR:                 $($env:BUILD_REQUESTEDFOR)"
    Write-Host "BUILD_REQUESTEDFOREMAIL:            $($env:BUILD_REQUESTEDFOREMAIL)"
}

# BUILD_SOURCEBRANCHFULLNAME 
if($env:BUILD_SOURCEBRANCH) {
    if($env:BUILD_SOURCEBRANCH -match "merge") {
        $sourceBranchFullName = $env:BUILD_SOURCEBRANCH
    } else {
        $sourceBranchFullName = $env:BUILD_SOURCEBRANCH.substring($env:BUILD_SOURCEBRANCH.indexOf('/', 5) + 1)
    }
}

if($sourceBranchFullName) {
    Write-Host "Source branch full name: $sourceBranchFullName"
    if($isRunningInVSTS) {
        Write-Host "##vso[task.setvariable variable=SOURCEBRANCHFULLNAME]$sourceBranchFullName"
    }
    $env:SOURCEBRANCHFULLNAME = $sourceBranchFullName
}

$prId = $env:SYSTEM_PULLREQUEST_PULLREQUESTID
if(!($prId) -and $env:BUILD_SOURCEBRANCH -match "pull") {
    Write-Host "W: Pulled PRID from Build Source?"
    $prStringStarts=($env:BUILD_SOURCEBRANCH.IndexOf("pull")+5)
    $prStringLength=$env:BUILD_SOURCEBRANCH.LastIndexOf("/")-$prStringStarts
    $prId=$env:BUILD_SOURCEBRANCH.Substring($prStringStarts, $prStringLength)
}
if($prId) {
    Write-Host "PR ID: '$prId'"
    if($isRunningInVSTS) {
        Write-Host "##vso[task.setVariable variable=PullRequestId]$prId"
        Write-Host "##vso[task.setVariable variable=IsPullRequest]$true"
    }
    $env:PullRequestId=$prId

    $prSourceBranch = $env:SYSTEM_PULLREQUEST_SOURCEBRANCH
    if(!($prSourceBranch)) {
        Write-Host "W: Pulled PRSource from Build Source?"
        $prSourceBranch = $sourceBranchFullName
    }
    if($prSourceBranch -match "merge") {
        $prSourceBranch = $prSourceBranch -replace "refs/heads/", ""
    } else {
        # TODO: This should be conditional, as it's too greedy atm
        #$prSourceBranch = $prSourceBranch.substring($prSourceBranch.indexOf('/', 5) + 1)
    }
    Write-Host "PR Source: '$prSourceBranch'"
    if($isRunningInVSTS) {
        Write-Host "##vso[task.setVariable variable=PullRequestSourceBranch]$prSourceBranch"
    }
    $env:PullRequestSource=$prSourceBranch
}

$publishMilestone = ''
if ($env:BUILD_SOURCEBRANCH -match '^refs/heads/releases/m[0-9]+$') {
    $publishMilestone = 'true'
}
Write-Host "Publish milestone: '$publishMilestone'"
if($isRunningInVSTS) {
    Write-Host "##vso[task.setVariable variable=publish_milestone]$publishMilestone"
}
$env:DoPublishMilestone=$publishMilestone

# CommitId
$commitId = $($env:BUILD_SOURCEVERSION)
Write-Host "Commit ID: '$commitId'"
if($isRunningInVSTS) {
    Write-Host "##vso[task.setVariable variable=CommitId]$commitId"
}
$env:CommitId=$commitId

# BuildReason
$buildReason = $($env:BUILD_REASON) 
Write-Host "Build Reason: '$buildReason'"
if($isRunningInVSTS) {
    Write-Host "##vso[task.setVariable variable=BuildReason]$buildReason"
}
$env:BuildReason=$buildReason

# BuildDefinitionName
$buildDefinitionName = $($env:BUILD_DEFINITIONNAME) 
Write-Host "Build Definition: '$buildDefinitionName'"
if($isRunningInVSTS) {
    Write-Host "##vso[task.setVariable variable=BuildDefinitionName]$buildDefinitionName"
}
$env:BuildDefinitionName=$buildDefinitionName

# BuildQueuedBy
$buildQueuedBy = $($env:BUILD_REQUESTEDFOR) 
Write-Host "Build Queued By: '$BUILD_REQUESTEDFOR'"
if($isRunningInVSTS) {
    Write-Host "##vso[task.setVariable variable=BuildQueuedBy]$buildQueuedBy"
}
$env:BuildQueuedBy=$buildQueuedBy

# RepositoryUri
$repositoryUri = $($env:BUILD_REPOSITORY_URI) 
Write-Host "Repo: '$repositoryUri'"
if($isRunningInVSTS) {
    Write-Host "##vso[task.setVariable variable=RepositoryUri]$repositoryUri"
}
$env:RepositoryUri=$repositoryUri


# SIG # Begin signature block
# MIII5wYJKoZIhvcNAQcCoIII2DCCCNQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUYcRCVvl//FVwquFVYxUP/c8h
# z1+gggY1MIIGMTCCBRmgAwIBAgIKYf5LqwAAAAACwjANBgkqhkiG9w0BAQUFADBt
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
# AgEVMCMGCSqGSIb3DQEJBDEWBBQPmn46AzXw8CbVFsbQZfhc6emX7DANBgkqhkiG
# 9w0BAQEFAASCAQBgqhe+nNQK/HyHsEDDtbQkOjcBYvV8Z1qce7TQWQFk1t5ZvSTf
# mWe5+0e/8jnpMChehrlZiH8TD/GSgRPk1wOsDxIly2sXc89LTjNTj7r7gitpznsM
# kZj4/8FKC+jiEOvtjp/Fshgauy6j0A4NAeyZ33L2vEYIxkX+neqKAIUzuhO/zFuf
# 7hFXJwmtKOSF2OdKYefAoHqkzJCS5erVg7iSmVigFw+6agUeE47Ju9/nRbK7srbW
# i2jmHtjhY29Xa3PP4u+hPbl7uE17oi0sL+yC+V7IV5eCqu4yHppJeJCtzrkzz6RE
# lB7JRon1zV2/+FLYG3hSBsdXD3ok88O90pe5
# SIG # End signature block
