BuildParameters.SetParameters(context: Context,
                            buildSystem: BuildSystem,
                            sourceDirectoryPath: "./src",
                            title: "docker-jenkins-slave-cake",
                            repositoryOwner: "gjones@powerfarming.co.nz",
                            repositoryName: "docker-jenkins-slave-cake",
                            shouldPostToMicrosoftTeams: true,
                            shouldRunGitVersion: true
                            );

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

BuildParameters.Tasks.RestoreTask
	//.IsDependentOn("Package-Docker")
    .Does(() => {
    });

BuildParameters.Tasks.PackageTask
	.IsDependentOn("Package-Docker");

BuildParameters.Tasks.BuildTask
    .IsDependentOn("Generate-Version-File-PF")
	.IsDependentOn("Build-Docker");

Task("Publish")
	.IsDependentOn("Publish-Artifacts")
	.IsDependentOn("Publish-PFDocker")
	.Does(() => {
	});

