// #load nuget:https://www.myget.org/F/cake-contrib/api/v2?package=Cake.Recipe&prerelease
#load "nuget:https://nuget.powerfarming.co.nz/api/odata?package=Cake.Recipe.PF&version=0.1.2"

#load pfdocker.cake

Environment.SetVariableNames();

BuildParameters.SetParameters(context: Context,
                            buildSystem: BuildSystem,
                            sourceDirectoryPath: "./src",
                            title: "docker-jenkins-slave-cake",
                            repositoryOwner: "gjones@powerfarming.co.nz",
                            repositoryName: "docker-jenkins-slave-cake",
                            shouldPostToMicrosoftTeams: true,
                            shouldRunGitVersion: true
                            );

BuildParameters.PrintParameters(Context);

ToolSettings.SetToolSettings(context: Context);

Task("Init")
    .IsDependentOn("PFInit")
    .IsDependentOn("Generate-Version-File-PF")
	.Does(() => {
		Information("Init");
    });

BuildParameters.Tasks.CleanTask
    .IsDependentOn("PFInit")
    // .IsDependentOn("PFInit-Clean")
    .IsDependentOn("Generate-Version-File-PF")
    .Does(() => {
    });

BuildParameters.Tasks.RestoreTask.Task.Actions.Clear();
BuildParameters.Tasks.RestoreTask
	//.IsDependentOn("Package-Docker")
    .Does(() => {
    });

BuildParameters.Tasks.PackageTask.Task.Actions.Clear();
BuildParameters.Tasks.PackageTask
	.IsDependentOn("Package-Docker");

BuildParameters.Tasks.BuildTask.Task.Actions.Clear();
BuildParameters.Tasks.BuildTask
	.IsDependentOn("Build-Docker");

Task("Publish")
    .IsDependentOn("PFInit")
	.IsDependentOn("Publish-Artifacts")
	.IsDependentOn("Publish-PFDocker")
	.Does(() => {
	});



// Simplified...
Build.RunVanilla();
