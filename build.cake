// This is intended as a baseline cake build template
// NOTE: This file will be overwritten on self update, so use project.cake instead
#load "nuget:https://nuget.powerfarming.co.nz/api/odata?package=PowerFarming.PowerShell.BuildTools&prerelease"
#load "project.cake"

//Environment.SetVariableNames();

var target = Argument("target", "Default");

Task("Init")
    .Does(() =>
{
    solution.PrintParameters();
});

Task("Clean")
    .IsDependentOn("Init")
    .Does(() =>
{
    foreach(var project in solution.AllProjects)
    {
        var projectVersion = project.GetVersion();
        //Information("Now cleaning project: "+project.Name);
        //project.CleanPackage();
    }
});

Task("Build")
    .IsDependentOn("Init")
    .Does(() =>
{
});

Task("Package")
    // TODO: Some quick checks to see if built this "run"
//    .IsDependentOn("Build")
    .IsDependentOn("Init")
    .Does(() =>
{
  foreach(var project in solution.AllProjects)
  {
    var projectVersion = project.GetVersion();
    Information("Now packaging project version: "+projectVersion.InformationalVersion);
    project.Package();
  }
});

Task("Test")
    .IsDependentOn("Init")
    // TODO: Some quick checks to see if built this "run"
//    .IsDependentOn("Build")
    .Does(() =>
{
});

Task("Publish")
    .IsDependentOn("Init")
    // TODO: Some quick checks to see if packaged this "run"
//    .IsDependentOn("Package")
    .Does(() =>
{
  foreach(var project in solution.AllProjects)
  {
    var projectVersion = project.GetVersion();
    Information("Now publishing project version: "+projectVersion.InformationalVersion);
    project.Publish();
  }
});

Task("Default")
    .IsDependentOn("Init")
    .Does(() =>
{
});

RunTarget(target);
