% startServer Start the Signal Analyzer example server
%   This script instantiates the MatlabHttpServer, registers the
%   SignalProcessor controller, and opens the React-based web UI.

% Ensure toolbox is on path
pSelf = fileparts(mfilename("fullpath"));
addpath(fullfile(pSelf, '..', '..'));

preferredPort = 8088;
if evalin("base", "exist('signalAnalyzerPort','var')")
    try
        preferredPort = evalin("base", "signalAnalyzerPort");
    catch
    end
end

% Stop any previously launched Signal Analyzer server in this MATLAB session.
if evalin("base", "exist('signalAnalyzerServer','var')")
    oldServer = evalin("base", "signalAnalyzerServer");
    if isa(oldServer, "MatlabHttpServer")
        try
            oldServer.stop();
            delete(oldServer);
        catch
        end
    end
    evalin("base", "clear signalAnalyzerServer");
end

port = chooseSignalAnalyzerPort(preferredPort);
disp("Starting Signal Analyzer example on port " + port + "...");
server = MatlabHttpServer(port);

% Register the complex signal processor controller
server.register(SignalProcessor());

% Serve the example UI from the same server so the frontend and API share
% one origin and do not depend on file:// query-string behavior.
server.serveStatic(string(pSelf));

% Start the server
server.start();
assignin("base", "signalAnalyzerServer", server);
assignin("base", "signalAnalyzerPort", port);

% Open the UI
uiUrl = "http://localhost:" + port + "/";
disp("Opening UI: " + uiUrl);
web(uiUrl, '-browser');

% Keep MATLAB active if running in -batch mode
if batchStartupOptionUsed
    disp("Press Ctrl+C to stop the server.");
    while true
        pause(1);
    end
end

function port = chooseSignalAnalyzerPort(preferredPort)
    arguments
        preferredPort (1,1) double
    end

    if isPortAvailable(preferredPort)
        port = preferredPort;
        return;
    end

    warning("SignalAnalyzer:PortInUse", ...
        "Port %d is already in use. Selecting an available port automatically.", ...
        preferredPort);

    fallbackStart = preferredPort + 1;
    fallbackEnd = preferredPort + 25;
    for candidate = fallbackStart:fallbackEnd
        if isPortAvailable(candidate)
            port = candidate;
            return;
        end
    end

    error("SignalAnalyzer:NoAvailablePort", ...
        "Could not find a free port between %d and %d.", ...
        fallbackStart, fallbackEnd);
end

function tf = isPortAvailable(port)
    arguments
        port (1,1) double
    end

    tf = false;
    socket = [];
    try
        socket = java.net.ServerSocket(int32(port));
        tf = true;
    catch
        tf = false;
    end

    if ~isempty(socket)
        try
            socket.close();
        catch
        end
    end
end
