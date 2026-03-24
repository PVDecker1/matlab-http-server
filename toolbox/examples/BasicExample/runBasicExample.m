% Ensure toolbox is on path
exampleDir = fileparts(mfilename("fullpath"));
addpath(fullfile(exampleDir, '..', '..'));

% Start a basic HTTP server
disp("Starting BasicExample on port 8080...");
server = MatlabHttpServer(8080);
server.register(BasicController());
server.start();

disp("Server running. Test with:");
disp("  # Linux / macOS / PowerShell (Recommended)");
disp("  curl http://localhost:8080/api/hello");
disp("  curl http://localhost:8080/api/echo -d '{""msg"":""hi""}' -H ""Content-Type: application/json""");
disp(" ");
disp("  # Windows CMD (Note: requires escaped double-quotes)");
disp("  curl http://localhost:8080/api/echo -d ""{\""msg\"":\""hi\""}"" -H ""Content-Type: application/json""");

% Keep MATLAB running if in batch mode
if batchStartupOptionUsed
    disp("Press Ctrl+C to exit.");
    while true
        pause(1);
    end
end
