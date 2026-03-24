%% 
% Ensure toolbox is on path
exampleDir = fileparts(mfilename("fullpath"));
addpath(fullfile(exampleDir, '..', '..'));

disp("Starting MultiControllerExample on port 8081...");
server = MatlabHttpServer(8081);

% Register multiple controllers
server.register(UserController());
server.register(AdminController());

server.start();

disp("Endpoints available:");
disp("  GET  /api/users");
disp("  GET  /api/admin/status");

if batchStartupOptionUsed
    disp("Press Ctrl+C to exit.");
    while true
        pause(1);
    end
end
