#load "nuget:http://nuget-public.devinf.powerfarming.co.nz/api/v2?package=Cake.Recipe.PF&version=0.3.4-alpha0056"
#load "nuget:http://nuget-public.devinf.powerfarming.co.nz/api/v2?package=Cake.Recipe.PFHelpers&version=0.7.0-dncore-cake-0-3-0084"

var buildDefaultsFile = "./properties.json";

Environment.SetVariableNames();

BuildParameters.Tasks.DefaultTask
    .IsDependentOn("Build");

// TODO: Load buildDefaultsFile as defaults, override with stuff from project.cake just in case
#load "project-tasks.cake"
#load "project.cake"

BuildParameters.PrintParameters(Context);

ToolSettings.SetToolSettings(context: Context);

RunTarget(BuildParameters.Target);
