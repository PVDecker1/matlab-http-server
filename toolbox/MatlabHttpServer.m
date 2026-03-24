classdef MatlabHttpServer < handle
    % MatlabHttpServer Primary entry point for the HTTP server framework
    %   A zero-dependency HTTP server. Manages the transport layer, 
    %   dispatches requests to registered ApiController instances via the 
    %   Router, and handles static file serving.

    properties (SetAccess = private)
        Port (1,1) double
        AllowedOrigin (1,1) string = "*"
    end

    properties (Access = {?mhs.internal.TcpTransport, ?matlab.unittest.TestCase})
        Transport    % mhs.internal.TcpTransport instance
    end

    properties (Access = private)
        Router (1,1) mhs.Router
        StaticHandlers (1,:) cell = {}
        DataListener = event.listener.empty
        IsStarted (1,1) logical = false
    end

    methods
        function obj = MatlabHttpServer(port, options)
            % MATLABHTTPSERVER Construct an instance of MatlabHttpServer
            arguments
                port (1,1) double = 8080
                options.AllowedOrigin (1,1) string = "*"
                options.Transport (1,1) string = "java"
            end

            obj.Port = port;
            obj.AllowedOrigin = options.AllowedOrigin;
            obj.Router = mhs.Router();
            obj.Transport = obj.createTransport(options.Transport, port);
        end

        function register(obj, controller)
            % REGISTER Register an ApiController with the server
            arguments
                obj (1,1) MatlabHttpServer
                controller (1,1) mhs.ApiController
            end
            obj.Router.register(controller);
        end

        function serveStatic(obj, rootDir, options)
            % SERVESTATIC Register a directory for static file serving.
            arguments
                obj     (1,1) MatlabHttpServer
                rootDir (1,1) string
                options.UrlPrefix (1,1) string = "/"
            end
            handler = mhs.StaticFileHandler(rootDir, UrlPrefix=options.UrlPrefix);
            obj.StaticHandlers{end+1} = handler;
        end

        function start(obj)
            % START Start listening for incoming HTTP connections
            arguments
                obj (1,1) MatlabHttpServer
            end

            if obj.IsStarted
                disp("[matlab-http-server] Server already started on port " + obj.Port);
                return;
            end

            if isempty(obj.DataListener) || ~isvalid(obj.DataListener)
                obj.DataListener = addlistener(obj.Transport, 'DataReceived', @obj.onTransportData);
            end

            obj.Transport.start();
            obj.IsStarted = true;
            disp("[matlab-http-server] Server started on port " + obj.Port);
        end

        function stop(obj)
            % STOP Stop the server and release the port
            arguments
                obj (1,1) MatlabHttpServer
            end

            if ~isempty(obj.DataListener)
                if all(isvalid(obj.DataListener))
                    delete(obj.DataListener);
                end
                obj.DataListener = event.listener.empty;
            end

            if ~isempty(obj.Transport) && isvalid(obj.Transport)
                obj.Transport.stop();
            end
            obj.IsStarted = false;
            disp("[matlab-http-server] Server stopped.");
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
        function transport = createTransport(~, mode, port)
            switch lower(mode)
                case 'java'
                    transport = mhs.internal.JavaSocketTransport(port);
                case 'go'
                    transport = mhs.internal.GoSidecarTransport(port);
                otherwise
                    error('MatlabHttpServer:invalidTransport', ...
                        ['Unknown transport: "%s". ' ...
                         'Valid options: "java" (default), "go".'], mode);
            end
        end

        function onTransportData(obj, ~, evt)
            % ONTRANSPORTDATA Listener for Transport DataReceived event
            obj.processRequest(evt.Socket, evt.RawBytes);
        end

        function processRequest(obj, socket, rawBytes)
            % PROCESSREQUEST Parse request, handle OPTIONS, and dispatch
            try
                req = mhs.internal.HttpParser.parse(rawBytes);
                res = mhs.HttpResponse(obj.AllowedOrigin);

                if strcmpi(req.Method, "OPTIONS")
                    mhs.internal.CorsHandler.handlePreflight(res);
                else
                    % Check static handlers before API router
                    handled = false;
                    for i = 1:numel(obj.StaticHandlers)
                        if obj.StaticHandlers{i}.handle(req, res)
                            handled = true;
                            break;
                        end
                    end

                    if ~handled
                        % Fall through to API router
                        obj.Router.dispatch(req, res);
                    end
                end
                
                % Write the response back via transport
                obj.Transport.writeResponse(socket, res.getResponseBytes());
                
            catch ME
                disp("[matlab-http-server ERROR] Request processing error: " + ME.message);

                % Attempt to send 400 Bad Request
                try
                    res = mhs.HttpResponse(obj.AllowedOrigin);
                    res.status(400).send("Bad Request");
                    obj.Transport.writeResponse(socket, res.getResponseBytes());
                catch
                    % Ignore further errors
                end
            end
        end
    end
end
