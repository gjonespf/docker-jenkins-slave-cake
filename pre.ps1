#!/usr/bin/pwsh

#===============
# Functions
#===============

function Get-GitCurrentBranch {
    (git symbolic-ref --short HEAD)
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
    git fetch origin master
    git fetch origin develop
    git checkout master
    git checkout develop
    git checkout $CurrentBranch
}

function Invoke-GitFetchRemoteBranches($CurrentBranch) {
    $remotes = Get-GitRemoteBranches
    $locals = Get-GitLocalBranches
    foreach($remote in $remotes) {
        $local = $remote -replace "remotes/origin/",""
        if($locals -notcontains $local) {
            git checkout $remote --track
        }
    }
    git checkout $CurrentBranch
}

#===============
# Main
#===============

# Useful missing vars
$currentBranch = Get-GitCurrentBranch
$env:BRANCH_NAME=$env:GITBRANCH=$currentBranch

# Enable nuget caching
if($env:HTTP_PROXY) {
    $nuget = Get-Command nuget
    if($nuget)
    {
        Write-Host "Setting Nuget proxy to '$env:HTTP_PROXY'"
        & $nuget config -set http_proxy=$env:HTTP_PROXY
    }
    else {
        Write-Host "Couldn't find nuget to set cache"
    }
}

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
    Remove-GitLocalBranches -CurrentBranch $currentBranch
    Invoke-GitFetchGitflowBranches -CurrentBranch $currentBranch
    Invoke-GitFetchRemoteBranches -CurrentBranch $currentBranch

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
        # rm ./preauth.ps1
    }
}

