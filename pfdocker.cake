#addin nuget:?package=Cake.Docker&version=0.9.3
//#addin nuget:?package=Cake.Git&version=0.17.0

#load "nuget:https://nuget.powerfarming.co.nz/api/odata?package=Cake.Recipe.PFHelpers&version=0.1.0"

#addin "nuget:https://www.nuget.org/api/v2?package=Newtonsoft.Json"
using Newtonsoft.Json;

public class DockerDetails
{
    public string ImageName { get; set; }
    public string ImageDescription { get; set; }
    public string ImageUrl { get; set; }
    public string GitUrl { get; set; }

    public string BuildId { get;set; }
    public string[] BuildArguments { get; set; }

    public string[] LocalTags { get; set; }
    public string DefaultLocal { get;set; }
    public string[] RemoteTags { get; set; }
    public string DefaultRemote { get;set; }
}

public class ProjectProperties
{
    public string ImageName { get; set; }
    public string ImageDescription { get; set; }
    public string ImageUrl { get; set; }
    public string GitUrl { get; set; }

    public string DefaultUser { get;set; }
    public string DefaultRemote { get;set; }
    public string DefaultLocal { get;set; }
    public string DefaultTag { get;set; }
}

public DockerDetails GetDockerDetails()
{
    DockerDetails ret = new DockerDetails();

    var propertiesFilePath = "./properties.json";
    var imageName = "UNKNOWN";
    var imageDesc = "UNKNOWN";
    var imageUrl = "UNKNOWN";
    var repoDir = DirectoryPath.FromString(".");
    var buildNumber = "UNKNOWN";
    var semVer = "UNKNOWN";

    if(PFBuildVersion == null) {
        throw new ApplicationException("PFBuildVersion is missing");
    }

    ProjectProperties props = new ProjectProperties();
    if(!string.IsNullOrEmpty(BuildNumber)) {
        buildNumber = BuildNumber;
    }
    if(!string.IsNullOrEmpty(PFBuildVersion.SemVersion)) {
        semVer = PFBuildVersion.SemVersion;
    }
    if(FileExists(propertiesFilePath)) {
        var jsonData = String.Join(System.Environment.NewLine, System.IO.File.ReadAllLines(propertiesFilePath));
        props = JsonConvert.DeserializeObject<ProjectProperties>(jsonData);
    }

    var tip = GitLogTip(repoDir);
    var currentBranch = GitBranchCurrent(repoDir);
    var buildDate = DateTime.Now;

    // Update DockerDetails
    if(!string.IsNullOrEmpty(props.ImageName)) {
        ret.ImageName = props.ImageName;
    }
    if(!string.IsNullOrEmpty(props.ImageDescription)) {
        ret.ImageDescription = props.ImageDescription;
    }
    if(!string.IsNullOrEmpty(props.ImageUrl)) {
        ret.ImageUrl = props.ImageUrl;
    }
    ret.GitUrl = currentBranch.Remotes.First().Url;

    // Update DockerDetails.BuildArguments
    var buildArgs = new string[] {
        "COMMIT_ID="+tip.Sha,
        "GIT_COMMIT="+tip.Sha,
        "GIT_BRANCH="+currentBranch.FriendlyName,
        "GIT_COMMITDATE="+GetRFCDate(tip.Committer.When.DateTime),
        "BUILD_NUMBER="+buildNumber,
        "GIT_URL="+ret.GitUrl,
        "BUILD_DATE="+GetRFCDate(buildDate),
        "BUILD_VERSION="+semVer,

        "IMAGE_NAME="+ret.ImageName,
        "IMAGE_DESC="+ret.ImageDescription,
        "IMAGE_URL="+ret.ImageUrl
    };
    ret.BuildArguments = buildArgs;

    // Tags
    var cleanBranchName = currentBranch.FriendlyName.Replace("/", "-").Replace("\\", "-");

    ret.LocalTags =  new string[] { 
                    (props.DefaultUser + "/" + ret.ImageName+":"+semVer), 
                    (props.DefaultUser + "/" + ret.ImageName+":"+cleanBranchName),
    };
    ret.DefaultLocal = (props.DefaultUser + "/" + ret.ImageName+":"+semVer);

    ret.RemoteTags =  new string[] { 
                    props.DefaultRemote + "/" + props.DefaultUser + "/" + (ret.ImageName+":"+semVer), 
                    props.DefaultRemote + "/" + props.DefaultUser + "/" + (ret.ImageName+":"+cleanBranchName),
    };
    ret.DefaultRemote = props.DefaultRemote + "/" + props.DefaultUser + "/" + (ret.ImageName+":"+semVer);

    return ret;
}

private string GetRFCDate(DateTime dateTime)
{
    DateTime UtcDateTime = TimeZoneInfo.ConvertTimeToUtc(dateTime);
    return UtcDateTime.ToString("yyyy-MM-dd'T'HH:mm:ss.fffzzz", System.Globalization.DateTimeFormatInfo.InvariantInfo);        
}

private string Information(DockerDetails deets)
{
    StringBuilder b = new StringBuilder();

    b.AppendLine("ImageName: "+deets.ImageName);

    b.AppendLine("Args:");
    foreach(var arg in deets.BuildArguments)
    {
        b.AppendLine(arg);
    }

    return b.ToString();
}

Task("Build-Docker")
    .IsDependentOn("PFInit")
	.Does(() => {
        var dockerDetails = GetDockerDetails();
        Information("Docker build with args:");
        Information(dockerDetails);

        var dockerFilePath = File("./Dockerfile");
        var dockerFileDir = Directory(".");
        if(FileExists(dockerFilePath)) {
            var buildSettings = new DockerImageBuildSettings() { 
                BuildArg = dockerDetails.BuildArguments,
                Tag = dockerDetails.LocalTags.ToArray(),
            };
            Verbose("Using dockerfile: "+dockerFilePath);
            Verbose("Image: "+dockerDetails.ImageName);
            Verbose(dockerDetails.BuildArguments);
            DockerBuild(buildSettings, dockerFileDir);
        } else {
            Error("Docker file not found! Used: "+ dockerFilePath);
        }
    });

Task("Package-Docker")
    .IsDependentOn("PFInit")
    .IsDependentOn("Generate-Version-File-PF")
	.Does(() => {
        Information("Docker build with args:");
        var dockerDetails = GetDockerDetails();
        Information(dockerDetails);
        var sourceTag = dockerDetails.LocalTags.First();
        // Simply apply remote tags
         foreach(var tagRef in dockerDetails.RemoteTags)
         {
             Information("Packaging tag: "+tagRef);
             DockerTag(sourceTag, tagRef);
         }
    });

Task("Publish-PFDocker")
    .IsDependentOn("PFInit")
    .IsDependentOn("Generate-Version-File-PF")
	.Does(() => {
        var dockerDetails = GetDockerDetails();
        foreach(var tagRef in dockerDetails.RemoteTags)
        {
            var dockerPushSettings = new DockerImagePushSettings() {
            };
            Information("Pushing tag: "+tagRef);
            DockerPush(dockerPushSettings, tagRef);
        }
    });
