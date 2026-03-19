classdef MatlabHttpServer < handle
    % MatlabHttpServer Primary entry point for the HTTP server framework
    %   A zero-dependency HTTP server based on tcpserver. Manages the socket
    %   layer, accumulates partial reads, parses HTTP requests, and dispatches
    %   them to registered ApiController instances via the Router.

    properties (SetAccess = private)
        Port (1,1) double
        AllowedOrigin (1,1) string = "*"
    end

    properties (Access = private)
        TcpServer % The underlying tcpserver instance
        Router (1,1) mhs.Router
        ClientStates (1,1) dictionary = dictionary() % map of ClientAddress to BufferAccumulator
    end

    methods
        function obj = MatlabHttpServer(port, options)
            % MATLABHTTPSERVER Construct an instance of MatlabHttpServer
            arguments
                port (1,1) double = 8080
                options.AllowedOrigin (1,1) string = "*"
            end

            obj.Port = port;
            obj.AllowedOrigin = options.AllowedOrigin;
            obj.Router = mhs.Router();
        end

        function register(obj, controller)
            % REGISTER Register an ApiController with the server
            arguments
                obj (1,1) MatlabHttpServer
                controller (1,1) mhs.ApiController
            end
            obj.Router.register(controller);
        end

        function start(obj)
            % START Start listening for incoming HTTP connections
            arguments
                obj (1,1) MatlabHttpServer
            end

            if ~isempty(obj.TcpServer)
                disp("[matlab-http-server] Server is already running on port " + obj.Port);
                return;
            end

            try
                obj.TcpServer = tcpserver("0.0.0.0", obj.Port);
                obj.TcpServer.ConnectionChangedFcn = @obj.onConnectionChanged;
                configureCallback(obj.TcpServer, "byte", 1, @obj.onDataReceived);
                disp("[matlab-http-server] Server started on port " + obj.Port);
            catch ME
                error("MatlabHttpServer:StartFailed", "Failed to start server on port %d: %s", obj.Port, ME.message);
            end
        end

        function stop(obj)
            % STOP Stop the server and release the port
            arguments
                obj (1,1) MatlabHttpServer
            end

            if ~isempty(obj.TcpServer)
                delete(obj.TcpServer);
                obj.TcpServer = [];
                obj.ClientStates = dictionary();
                disp("[matlab-http-server] Server stopped.");
            end
        end

        function delete(obj)
            % DELETE Destructor
            obj.stop();
        end

        function processRequestForTesting(obj, src, rawBytes)
            % PROCESSREQUESTFORTESTING Public wrapper for testing processRequest
            obj.processRequest(src, rawBytes);
        end
    end

    methods (Access = private)
        function onConnectionChanged(obj, src, event)
            % ONCONNECTIONCHANGED Handle new or closed TCP connections
            try
                if ~isempty(src.ClientAddress)
                    % Track client state
                    clientKey = string(src.ClientAddress) + ":" + string(src.ClientPort);
                    obj.ClientStates(clientKey) = mhs.internal.BufferAccumulator();
                end
            catch ME
                disp("[matlab-http-server ERROR] Connection error: " + ME.message);
            end
        end

        function onDataReceived(obj, src, event)
            % ONDATARECEIVED Handle incoming TCP data
            try
                if isempty(src.ClientAddress)
                    return;
                end

                clientKey = string(src.ClientAddress) + ":" + string(src.ClientPort);

                % Fallback if connection event was missed
                if ~isKey(obj.ClientStates, clientKey)
                    obj.ClientStates(clientKey) = mhs.internal.BufferAccumulator();
                end

                accumulator = obj.ClientStates(clientKey);

                % Read all available bytes
                numBytes = src.NumBytesAvailable;
                if numBytes > 0
                    bytes = read(src, numBytes, "uint8");
                    accumulator.add(bytes');

                    if accumulator.isComplete()
                        obj.processRequest(src, accumulator.getBuffer());
                        % Disconnect after handling (no keep-alive)
                        obj.ClientStates(clientKey) = [];
                        % MathWorks tcpserver doesn't have an explicit close for individual clients
                        % other than writing the response and letting the client close or closing the whole server
                    end
                end
            catch ME
                disp("[matlab-http-server ERROR] Data read error: " + ME.message);
            end
        end

        function processRequest(obj, src, rawBytes)
            % PROCESSREQUEST Parse request, handle OPTIONS, and dispatch
            try
                req = mhs.internal.HttpParser.parse(rawBytes);
                res = mhs.HttpResponse(src, obj.AllowedOrigin);

                if strcmpi(req.Method, "OPTIONS")
                    mhs.internal.CorsHandler.handlePreflight(res);
                else
                    obj.Router.dispatch(req, res);
                end
            catch ME
                disp("[matlab-http-server ERROR] Request processing error: " + ME.message);

                % Attempt to send 400 Bad Request
                try
                    res = mhs.HttpResponse(src, obj.AllowedOrigin);
                    res.status(400).send("Bad Request");
                catch
                    % Ignore further errors
                end
            end
        end
    end
end