// Load your project specific stuff here

Task("ProjInit")
    .Does(() =>
{
    // Register project handlers?
    //Verbose("ProjInit");
    solution.DumpParameters();
});

Task("ProjClean")
    .Does(() =>
{
    //Verbose("ProjClean");
});


Task("ProjBuild")
    .Does(() =>
{
    //Verbose("ProjBuild");
});

Task("ProjPackage")
    .Does(() =>
{
    //Verbose("ProjPackage");
});

Task("ProjTest")
    .Does(() =>
{
    //Verbose("ProjTest");
});

Task("ProjPublish")
    .Does(() =>
{
    //Verbose("ProjPublish");
});


