#load "nuget:https://nuget.powerfarming.co.nz/api/odata?package=Cake.Recipe.PF&version=0.3.3"
#load "nuget:https://nuget.powerfarming.co.nz/api/odata?package=Cake.Recipe.PFHelpers&version=0.7.0-alpha0018"

Environment.SetVariableNames();

#load "project.cake"

BuildParameters.PrintParameters(Context);

ToolSettings.SetToolSettings(context: Context);

// Simplified...
Build.RunVanilla();
