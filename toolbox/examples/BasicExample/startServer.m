% Start a basic HTTP server
disp("Starting BasicExample on port 8080...");
server = MatlabHttpServer(8080);
server.register(BasicController());
server.start();

disp("Server running. Test with:");
disp("  curl http://localhost:8080/api/hello");
disp("  curl http://localhost:8080/api/echo -d '{""msg"":""hi""}' -H ""Content-Type: application/json""");

% Keep MATLAB running if in batch mode
if ~usejava('desktop')
    disp("Press Ctrl+C to exit.");
    while true
        pause(1);
    end
end