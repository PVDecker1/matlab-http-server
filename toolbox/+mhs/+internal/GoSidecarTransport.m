classdef GoSidecarTransport < mhs.internal.TcpTransport
% GoSidecarTransport HTTP transport using a pre-compiled Go binary.
%   Works with base MATLAB — no toolboxes required.
%   Go binary handles all HTTP; MATLAB handles request processing.
%   Communication over stdin/stdout using line-delimited JSON.
%   Preferred for headless, server, and production deployments.
%
%   The binary must exist at toolbox/bin/<platform>/matlab-http-bridge[.exe].
%   Build from source: cd sidecar && make build-all

    properties (SetAccess = protected)
        Port
    end

    properties (Access = {?matlab.unittest.TestCase})
        Process      % java.lang.Process — the Go binary subprocess
        BinaryPath (1,1) string
    end

    properties (Access = private)
        Writer       % java.io.PrintWriter — writes to Go stdin
        Reader       % java.io.BufferedReader — reads from Go stdout
        Timer        % timer — polls Go stdout
        IsRunning (1,1) logical = false
    end

    methods
        function obj = GoSidecarTransport(port)
            arguments
                port (1,1) double = 8080
            end
            obj.Port = port;
            obj.BinaryPath = mhs.internal.GoSidecarTransport.findBinary();
        end

        function start(obj)
            if obj.IsRunning
                disp("[matlab-http-server] GoSidecarTransport already running.");
                return;
            end

            pb = java.lang.ProcessBuilder({char(obj.BinaryPath), ...
                '--port', char(string(obj.Port))});
            pb.redirectErrorStream(true);
            obj.Process = pb.start();

            obj.Writer = java.io.PrintWriter(...
                java.io.OutputStreamWriter(obj.Process.getOutputStream()), true);

            obj.Reader = java.io.BufferedReader(...
                java.io.InputStreamReader(obj.Process.getInputStream()));

            % Use a timer instead of backgroundPool to avoid 
            % non-serializable Java object issues.
            obj.Timer = timer(...
                'ExecutionMode', 'fixedRate', ...
                'Period', 0.05, ...
                'TimerFcn', @(~,~) obj.pollStdout(), ...
                'Name', 'GoSidecarStdoutPoller');
            
            obj.IsRunning = true;
            start(obj.Timer);
            disp("[matlab-http-server] GoSidecarTransport started on port " + obj.Port);
        end

        function stop(obj)
            obj.IsRunning = false;
            if ~isempty(obj.Timer)
                try
                    stop(obj.Timer);
                catch
                end
                delete(obj.Timer);
                obj.Timer = [];
            end
            if ~isempty(obj.Writer)
                try
                    obj.Writer.close();
                catch
                end
            end
            if ~isempty(obj.Reader)
                try
                    obj.Reader.close();
                catch
                end
            end
            if ~isempty(obj.Process)
                try
                    obj.Process.destroy();
                    obj.Process.waitFor();
                catch
                end
                obj.Process = [];
            end
            obj.Writer = [];
            obj.Reader = [];
            disp("[matlab-http-server] GoSidecarTransport stopped.");
        end

        function delete(obj)
            obj.stop();
        end

        function writeResponse(obj, socket, responseBytes)
            % socket is struct(id, transport) — id is the request UUID from Go
            [status, headers, body] = mhs.internal.GoSidecarTransport ...
                .parseResponseBytes(responseBytes);

            resp.id      = char(socket.id);
            resp.status  = status;
            
            % Convert dictionary to struct for jsonencode if needed
            if isa(headers, 'dictionary')
                hStruct = struct();
                keys = headers.keys();
                for i = 1:numel(keys)
                    field = matlab.lang.makeValidName(char(keys(i)));
                    hStruct.(field) = char(headers(keys(i)));
                end
                resp.headers = hStruct;
            else
                resp.headers = headers;
            end
            
            resp.body    = char(matlab.net.base64encode(body));

            obj.Writer.println(jsonencode(resp));
        end
    end

    methods (Access = private)
        function pollStdout(obj)
            if ~obj.IsRunning || isempty(obj.Reader)
                return;
            end
            try
                % Non-blocking check
                while obj.Reader.ready()
                    line = obj.Reader.readLine();
                    if isempty(line)
                        break;
                    end
                    obj.onLineFromGo(char(line));
                end
            catch
                % Process likely closed
            end
        end

        function onLineFromGo(obj, line)
            line = strip(line);
            if isempty(line) || ~startsWith(line, '{')
                return;
            end
            try
                req = jsondecode(line);

                rawBytes = mhs.internal.GoSidecarTransport ...
                    .buildRawRequest(req);

                socketSub = struct('id', req.id, 'transport', obj);

                evt = mhs.internal.TransportEventData(...
                    string(req.id), rawBytes, socketSub);
                notify(obj, 'DataReceived', evt);

            catch ME
                disp("[matlab-http-server ERROR] GoSidecar parse error: " ...
                    + ME.message);
            end
        end
    end

    methods (Static)

        function path = findBinary()
            % Locate the pre-compiled binary based on current platform.
            toolboxRoot = fileparts(fileparts(fileparts( ...
                mfilename('fullpath'))));
            if ispc
                path = fullfile(toolboxRoot, 'bin', 'win64', ...
                    'matlab-http-bridge.exe');
            elseif ismac
                if strcmp(computer('arch'), 'maca64')
                    path = fullfile(toolboxRoot, 'bin', 'maca64', ...
                        'matlab-http-bridge');
                else
                    path = fullfile(toolboxRoot, 'bin', 'maci64', ...
                        'matlab-http-bridge');
                end
            else
                path = fullfile(toolboxRoot, 'bin', 'glnxa64', ...
                    'matlab-http-bridge');
            end

            if ~isfile(path)
                error('MatlabHttpServer:binaryNotFound', ...
                    ['Go sidecar binary not found: %s\n' ...
                     'Build with: cd sidecar && make build-all'], path);
            end
        end

        function raw = buildRawRequest(req)
            % Reconstruct a raw HTTP/1.1 request byte array from the
            % parsed JSON struct Go sent. This lets HttpParser handle it
            % without modification.
            CRLF = char([13 10]);

            if ~isempty(req.query)
                target = string(req.path) + "?" + string(req.query);
            else
                target = string(req.path);
            end

            lines = string(req.method) + " " + target + ...
                " HTTP/1.1" + CRLF;

            if isstruct(req.headers)
                fields = fieldnames(req.headers);
                for i = 1:numel(fields)
                    % Convert underscores back to hyphens for HTTP headers
                    key = strrep(fields{i}, '_', '-');
                    lines = lines + key + ": " + ...
                        string(req.headers.(fields{i})) + CRLF;
                end
            end

            if ~isempty(req.body)
                bodyBytes = uint8(char(req.body));
            else
                bodyBytes = uint8([]);
            end

            lines = lines + "Content-Length: " + ...
                numel(bodyBytes) + CRLF + CRLF;

            raw = [unicode2native(char(lines), 'utf-8'), bodyBytes]';
        end

        function [status, headers, bodyBytes] = parseResponseBytes(raw)
            % Parse raw HTTP response bytes into components for JSON
            % serialization back to Go.
            crlfcrlf = uint8([13 10 13 10]);
            idx = strfind(raw(:)', crlfcrlf);
            if isempty(idx)
                % Fallback to LF LF
                lflf = uint8([10 10]);
                idx = strfind(raw(:)', lflf);
                if isempty(idx)
                    status = 500;
                    headers = dictionary();
                    bodyBytes = uint8([]);
                    return;
                end
                headerEndLen = 2;
            else
                headerEndLen = 4;
            end

            headerPart = char(raw(1:idx(1)-1));
            if size(headerPart, 1) > 1, headerPart = headerPart'; end
            bodyBytes  = raw(idx(1)+headerEndLen:end);

            % Split by any common newline
            lines = string(regexp(headerPart, '\r\n|\n|\r', 'split'));

            % Status line: HTTP/1.1 200 OK
            statusLine = lines(1);
            parts = split(statusLine, ' ');
            if numel(parts) >= 2
                status = str2double(parts(2));
            else
                status = 500;
            end

            % Headers
            headers = dictionary(string.empty, string.empty);
            for i = 2:numel(lines)
                line = strip(lines(i));
                if strlength(line) == 0, continue; end
                colonIdx = strfind(char(line), ':');
                if ~isempty(colonIdx)
                    key = strip(extractBefore(line, colonIdx(1)));
                    val = strip(extractAfter(line, colonIdx(1)));
                    headers(key) = val;
                end
            end
        end

    end
end
