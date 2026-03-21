% startServer Start the Signal Analyzer example server
%   This script instantiates the MatlabHttpServer, registers the
%   SignalProcessor controller, and opens the React-based web UI.

% Ensure toolbox is on path
addpath(fullfile(pwd, '..', '..'));

disp("Starting Signal Analyzer example on port 8080...");
server = MatlabHttpServer(8080);

% Register the complex signal processor controller
server.register(SignalProcessor());

% Start the server
server.start();

% Open the UI
pSelf = fileparts(mfilename("fullpath"));
uiPath = fullfile(pSelf, 'index.html');
disp("Opening UI: " + uiPath);
web(uiPath, '-browser');

% Keep MATLAB active if running in -batch mode
if batchStartupOptionUsed
    disp("Press Ctrl+C to stop the server.");
    while true
        pause(1);
    end
end
