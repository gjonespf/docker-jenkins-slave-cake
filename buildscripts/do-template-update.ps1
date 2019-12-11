param([string]$destinationDir) 
#TODO: Pull in properties file

$pwd = Resolve-Path "$PSScriptRoot/.."

if (($destinationDir | Split-Path -Leaf) -eq "buildscripts") {
    $destinationDir = Resolve-Path "$destinationDir/.."
}

# TEST:
# $Path = Resolve-Path "..\.gitignore"
# $TextToFind = "# Deployment/compose/publicbrand-template"; $ReplaceWith = "TEST"
function Update-FileSearchAndReplace ($Path, $TextToFind, $ReplaceWith)
{
    $fileContents = Get-Content $Path
    $containsWord = $fileContents | ForEach-Object { $_ -match [System.Text.RegularExpressions.Regex]::Escape($TextToFind) }
    If($containsWord -contains $true)
    {
        Write-Host "Updating file '$Path'"
        ($fileContents) | ForEach-Object { $_ -replace $TextToFind , $ReplaceWith } | 
        Set-Content $Path
    }
}

# TODO: Possibly resolve project properties.json first, then use it to help update other stuff here

Write-Host "Updating with directory '$($destinationDir)' with template files from '$pwd'"

# Jenkins file most important
Copy-Item -Force $pwd\Jenkinsfile $destinationDir\

# Base scripts
Copy-Item -Force $pwd\build.ps1 $destinationDir\
Copy-Item -Force $pwd\pre.ps1 $destinationDir\
New-Item -ItemType Directory -Force -Path $destinationDir\buildscripts | Out-Null
Copy-Item -Force $pwd\buildscripts\*.ps1 $destinationDir\buildscripts\
New-Item -ItemType Directory -Force -Path $destinationDir\.config\ | Out-Null
Copy-Item -Force $pwd\.config\*.json $destinationDir\.config\
Copy-Item -Force $pwd\GitVersion.yml $destinationDir\
Copy-Item -Force $pwd\.gitignore $destinationDir\
Copy-Item -Force $pwd\.dockerignore $destinationDir\
Copy-Item -Force $pwd\.artifactignore $destinationDir\
Update-FileSearchAndReplace -Path "$destinationDir\.gitignore" -TextToFind "# Deployment/compose/publicbrand-template" -ReplaceWith "Deployment/compose/publicbrand-template"

# Cake setup
New-Item -ItemType Directory -Force -Path $destinationDir\tools | Out-Null
Copy-Item -Force $pwd\tools\*.config $destinationDir\Tools

# VSCode
New-Item -ItemType Directory -Force -Path $destinationDir\.vscode | Out-Null
Copy-Item -Recurse -Force $pwd\.vscode\* $destinationDir\.vscode

# Dist files likely needed
Copy-Item -Force $pwd\SiteTemplate.Dockerfile $destinationDir\Dockerfile
Copy-Item -Force $pwd\SiteTemplate.properties.json $destinationDir\properties.json.dist
Copy-Item -Force $pwd\SiteTemplate.project.cake $destinationDir\project.cake.dist

# Overrides, these should always be updated
Copy-Item -Force $pwd\SiteTemplate.SiteEnvironment.json $destinationDir\SiteEnvironment.json
Copy-Item -Force $pwd\setup.cake $destinationDir\setup.cake
Copy-Item -Force $pwd\README.Template.md $destinationDir\README.Template.md

# Manually add dist templates to ignore
# Deployment/compose/publicbrand-redirect-template
# Deployment/compose/publicbrand-template

# Build up deployment
New-Item -ItemType Directory -Force -Path $destinationDir\Deployment\compose | Out-Null
New-Item -ItemType Directory -Force -Path $destinationDir\Deployment\swarm | Out-Null
Copy-Item -Force $pwd\Deployment\*.ps1 $destinationDir\Deployment\
Copy-Item -Force $pwd\Deployment\*.sh $destinationDir\Deployment\
Copy-Item -Force $pwd\Deployment\*Dockerfile $destinationDir\Deployment\
Copy-Item -Force $pwd\Deployment\.gitignore $destinationDir\Deployment\

# Compose
New-Item -ItemType Directory -Force -Path $destinationDir\Deployment\compose\publicbrand-template | Out-Null
New-Item -ItemType Directory -Force -Path $destinationDir\Deployment\compose\publicbrand-redirect-template | Out-Null
Copy-Item -R -Force $pwd\Deployment\Compose\publicbrand-template\* $destinationDir\Deployment\compose\publicbrand-template\
Copy-Item -Force $pwd\Deployment\Compose\* $destinationDir\Deployment\compose\
# cp -R -Force $pwd\Deployment\Compose\publicbrand-redirect-template $destinationDir\Deployment\compose\publicbrand-redirect-template

# Nuspec
New-Item -ItemType Directory -Force -Path $destinationDir\nuspec\nuget | Out-Null
# TODO: Pull from proj file if exists?
Copy-Item -Force $pwd\nuspec\nuget\publicbrand-APPLICATIONNAME.Octopus.nuspec.dist $destinationDir\nuspec\nuget\publicbrand-APPLICATIONNAME.Octopus.nuspec.dist

# Remove old stuff shifted or no longer needed
Remove-Item $destinationDir\template-update-mmv2.ps1 -ErrorAction SilentlyContinue | Out-Null
Remove-Item $destinationDir\build.core.ps1 -ErrorAction SilentlyContinue | Out-Null     # Will be updated later when I can get it to work

