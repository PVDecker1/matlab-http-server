disp("Starting MultiControllerExample on port 8081...");
server = MatlabHttpServer(8081);

% Register multiple controllers
server.register(UserController());
server.register(AdminController());

server.start();

disp("Endpoints available:");
disp("  GET  /api/users");
disp("  GET  /api/admin/status");

if ~usejava('desktop')
    disp("Press Ctrl+C to exit.");
    while true
        pause(1);
    end
end