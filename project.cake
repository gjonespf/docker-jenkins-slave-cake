


Task("Init")
    .IsDependentOn("PFInit")
    .IsDependentOn("Generate-Version-File-PF")
    .IsDependentOn("Invoke-DockerLogin")
	.Does(() => {
		Information("Init");
    });

BuildParameters.Tasks.CleanTask
    .IsDependentOn("PFInit")
    .IsDependentOn("Generate-Version-File-PF")
    .Does(() => {
    });

BuildParameters.Tasks.RestoreTask
    .Does(() => {
    });

BuildParameters.Tasks.BuildTask
    .IsDependentOn("PFInit")
    .IsDependentOn("Invoke-DockerLogin")
    .IsDependentOn("ConfigureDockerDetails")
	.IsDependentOn("Build-Docker")
    .Does(() => {
    });

Task("UnitTest")
    .Does(() => {
        });
        
Task("CodeTest")
    .Does(() => {
        });

BuildParameters.Tasks.PackageTask
    .IsDependentOn("PFInit")
	.IsDependentOn("Package-GenerateReleaseVersion")
	.IsDependentOn("Package-Docker")
	.IsDependentOn("Create-Nuget-Packages")
    .IsDependentOn("Package-CopyReleaseArtifacts")
    ;

Task("Publish")
    .IsDependentOn("PFInit")
    .IsDependentOn("Generate-Version-File-PF")
	.IsDependentOn("Publish-Artifacts")
	.IsDependentOn("Publish-PFDocker")
	//.IsDependentOn("Publish-PFDockerReleaseInformation")
	//.IsDependentOn("Publish-NotifyReleaseTeams")
	.Does(() => {
	});


