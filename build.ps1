
# TODO: Prerequisites
[CmdletBinding()]
Param(
    [string]$Script = "setup.cake",
    [string]$Target = "build",
    [string]$Configuration,
    [ValidateSet("Quiet", "Minimal", "Normal", "Verbose", "Diagnostic")]
    [string]$Verbosity="Minimal",
    [switch]$ShowDescription,
    [Alias("WhatIf", "Noop")]
    [switch]$DryRun,
    [switch]$Experimental,
    [version]$CakeVersion = '0.33.0',
    [string]$GitVersionVersion = '5.0.1',
    [string]$DotnetToolPath = '.dotnet/tools/',
    [string]$DotnetToolDefinitionsPath = 'dotnet-tools.json',
    [string]$ProjectDefinitionsPath = 'properties.json',
    [Parameter(Position=0,Mandatory=$false,ValueFromRemainingArguments=$true)]
    [string[]]$ScriptArgs
)

# Ensure we're in the build dir, or all sorts of things break...
Push-Location
Set-Location $PSScriptRoot

Write-Information "Build is setting up tools..."

$toolPathExists = Resolve-Path $DotnetToolPath -ErrorAction SilentlyContinue
if(!($toolPathExists)) {
    New-Item -ItemType Directory -Path $DotnetToolPath | Out-Null
}

# Set up process env based on properties.json
$projDefPathExists = Resolve-Path $ProjectDefinitionsPath -ErrorAction SilentlyContinue
if($projDefPathExists) {
    $projectDefinitions = Get-Content $ProjectDefinitionsPath | ConvertFrom-Json

    $projectDefinitions.PSObject.Properties | ForEach-Object {
        $name = $_.Name 
        $value = $_.value
        Write-Verbose "properties - $name = $value"
        if(!([Environment]::GetEnvironmentVariable($name) -or $ForceEnv)) {
            Write-Information "Setting empty env var: $name = $value"
            [Environment]::SetEnvironmentVariable($name, $value, [System.EnvironmentVariableTarget]::Process)
        }
    }
}

function New-DotnetToolDefinition ($PackageId, $Version, $CommandName) {
    [pscustomobject] @{
        PackageId = $PackageId
        Version = $Version
        CommandName = $CommandName
    }
}

# TODO: Load from a json config as alternative?
$defaultToolVers = @(
    New-DotnetToolDefinition -PackageId "cake.tool" -Version $CakeVersion -CommandName "dotnet-cake"
    New-DotnetToolDefinition -PackageId "gitversion.tool" -Version $GitVersionVersion -CommandName "dotnet-gitversion"
)

function Invoke-DotnetToolUpdate ($DotnetToolPath, $DotnetToolDefinitions) {

    # TODO: Long term, rely on .NET Core v3 tools setup, and remove this noise
    $dotnetVersion = [Version](dotnet --version)
    if($dotnetVersion -and $dotnetVersion.Major -eq 3) {
        & dotnet tool restore
    }

    # Check existing versions...
    $toollist = (dotnet tool list --tool-path $DotnetToolPath)
    $toolvers = ($toollist | Select-Object -Skip 2) | %{ $packageId, $version, $commandname = $_.Trim() -split '\s+'
        [pscustomobject] @{
            PackageId = $packageId
            Version = $version
            CommandName = $commandname
        }
    }
    # TODO: Load from a json config as alternative?
    $defaultToolVers = @(
        New-DotnetToolDefinition -PackageId "cake.tool" -Version $CakeVersion -CommandName "dotnet-cake"
        New-DotnetToolDefinition -PackageId "gitversion.tool" -Version $GitVersionVersion -CommandName "dotnet-gitversion"
    )

    if(!($DotnetToolDefinitions)) {
        $DotnetToolDefinitions = $defaultToolVers
    }
    foreach($tool in $DotnetToolDefinitions) {
        # New install
        if(!($toolvers | ?{ $_.PackageId -eq $tool.PackageId })) {
            Write-Information "Installing missing tool $($tool.PackageId) v $($tool.Version)"
            dotnet tool install $tool.PackageId --tool-path $DotnetToolPath --version $tool.Version
        }
        $dotnetvers = [version](dotnet --version)
        # Update version (update to specific version coming in dotnet sdk 3 :/)
        if($dotnetvers.Major -le 2 -and ($toolvers | ?{ $_.PackageId -eq $tool.PackageId -and $_.Version -ne $tool.Version })) {
            Write-Information "Installing updated tool $($tool.PackageId)"
            dotnet tool uninstall $tool.PackageId --tool-path $DotnetToolPath
            dotnet tool install $tool.PackageId --tool-path $DotnetToolPath --version $tool.Version
        }
    }
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

function Invoke-DotnetToolShims ($DotnetToolPath, $DotnetToolDefinitions) {
    # Hacky hack for path set to tools dir for now
    Add-PathToSearchPath -NewPath (Resolve-Path "$PSScriptPath").Path
    $toolPath = Resolve-Path $DotnetToolPath -ErrorAction SilentlyContinue
    if($toolPath) {
        Add-PathToSearchPath -NewPath $toolPath
    }

    # Hacky hack for gitversion until you can nicely define where it should be
    # TODO: Needs better xplat support
    $oldGitversion = Get-Command gitversion -ErrorAction SilentlyContinue
    $dotnetGitVersion = Get-Command dotnet-gitversion -ErrorAction SilentlyContinue
    if(!($oldGitversion) -and $dotnetGitVersion -and $env:ChocolateyInstall) {
        # Create a hacky shim
        $shimGen = "$($env:ChocolateyInstall)/tools/shimgen.exe"
        & $shimGen -o="$($toolPath.Path)/gitversion.exe" -p="$($dotnetGitVersion.Path)"
    }

    # TODO: With this setup, gitversion seems to need to be primed first...
    if($dotnetGitVersion) {
        & $dotnetGitVersion | Out-Null
    }
}

$dotnetToolsVersions = $defaultToolVers
if($DotnetToolDefinitionsPath -and (Test-Path $DotnetToolDefinitionsPath)) {
    Write-Information "Loading dotnet-tools definitions from $DotnetToolDefinitionsPath"
    $dotnetToolsVersions = (Get-Content $DotnetToolDefinitionsPath | ConvertFrom-Json)
}

Write-Information "Using dotnet-tools versions:"
Write-Information $dotnetToolsVersions

Invoke-DotnetToolUpdate -DotnetToolPath $DotnetToolPath -DotnetToolDefinitions $dotnetToolsVersions

# Hacky hacks gonna hack
Invoke-DotnetToolShims -DotnetToolPath $DotnetToolPath -DotnetToolDefinitions $dotnetToolsVersions

# Ensure we use the specific version we asked for
$dotnetcake = Get-Command "dotnet-cake" -ErrorAction SilentlyContinue
if(!($dotnetcake)) {
    throw "Could not get correct cake path"
}
$dotnetcake = $dotnetcake | Select -ExpandProperty Source
if(Test-Path $dotnetcake) {
    $dotnetcake = (Resolve-Path $dotnetcake).Path

    Write-Information "Running dotnet-cake from: $dotnetcake"

    Write-Verbose "Version check:"
    & $dotnetcake -Version
    & $dotnetcake $Script --target=$Target --verbosity=$Verbosity

} else {
    Write-Error "Could not find dotnet-cake to run build script"
    Write-Information "Using PATH: $($env:PATH)"
}

Pop-Location

# SIG # Begin signature block
# MIII5wYJKoZIhvcNAQcCoIII2DCCCNQCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUu0AJQvrJ7RDP7TtrLJ1H+NuP
# kA+gggY1MIIGMTCCBRmgAwIBAgIKYf5LqwAAAAACwjANBgkqhkiG9w0BAQUFADBt
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
# AgEVMCMGCSqGSIb3DQEJBDEWBBR/HuxzJZjeUUICj1d4o6igaOo7tDANBgkqhkiG
# 9w0BAQEFAASCAQCqs14APN03vd3EE3IQE5iAHzBn+CA1o9VXZ2AG+cO6Q6edokcH
# YcbAq9IRzaC55EGaEzjk7q7smTMBq9KibJ8kv0fgxsqVEPGD0kUlIeNZxWN6A9No
# VMrKh78xHRSoWHq6LvJPIi01BJly3BbwiZ1RCWDQO0hbkxjWBjsx0eeJh3yBEFcv
# sCerXxRdfftXPkarVttwLmxakwbiYAJJOgyybzwAFj07/wAq0a0M3ZElkERO2zxI
# OGwx3uvLQGya7kRKGN5XS5vSAqe+i0IYLJA7a4GLcyFG+f1SdMUyynMkCJgq3y20
# TWqMQiyDvd3+Kw2NMgxXoCPtPb2W4k6R93pR
# SIG # End signature block
