function plan = buildfile
    % Create a plan from the tasks in this file
    plan = buildplan;

    % Add tasks
    plan("test") = matlab.buildtool.Task();
    plan("test").Actions = @testAction;
    
    plan("check") = matlab.buildtool.Task();
    plan("check").Actions = @checkAction;
    
    plan("package") = matlab.buildtool.Task();
    plan("package").Actions = @packageAction;
    
    plan("ci") = matlab.buildtool.Task();
    plan("ci").Description = "Full CI pipeline";
    plan("ci").Dependencies = ["check", "test", "package"];

    % Default task is 'test'
    plan.DefaultTasks = "test";
    
end

function testAction(context)
    % Run the full test suite with code coverage
    import matlab.unittest.TestRunner
    import matlab.unittest.plugins.CodeCoveragePlugin
    import matlab.unittest.plugins.codecoverage.CoverageReport
    import matlab.unittest.plugins.codecoverage.CoberturaFormat
    
    suite = testsuite("tests");
    runner = TestRunner.withTextOutput;
    
    covFolder = fullfile("build", "coverage");
    if ~exist(covFolder, 'dir')
        mkdir(covFolder);
    end
    
    % Cobertura and HTML
    xmlFile = fullfile(covFolder, "coverage.xml");
    
    % Target only runtime .m files in toolbox/ and its subfolders,
    % excluding documentation and examples.
    allFiles = dir(fullfile("toolbox", "**", "*.m"));
    allFiles = allFiles(~[allFiles.isdir]);
    sourceFiles = fullfile({allFiles.folder}, {allFiles.name});
    
    % Exclude documentation and examples from runtime coverage checks.
    isExample = contains(sourceFiles, fullfile("toolbox", "examples"));
    isDoc = contains(sourceFiles, fullfile("toolbox", "doc"));
    sourceFiles = sourceFiles(endsWith(sourceFiles, ".m") & ~isExample & ~isDoc);
    
    % Use multiple formats in one plugin call
    formats = [CoverageReport(covFolder), CoberturaFormat(xmlFile)];
    
    runner.addPlugin(CodeCoveragePlugin.forFile(sourceFiles, ...
        'Producing', formats));
        
    results = runner.run(suite);
    
    if any([results.Failed]) || any([results.Incomplete])
        error("test:Failed", "One or more tests failed or were incomplete.");
    end
    
    % Check coverage threshold
    addpath("scripts");
    checkCoverage(xmlFile, 0.90);
end

function checkAction(context)
    % Run CodeIssuesTask on toolbox/
    issues = codeIssues("toolbox");
    if ~isempty(issues.Issues)
        disp(issues.Issues);
    end
end

function packageAction(context)
    % Package the toolbox
    prjFile = "matlab-http-server.prj";
    outFile = "matlab-http-server.mltbx";

    % Check for GITHUB_REF_NAME environment variable to set version
    version = string(getenv("GITHUB_REF_NAME"));
    if startsWith(version, "v")
        version = extractAfter(version, 1);
        fprintf('Setting toolbox version to %s (from GITHUB_REF_NAME)\n', version);

        opts = matlab.addons.toolbox.ToolboxOptions(prjFile);
        opts.ToolboxVersion = version;
        opts.OutputFile = outFile;

        fprintf('Packaging into %s...\n', outFile);
        matlab.addons.toolbox.packageToolbox(opts);
    else
        fprintf('Packaging %s into %s...\n', prjFile, outFile);
        matlab.addons.toolbox.packageToolbox(prjFile, outFile);
    end
end
