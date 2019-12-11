[CmdletBinding()]
Param(
    [string]$VstsApiToken,
    [string]$JenkinsApiUsername,
    [string]$JenkinsApiPassword,
    [string]$PropsFileName = "properties.json",
    [string]$TempPath = "BuildArtifacts/",
    [switch]$WhatIf
)
# Install-Module -Name VSTeam -RequiredVersion 4.0.9

Import-Module VSTeam
$teamExists = Get-Module VSTeam
if(!$teamExists) {
    throw "Could not load VSTeam module, required for this script"
}
$testCmds = Get-Command -Module VSTeam
if(!$testCmds) {
    throw "Commands not loaded correctly?"
}
if($env:VstsApiToken) {
    $VstsApiToken = $env:VstsApiToken
}
if(!$VstsApiToken) {
    throw "VSTS Api key missing"
}

$root = $PSScriptRoot
if(!$root) {
    $root = Resolve-Path "."
}

$props = @{}
$propsFilePath = "$root/$PropsFileName"
if(!(Test-Path $propsFilePath)) {
    if(Test-Path "$root/../$PropsFileName") {
        $propsFilePath = "$root/../$PropsFileName"
    }
}

if(Test-Path $propsFilePath) {
    $file = Get-Content -Path $propsFilePath
    $props = $file | ConvertFrom-Json
} else {
    throw "Couldn't find props file... Please ensure the file '$PropsFileName' is present"
}

function Update-VSTeamJenkinsServiceEndpoint($Props, $JenkinsProps, $TempPath)
{
    $endpoints = Get-VSTeamServiceEndpoint -ProjectName $($props.ProjectName) -ErrorAction SilentlyContinue
    $jenkinsEndpointPayload = @{
        "name" = "Jenkins - DEVINF"
        "type" = "jenkins"
        "url" = "$($props.JenkinsUrl)"
        "authorization" = @{
            "parameters" = @{ 
                "username" = "$($JenkinsProps.JenkinsApiUsername)"
                "password" = "$($JenkinsProps.JenkinsApiPassword)"
            }
            "scheme" = "UsernamePassword"
        }
        "data" = @{
            "acceptUntrustedCerts" = "true"
        }
    }

    $existingEndpoint = $endpoints | ?{ $_.Name -eq $jenkinsEndpointPayload.Name}
    if(!$endpoints -or !$existingEndpoint) {
        # Add default jenkins endpoint
        $newEndpoint = Add-VSTeamServiceEndpoint -ProjectName $props.ProjectName -EndpointName $jenkinsEndpointPayload.Name -EndpointType "jenkins" -Object $jenkinsEndpointPayload
        if($newEndpoint) {
            Write-Host "Successfully created endpoint $($jenkinsEndpointPayload.Name) on project $($props.ProjectName)"
        }
    } 
    if($existingEndpoint) {
        # Update
        $newEndpoint = Update-VSTeamServiceEndpoint -ProjectName $props.ProjectName -Id $existingEndpoint.Id -Object $jenkinsEndpointPayload
        if($newEndpoint) {
            Write-Host "Successfully updated endpoint $($jenkinsEndpointPayload.Name) on project $($props.ProjectName)"
        }
    } else {
        Write-Error "Error creating endpoint $($jenkinsEndpointPayload.Name) on project $($props.ProjectName)"
    }
}

function Update-VSTeamDefaultPipelines($Props, $TempPath, [switch]$Force) {
    $builds = Get-VSTeamBuildDefinition -ProjectName $($props.ProjectName) -ErrorAction SilentlyContinue
    $defaultBuilds = @(
        @{
            "Name" = "$($props.ProjectName) VSTS"
            "BuildDefinition" = "azure-pipelines.yaml"
            "BuildBranchDefault" = "refs/heads/master"
            "BuildPool" = "devinf"
        },
        @{
            "Name" = "$($props.ProjectName) PR VSTS"
            "BuildDefinition" = "azure-pipelines.pr.yaml"
            "BuildBranchDefault" = "refs/heads/develop"
            "BuildPool" = "devinf"
        }
    )
    # $kdBuilds = Get-VSTeamBuildDefinition -ProjectName "PowerFarming.KiotiDirect" -ErrorAction SilentlyContinue
    # $buildDef = $defaultBuilds | Select -f 1
    # $team = Get-VSTeam -ProjectName "$($Props.ProjectName)"
    $repo = Get-VSTeamGitRepository -ProjectName "$($Props.ProjectName)"
    foreach($buildDef in $defaultBuilds) {

        $buildDefinitionPayload = @{
            "Name" = "$($buildDef.Name)"
            "Variables" = @{
                BuildJobEndpoint=@{value="Jenkins - $($buildDef.BuildPool)"; allowOverride= $true }; 
                BuildJobGroup=@{value="$($Props.ProjectGroupName)"}; 
                BuildJobProject=@{value="$($Props.ProjectName)"}
                }
            "Process" = @{
                "type" = 2
                "yamlFilename" = "$($buildDef.BuildDefinition)"
            }
            "Repository" = @{
                "id" = $repo.ID
                "type" = "TfsGit"
                "url" = "$($Props.SourceControlUrl)"
                "defaultBranch" = "$($buildDef.BuildBranchDefault)"
            }
            "Queue" = @{
                "poolName"    = "$($buildDef.BuildPool)"
                "pool"        = "VSTeamPool"
                #ID          : 56
                "ProjectName" = "$($Props.ProjectName)"
                "Name"        = "$($buildDef.BuildPool)"
            }
        }
        $existingBuildDef = ($builds | ?{ $_.Name -eq $buildDef.Name} )
        # This removes all build history... Really not a good idea
        # if($Force) {
        #     Write-Host "Force enabled, removing existing build def $($existingBuildDef.Name)"
        #     Remove-VSTeamBuildDefinition -ProjectName "$($Props.ProjectName)" -Id $existingBuildDef.ID -Confirm
        #     $existingBuildDef = $null
        # }
        $tmpJson = "BuildArtifacts/vsts-payload.json"
        # Add the ID
        if($existingBuildDef) {
            $buildDefinitionPayload.ID = $existingBuildDef.ID
            $buildDefinitionPayload.Revision = $existingBuildDef.Revision + 1
        }
        $buildDefinitionPayload | ConvertTo-Json | Out-File $tmpJson
        if(!$existingBuildDef) {
            Write-Host "Adding missing build definition $($buildDef.Name) on project $($props.ProjectName)"
            $newBuildDef = Add-VSTeamBuildDefinition -ProjectName $($props.ProjectName) -InFile $tmpJson
        } else {
            Write-Host "Updating build definition $($buildDef.Name) on project $($props.ProjectName)"
            $newBuildDef = Update-VSTeamBuildDefinition -ProjectName $($props.ProjectName) -ID $existingBuildDef.ID -InFile $tmpJson
        }
    }
}

function Invoke-Main($Props, $VstsApiToken, $JenkinsApiUsername, $JenkinsApiPassword, $TempPath)
{
    $pfvsts = $Props.VstsUrl
    $token = $VstsApiToken
    Add-VSTeamAccount -Account $pfvsts -PersonalAccessToken $token -Drive pfvsts
    $vstsDrive = New-PSDrive -Name pfvsts -PSProvider SHiPS -Root 'VSTeam#VSTeamAccount'

    $JenkinsProps = @{
        "JenkinsUrl" = "$($Props.JenkinsUrl)"
        "JenkinsApiUsername" = "$JenkinsApiUsername"
        "JenkinsApiPassword" = "$JenkinsApiPassword"
    }

    Update-VSTeamJenkinsServiceEndpoint -Props $Props -JenkinsProps $JenkinsProps -TempPath $TempPath
    Update-VSTeamDefaultPipelines -Props $Props -TempPath $TempPath
}

Invoke-Main -Props $props -VstsApiToken $VstsApiToken -JenkinsApiUsername $JenkinsApiUsername -JenkinsApiPassword $JenkinsApiPassword -TempPath $TempPath




# SIG # Begin signature block
# MIII5wYJKoZIhvcNAQcCoIII2DCCCNQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUmeJMkScMldTvJDtdTs/k36uH
# tiugggY1MIIGMTCCBRmgAwIBAgIKYf5LqwAAAAACwjANBgkqhkiG9w0BAQUFADBt
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
# AgEVMCMGCSqGSIb3DQEJBDEWBBSrfcaaH4y8Da8d/0KAYsSA1rNOuDANBgkqhkiG
# 9w0BAQEFAASCAQCAJA6OXLbbvvz8uoALmDXup7f6PGI72MGEdQPCPNUKW6VjPP43
# jodGmE6FDKMVhnMDAp20VjBFhsSyUCeFmdTPDORtrZkc9UC0YiFDO0tn5IT/7Sqg
# 04eAoVn0AaCsnV7BXPUoyIHNSCBAtoVYBMAn6DUsNj8FsuliphWtLKfrKAS8m7U8
# YsJ+PhxOsmycFRPMb3tbSoQgfRb3ITgbqsBDkMEWydOMQ2h+PiRQc5FdXeEDDGMx
# FJOkkBAnaTCN8DRkVRlTjh9bwyTEFYCNLy5t60Ecoi1YpE+al963zyjesCdk2IB7
# 246LbX77d5hxH6+87jKNcQ/WpsmdOPA9wfOt
# SIG # End signature block
