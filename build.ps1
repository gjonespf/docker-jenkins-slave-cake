##########################################################################
# This is the Cake bootstrapper script for PowerShell.
# This file was downloaded from https://github.com/cake-build/resources
# Feel free to change this file to fit your needs.
##########################################################################

<#

.SYNOPSIS
This is a Powershell script to bootstrap a Cake build.

.DESCRIPTION
This Powershell script will download NuGet if missing, restore NuGet tools (including Cake)
and execute your Cake build script with the parameters you provide.

.PARAMETER Script
The build script to execute.
.PARAMETER Target
The build script target to run.
.PARAMETER Configuration
The build configuration to use.
.PARAMETER Verbosity
Specifies the amount of information to be displayed.
.PARAMETER Experimental
Tells Cake to use the latest Roslyn release.
.PARAMETER WhatIf
Performs a dry run of the build script.
No tasks will be executed.
.PARAMETER Mono
Tells Cake to use the Mono scripting engine.
.PARAMETER SkipToolPackageRestore
Skips restoring of packages.
.PARAMETER ScriptArgs
Remaining arguments are added here.

.LINK
https://cakebuild.net

#>

[CmdletBinding()]
Param(
    [string]$Script = "build.cake",
    [string]$Target = "Default",
    [ValidateSet("Release", "Debug")]
    [string]$Configuration = "Release",
    [ValidateSet("Quiet", "Minimal", "Normal", "Verbose", "Diagnostic")]
    [string]$Verbosity = "Verbose",
    [switch]$Experimental,
    [Alias("DryRun","Noop")]
    [switch]$WhatIf,
    [switch]$Mono,
    [switch]$SkipToolPackageRestore,
    [Parameter(Position=0,Mandatory=$false,ValueFromRemainingArguments=$true)]
    [string[]]$ScriptArgs
)

function MD5HashFile([string] $filePath)
{
    if ([string]::IsNullOrEmpty($filePath) -or !(Test-Path $filePath -PathType Leaf))
    {
        return $null
    }

    # Use Get-FileHash if support exists
    $getHashExists = Get-Command "Get-FileHash"
    if($getHashExists)
    {
        return (Get-FileHash -Path $filePath -Algorithm "MD5").Hash
    }    
    # Use System.Security.Cryptography.MD5 for MD5, if it exists
    elseif([System.Security.Cryptography.MD5]) 
    {
        [System.IO.Stream] $file = $null;
        [System.Security.Cryptography.MD5] $md5 = $null;
        try
        {
            $md5 = [System.Security.Cryptography.MD5]::Create()
            $file = [System.IO.File]::OpenRead($filePath)
            return [System.BitConverter]::ToString($md5.ComputeHash($file))
        }
        finally
        {
            if ($file -ne $null)
            {
                $file.Dispose()
            }
        }
    }
    else {
        throw "No MD5 support could be found, cannot continue"
    }
}

Write-Host "Preparing to run build script..."

if(!$PSScriptRoot){
    $PSScriptRoot = Split-Path $MyInvocation.MyCommand.Path -Parent
}

$TOOLS_DIR = Join-Path $PSScriptRoot "tools"
$ADDINS_DIR = Join-Path $TOOLS_DIR "Addins"
$MODULES_DIR = Join-Path $TOOLS_DIR "Modules"
$NUGET_EXE = Join-Path $TOOLS_DIR "nuget.exe"
$CAKE_EXE = Join-Path $TOOLS_DIR "Cake/Cake.exe"
$NUGET_URL = "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe"
$PACKAGES_CONFIG = Join-Path $TOOLS_DIR "packages.config"
$PACKAGES_CONFIG_MD5 = Join-Path $TOOLS_DIR "packages.config.md5sum"
$ADDINS_PACKAGES_CONFIG = Join-Path $ADDINS_DIR "packages.config"
$MODULES_PACKAGES_CONFIG = Join-Path $MODULES_DIR "packages.config"

# Should we use mono?
$UseMono = "";
if($Mono.IsPresent) {
    Write-Verbose -Message "Using the Mono based scripting engine."
    $UseMono = "-mono"
}

# Should we use the new Roslyn?
$UseExperimental = "";
if($Experimental.IsPresent -and !($Mono.IsPresent)) {
    Write-Verbose -Message "Using experimental version of Roslyn."
    $UseExperimental = "-experimental"
}

# Is this a dry run?
$UseDryRun = "";
if($WhatIf.IsPresent) {
    $UseDryRun = "-dryrun"
}

# Make sure tools folder exists
if ((Test-Path $PSScriptRoot) -and !(Test-Path $TOOLS_DIR)) {
    Write-Verbose -Message "Creating tools directory..."
    New-Item -Path $TOOLS_DIR -Type directory | out-null
}

# Make sure that packages.config exist.
if (!(Test-Path $PACKAGES_CONFIG)) {
    Write-Verbose -Message "Downloading packages.config..."
    try { (New-Object System.Net.WebClient).DownloadFile("https://cakebuild.net/download/bootstrapper/packages", $PACKAGES_CONFIG) } catch {
        Throw "Could not download packages.config."
    }
}

# Try find NuGet.exe using Get-Command if not exists
if (!($NUGET_EXE) -or !(Test-Path $NUGET_EXE)) {
    # Try grabbing using Get-Command, note no exe extension to allow xplat
    Write-Verbose -Message "Trying to find nuget.exe using Get-Command..."
    $NUGET_USING_GETCOMMAND = (Get-Command "nuget")
    if($NUGET_USING_GETCOMMAND) {
        $NUGET_EXE = $NUGET_USING_GETCOMMAND.Source
    }
}

# Try find NuGet.exe in path if not exists
if (!(Test-Path $NUGET_EXE)) {
    Write-Verbose -Message "Trying to find nuget.exe in PATH..."
    $existingPaths = $Env:Path -Split ';' | Where-Object { (![string]::IsNullOrEmpty($_)) -and (Test-Path $_ -PathType Container) }
    $NUGET_EXE_IN_PATH = Get-ChildItem -Path $existingPaths -Filter "nuget.exe" | Select -First 1
    if ($NUGET_EXE_IN_PATH -ne $null -and (Test-Path $NUGET_EXE_IN_PATH.FullName)) {
        Write-Verbose -Message "Found in PATH at $($NUGET_EXE_IN_PATH.FullName)."
        $NUGET_EXE = $NUGET_EXE_IN_PATH.FullName
    }
}

# Try download NuGet.exe if not exists
if (!(Test-Path $NUGET_EXE)) {
    Write-Verbose -Message "Downloading NuGet.exe..."
    try {
        (New-Object System.Net.WebClient).DownloadFile($NUGET_URL, $NUGET_EXE)
    } catch {
        Throw "Could not download NuGet.exe."
    }
}

# Save nuget.exe path to environment to be available to child processed
$ENV:NUGET_EXE = $NUGET_EXE

# Restore tools from NuGet?
if(-Not $SkipToolPackageRestore.IsPresent) {
    Push-Location
    Set-Location $TOOLS_DIR

    # Check for changes in packages.config and remove installed tools if true.
    [string] $md5Hash = MD5HashFile($PACKAGES_CONFIG)
    if((!(Test-Path $PACKAGES_CONFIG_MD5)) -Or
      ($md5Hash -ne (Get-Content $PACKAGES_CONFIG_MD5 ))) {
        Write-Verbose -Message "Missing or changed package.config hash..."
        Remove-Item * -Recurse -Exclude packages.config,nuget.exe
    }

    Write-Verbose -Message "Restoring tools from NuGet..."
    $NuGetOutput = Invoke-Expression "&`"$NUGET_EXE`" install -ExcludeVersion -OutputDirectory `"$TOOLS_DIR`""

    if ($LASTEXITCODE -ne 0) {
        Throw "An error occured while restoring NuGet tools."
    }
    else
    {
        $md5Hash | Out-File $PACKAGES_CONFIG_MD5 -Encoding "ASCII"
    }
    Write-Verbose -Message ($NuGetOutput | out-string)
    
    Pop-Location
}

# Restore addins from NuGet
if (Test-Path $ADDINS_PACKAGES_CONFIG) {
    Push-Location
    Set-Location $ADDINS_DIR

    Write-Verbose -Message "Restoring addins from NuGet..."
    $NuGetOutput = Invoke-Expression "&`"$NUGET_EXE`" install -ExcludeVersion -OutputDirectory `"$ADDINS_DIR`""

    if ($LASTEXITCODE -ne 0) {
        Throw "An error occured while restoring NuGet addins."
    }

    Write-Verbose -Message ($NuGetOutput | out-string)

    Pop-Location
}

# Restore modules from NuGet
if (Test-Path $MODULES_PACKAGES_CONFIG) {
    Push-Location
    Set-Location $MODULES_DIR

    Write-Verbose -Message "Restoring modules from NuGet..."
    $NuGetOutput = Invoke-Expression "&`"$NUGET_EXE`" install -ExcludeVersion -OutputDirectory `"$MODULES_DIR`""

    if ($LASTEXITCODE -ne 0) {
        Throw "An error occured while restoring NuGet modules."
    }

    Write-Verbose -Message ($NuGetOutput | out-string)

    Pop-Location
}

# Make sure that Cake has been installed.
if (!(Test-Path $CAKE_EXE)) {
    Throw "Could not find Cake.exe at $CAKE_EXE"
}

# Start Cake
Write-Host "Running build script..."
Invoke-Expression "& `"$CAKE_EXE`" `"$Script`" -target=`"$Target`" -configuration=`"$Configuration`" -verbosity=`"$Verbosity`" $UseMono $UseDryRun $UseExperimental $ScriptArgs"
exit $LASTEXITCODE

# SIG # Begin signature block
# MIIIvQYJKoZIhvcNAQcCoIIIrjCCCKoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUAIZ21UJKA5eLp+IHOZ2Rdicc
# ry6gggYLMIIGBzCCBO+gAwIBAgIKT93B1AAAAAACIzANBgkqhkiG9w0BAQUFADBt
# MRIwEAYKCZImiZPyLGQBGRYCbnoxEjAQBgoJkiaJk/IsZAEZFgJjbzEcMBoGCgmS
# JomT8ixkARkWDHBvd2VyZmFybWluZzElMCMGA1UEAxMccG93ZXJmYXJtaW5nLVBG
# TlotU1JWLTAyOC1DQTAeFw0xNzAxMTEyMDUxMzVaFw0xODAxMTEyMDUxMzVaMIGJ
# MRIwEAYKCZImiZPyLGQBGRYCbnoxEjAQBgoJkiaJk/IsZAEZFgJjbzEcMBoGCgmS
# JomT8ixkARkWDHBvd2VyZmFybWluZzEeMBwGA1UECxMVTmV3IFplYWxhbmQgV2hv
# bGVzYWxlMQswCQYDVQQLEwJJVDEUMBIGA1UEAxMLR2F2aW4gSm9uZXMwggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCsIG8CPKxGQ8QVPwT9RimGketdE8Xk
# snTl0w2/hZuw11D52G2cgYPmYNetylnEChR5XjHsOjO04+bs2jVPYhaPlynXlNmR
# GJlom4y6G/LYUbvLhifw/RzlfATpbDXiouqnx29zHl8/EafxQKM8G6VNyDQhvGHV
# wvjALTXdYH0MulOV9c/xwAdzWLGoDzPiomMZxWuJO3KWMd5j+3Mgq3vu+cnO63Ii
# EFnIbLHuAbKWF5F864v4u7Kqze1mX5dI6lWhewkF+xHvajCE7/mwEil7A4PsOqhe
# uk/tp7BKPMmFbK05CHpz2yfE9ZEAUldzf7l+t38GtWzSMcdP7MCqlT6tAgMBAAGj
# ggKKMIIChjAdBgNVHQ4EFgQU04lQfevQ+lUfNccaTbU1JW52eDcwHwYDVR0jBBgw
# FoAUwyl94sUGMISSqn1Dg21DQS+Tk4EwgekGA1UdHwSB4TCB3jCB26CB2KCB1YaB
# 0mxkYXA6Ly8vQ049cG93ZXJmYXJtaW5nLVBGTlotU1JWLTAyOC1DQSxDTj1QRk5a
# LVNSVi0wMjgsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNl
# cnZpY2VzLENOPUNvbmZpZ3VyYXRpb24sREM9cG93ZXJmYXJtaW5nLERDPWNvLERD
# PW56P2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFzcz1j
# UkxEaXN0cmlidXRpb25Qb2ludDCB2AYIKwYBBQUHAQEEgcswgcgwgcUGCCsGAQUF
# BzAChoG4bGRhcDovLy9DTj1wb3dlcmZhcm1pbmctUEZOWi1TUlYtMDI4LUNBLENO
# PUFJQSxDTj1QdWJsaWMlMjBLZXklMjBTZXJ2aWNlcyxDTj1TZXJ2aWNlcyxDTj1D
# b25maWd1cmF0aW9uLERDPXBvd2VyZmFybWluZyxEQz1jbyxEQz1uej9jQUNlcnRp
# ZmljYXRlP2Jhc2U/b2JqZWN0Q2xhc3M9Y2VydGlmaWNhdGlvbkF1dGhvcml0eTAl
# BgkrBgEEAYI3FAIEGB4WAEMAbwBkAGUAUwBpAGcAbgBpAG4AZzALBgNVHQ8EBAMC
# B4AwEwYDVR0lBAwwCgYIKwYBBQUHAwMwNAYDVR0RBC0wK6ApBgorBgEEAYI3FAID
# oBsMGWdqb25lc0Bwb3dlcmZhcm1pbmcuY28ubnowDQYJKoZIhvcNAQEFBQADggEB
# AKydtpDgRWqG4A/jxGfjvImDK0yvbgVxVF4PofBLXext+lBUViXgy7WDz02mttnI
# rV1z/5uU0KvekveUnQSKx00uSlCb//nqnv53CbRj20bXPDGgDMVDtw+ZB87R1vD9
# g6H+lFrbPKK1q1L25E5a7wWH/L3g/9Sq2QS6ezmSfU2FSNKaphbP/55tVWU1g03M
# Ai7DvHDFB0AEaxqpviyWbzrEt3mGOeG/3p8+KrKWqjfQnZ6wsdFKQsvpSwaxrLut
# Z3p0vey2tOtO1ZXYwbL1gMpymMTlDjBQOEMBGAocUBzVYUXU9FuQmY5Y2cWXz6kq
# rHWWJpQlDDodXIm+uoy3lFwxggIcMIICGAIBATB7MG0xEjAQBgoJkiaJk/IsZAEZ
# FgJuejESMBAGCgmSJomT8ixkARkWAmNvMRwwGgYKCZImiZPyLGQBGRYMcG93ZXJm
# YXJtaW5nMSUwIwYDVQQDExxwb3dlcmZhcm1pbmctUEZOWi1TUlYtMDI4LUNBAgpP
# 3cHUAAAAAAIjMAkGBSsOAwIaBQCgeDAYBgorBgEEAYI3AgEMMQowCKACgAChAoAA
# MBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEEMBwGCisGAQQBgjcCAQsxDjAMBgor
# BgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBQnuX8/cOEgVDBlQPZpa4UaY39zlzAN
# BgkqhkiG9w0BAQEFAASCAQBwAtSc2HQP22OKw6VbVpmzw6UqWlnPTJeFV2bKbVlu
# UF8CqKfO+meE1WQdvH+084XvxvYqjZORqBMYg+/XfTFg28M6veO5ZK2n2FWdXWrB
# dDvyuhZth6whDiI9QTFQPhdbgYji/d+/mWgXCoLsa+arwiDRy4ezTNgkuTXGrGHE
# afbXGxnBeeEn7/fJzWk9fRR/tN9JD9jLBTvn/8rB7IELt/o0AR/v9Uk3zhRaOz/Y
# fSWJthD8BYaY9+EwGUdWkwpbcAR5+rOQdJu4mzN5KwMDyvssA2KDcLjrSPM2bD0d
# zrj8ZwCeVbsODWNX93NG1yC0S8xBABUhfhQMPUSvHlpK
# SIG # End signature block
