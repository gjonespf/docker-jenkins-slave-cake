// Self-referential inception lol
#load "nuget:https://nuget.powerfarming.co.nz/api/odata?package=PowerFarming.PowerShell.BuildTools&version=0.1.30"
#load "project.cake"

//Environment.SetVariableNames();

var target = Argument("target", "Default");

Task("Init")
    .IsDependentOn("PFCakeInit")
    .IsDependentOn("ProjInit")
    .Does(() =>
{
    solution.PrintParameters();
    solution.Init();
});

Task("Clean")
    .IsDependentOn("CleanPackage")
    .IsDependentOn("ProjClean")
    .IsDependentOn("Init")
    .Does(() =>
{
    foreach(var project in solution.AllProjects.OrderBy(p => p.ProjectPath.FullPath))
    {
        Information("Now cleaning project: "+project.ProjectName+" at path "+project.ProjectPath.FullPath);
        project.Clean();
    }
});

Task("CleanPackage")
    .IsDependentOn("Init")
    .Does(() =>
{
    foreach(var project in solution.AllProjects.OrderBy(p => p.ProjectPath.FullPath))
    {
        Information("Now cleaning packages for project: "+project.ProjectName+" at path "+project.ProjectPath.FullPath);
        project.CleanPackage();
    }
});

Task("Build")
    .IsDependentOn("Clean")
    .IsDependentOn("ProjBuild")
    .IsDependentOn("Init")
    .Does(() =>
{
    foreach(var project in solution.AllProjects.OrderBy(p => p.ProjectPath.FullPath))
    {
        Information("Now building project: "+project.ProjectName+" at path "+project.ProjectPath.FullPath);
        project.Build();
    }
});

Task("Package")
    // TODO: Some quick checks to see if built this "run"
//    .IsDependentOn("Build")
    .IsDependentOn("CleanPackage")
    .IsDependentOn("ProjPackage")
    .IsDependentOn("Init")
    .Does(() =>
{
    foreach(var project in solution.AllProjects.OrderBy(p => p.ProjectPath.FullPath))
    {
        Information("Now packaging project: "+project.ProjectName+" at path "+project.ProjectPath.FullPath);
        project.Package();
    }
});

Task("Test")
    .IsDependentOn("Init")
    .IsDependentOn("ProjTest")
    // TODO: Some quick checks to see if built this "run"
//    .IsDependentOn("Build")
    .Does(() =>
{
    foreach(var project in solution.AllProjects.OrderBy(p => p.ProjectPath.FullPath))
    {
        Information("Now testing project: "+project.ProjectName+" at path "+project.ProjectPath.FullPath);
        project.Test();
    }
});

Task("Publish")
    .IsDependentOn("Init")
    .IsDependentOn("ProjPublish")
    // TODO: Some quick checks to see if packaged this "run"
//    .IsDependentOn("Package")
    .Does(() =>
{
    foreach(var project in solution.AllProjects.OrderBy(p => p.ProjectPath.FullPath))
    {
        Information("Now publishing project: "+project.ProjectName+" at path "+project.ProjectPath.FullPath);
        project.Publish();
    }
});

Task("Default")
    .IsDependentOn("CleanPackage")
    .IsDependentOn("Init")
    .IsDependentOn("Build")
    .Does(() =>
{
});

RunTarget(target);
