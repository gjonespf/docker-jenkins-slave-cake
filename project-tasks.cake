BuildParameters.SetParameters(context: Context,
                            buildSystem: BuildSystem,
                            sourceDirectoryPath: "./src",
                            title: "docker-jenkins-slave-cake",
                            repositoryOwner: "gjones@powerfarming.co.nz",
                            repositoryName: "docker-jenkins-slave-cake",
                            shouldPostToMicrosoftTeams: true,
                            shouldRunGitVersion: true
                            );

GitVersion(new GitVersionSettings{
    ToolPath = Context.Tools.Resolve("dotnet-gitversion") ?? Context.Tools.Resolve("dotnet-gitversion.exe")
  });

Task("Clean-BuildVersion")
	.Does(() => {
        var versFiles = GetFiles("./**/AssemblyGeneratedVersion.json");
		Information("Clean-BuildVersion");
        foreach(var file in versFiles)
        {
            DeleteFile(file);
        }
    });

Task("Copy-BuildVersion")
	.Does(() => {
        // Copy versioning to BuildArtifacts for the moment...
        var artifactPath = MakeAbsolute(Directory("./BuildArtifacts/"));
        var buildFilePath = MakeAbsolute(new FilePath("./BuildVersion.json"));
        var packageFilePath = MakeAbsolute(new FilePath("./ReleaseVersion.json"));
        CopyFile(buildFilePath, new FilePath(artifactPath+"/BuildVersion.json"));
        CopyFile(packageFilePath, new FilePath(artifactPath+"/ReleaseVersion.json"));
    });

Task("Clean-ReleaseArtifacts")
	.Does(() => {
        var releasePath = MakeAbsolute(Directory("./ReleaseArtifacts/"));
        EnsureDirectoryExists(releasePath);
        DeleteDirectory(releasePath, recursive:true);
        EnsureDirectoryExists(releasePath);
    });

Task("Package-CopyReleaseArtifacts")
	.Does(() => {
        var artifactPath = MakeAbsolute(Directory("./BuildArtifacts/"));
        var releasePath = MakeAbsolute(Directory("./ReleaseArtifacts/"));
        EnsureDirectoryExists(releasePath);

        CopyFile(MakeAbsolute(new FilePath("./BuildVersion.json")), new FilePath(releasePath+"/BuildVersion.json"));
        CopyFile(MakeAbsolute(new FilePath("./ReleaseVersion.json")), new FilePath(releasePath+"/ReleaseVersion.json"));
        CopyFile(MakeAbsolute(new FilePath("./.artifactignore")), new FilePath(releasePath+"/.artifactignore"));

        // TODO: Add stuff here
    });

Task("CreateAssemblyInfoIfMissing")
	.Does(() => {
        // TODO: Is this needed anymore?
	});

Task("Invoke-DockerLogin")
.Does(() => {   
    var dockerRegistry = EnvironmentVariable("DOCKER-REGISTRYURI");
    var dockerUsername = EnvironmentVariable("DOCKER-REGISTRYUSER");
    var dockerPassword = EnvironmentVariable("DOCKER-REGISTRYPASS");
    if(string.IsNullOrEmpty(dockerUsername))
        throw new Exception("Could not get dockerUsername environment variable");
    if(string.IsNullOrEmpty(dockerPassword))
        throw new Exception("Could not get dockerPassword environment variable");

    if(!string.IsNullOrEmpty(dockerRegistry)) {
        Information("Ensuring docker login to registry: "+dockerRegistry);
        DockerLogin(new DockerRegistryLoginSettings{
            Password=dockerPassword,
            Username=dockerUsername
        }, dockerRegistry);   
    } else {
        // Defaults to 
        Information("Ensuring docker login to registry: "+"docker.io");
        DockerLogin(new DockerRegistryLoginSettings{
            Password=dockerPassword,
            Username=dockerUsername
        });   
    }
});
