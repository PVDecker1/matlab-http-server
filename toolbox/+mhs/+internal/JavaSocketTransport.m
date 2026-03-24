classdef JavaSocketTransport < mhs.internal.TcpTransport
% JavaSocketTransport HTTP transport using java.net.ServerSocket.
%   Works with base MATLAB without relying on Parallel Computing Toolbox.
%   A timer polls the Java server socket for new clients and reads request
%   bytes incrementally until a complete HTTP request is available.

    properties (SetAccess = protected)
        Port
    end

    properties (Access = {?matlab.unittest.TestCase})
        ServerSocket
        Timer
    end

    properties (Access = private)
        IsRunning (1,1) logical = false
        ClientKeys (1,:) string = string.empty(1, 0)
        ClientSockets (1,:) cell = {}
        ClientAccumulators (1,:) cell = {}
    end

    properties (Constant, Access = private)
        AcceptTimeoutMs (1,1) double = 25
        ClientReadTimeoutMs (1,1) double = 25
        PollPeriodSeconds (1,1) double = 0.02
    end

    methods
        function obj = JavaSocketTransport(port)
            arguments
                port (1,1) double = 8080
            end

            obj.Port = port;
        end

        function start(obj)
            if obj.IsRunning
                disp("[matlab-http-server] JavaSocketTransport already running.");
                return;
            end

            try
                obj.ServerSocket = java.net.ServerSocket(int32(obj.Port));
                obj.ServerSocket.setSoTimeout(int32(obj.AcceptTimeoutMs));
            catch ME
                error("JavaSocketTransport:StartFailed", ...
                    "Failed to bind Java server socket on port %d: %s", ...
                    obj.Port, ME.message);
            end

            obj.Timer = timer( ...
                "ExecutionMode", "fixedSpacing", ...
                "Period", obj.PollPeriodSeconds, ...
                "BusyMode", "drop", ...
                "TimerFcn", @(~, ~) obj.pollSockets(), ...
                "ErrorFcn", @(~, evt) obj.onTimerError(evt), ...
                "Name", "JavaSocketTransportPoller");

            obj.IsRunning = true;
            start(obj.Timer);
            disp("[matlab-http-server] JavaSocketTransport started on port " + obj.Port);
        end

        function stop(obj)
            if ~obj.IsRunning
                return;
            end

            obj.IsRunning = false;

            if ~isempty(obj.Timer)
                try
                    stop(obj.Timer);
                catch
                end
                delete(obj.Timer);
                obj.Timer = [];
            end

            obj.closeAllClients();

            if ~isempty(obj.ServerSocket)
                try
                    obj.ServerSocket.close();
                catch
                end
                obj.ServerSocket = [];
            end

            disp("[matlab-http-server] JavaSocketTransport stopped.");
        end

        function delete(obj)
            obj.stop();
        end

        function writeResponse(obj, socket, responseBytes)
            try
                if isempty(socket)
                    return;
                end

                stream = socket.getOutputStream();
                bytes = uint8(responseBytes(:)');
                stream.write(bytes);
                stream.flush();
            catch ME
                disp("[matlab-http-server ERROR] JavaSocketTransport write failed: " + ME.message);
            end

            obj.closeClientSocket(socket);
        end
    end

    methods (Access = private)
        function pollSockets(obj)
            if ~obj.IsRunning || isempty(obj.ServerSocket)
                return;
            end

            obj.acceptPendingClients();
            obj.readPendingClients();
        end

        function acceptPendingClients(obj)
            while obj.IsRunning
                try
                    clientSocket = obj.ServerSocket.accept();
                    clientSocket.setSoTimeout(int32(obj.ClientReadTimeoutMs));
                    obj.registerClient(clientSocket);
                catch ME
                    if obj.isTimeoutError(ME)
                        break;
                    end

                    if obj.IsRunning
                        disp("[matlab-http-server ERROR] JavaSocketTransport accept failed: " + ME.message);
                    end
                    break;
                end
            end
        end

        function readPendingClients(obj)
            idx = 1;
            while idx <= numel(obj.ClientSockets)
                clientSocket = obj.ClientSockets{idx};

                if isempty(clientSocket)
                    obj.removeClientByIndex(idx);
                    continue;
                end

                try
                    stream = clientSocket.getInputStream();
                    bytesRead = obj.readAvailableBytes(stream, obj.ClientAccumulators{idx});
                    if bytesRead < 0
                        obj.closeAndRemoveClient(idx);
                        continue;
                    end

                    if obj.ClientAccumulators{idx}.isComplete()
                        evt = mhs.internal.TransportEventData( ...
                            obj.ClientKeys(idx), ...
                            obj.ClientAccumulators{idx}.getBuffer(), ...
                            clientSocket);
                        notify(obj, "DataReceived", evt);

                        if idx <= numel(obj.ClientSockets) && isequal(obj.ClientSockets{idx}, clientSocket)
                            obj.removeClientByIndex(idx);
                        end
                        continue;
                    end
                catch ME
                    if ~(obj.isTimeoutError(ME) || obj.isWouldBlockError(ME))
                        disp("[matlab-http-server ERROR] JavaSocketTransport read failed: " + ME.message);
                        obj.closeAndRemoveClient(idx);
                        continue;
                    end
                end

                idx = idx + 1;
            end
        end

        function registerClient(obj, clientSocket)
            clientKey = string(clientSocket.getInetAddress().getHostAddress()) + ":" + ...
                string(clientSocket.getPort());

            obj.ClientKeys(end + 1) = clientKey;
            obj.ClientSockets{end + 1} = clientSocket;
            obj.ClientAccumulators{end + 1} = mhs.internal.BufferAccumulator();
        end

        function bytesRead = readAvailableBytes(obj, stream, accumulator)
            bytesRead = 0;

            firstByte = stream.read();
            if firstByte < 0
                bytesRead = firstByte;
                return;
            end

            accumulator.add(uint8(firstByte));
            bytesRead = 1;

            while stream.available() > 0 && ~accumulator.isComplete()
                nextByte = stream.read();
                if nextByte < 0
                    return;
                end

                accumulator.add(uint8(nextByte));
                bytesRead = bytesRead + 1;
            end
        end

        function closeAndRemoveClient(obj, idx)
            clientSocket = obj.ClientSockets{idx};
            obj.closeClientSocket(clientSocket);
        end

        function closeClientSocket(obj, socket)
            if isempty(socket)
                return;
            end

            idx = obj.findClientIndex(socket);

            try
                socket.close();
            catch
            end

            if idx > 0
                obj.removeClientByIndex(idx);
            end
        end

        function idx = findClientIndex(obj, socket)
            idx = 0;
            for i = 1:numel(obj.ClientSockets)
                if isequal(obj.ClientSockets{i}, socket)
                    idx = i;
                    return;
                end
            end
        end

        function removeClientByIndex(obj, idx)
            obj.ClientKeys(idx) = [];
            obj.ClientSockets(idx) = [];
            obj.ClientAccumulators(idx) = [];
        end

        function closeAllClients(obj)
            for i = 1:numel(obj.ClientSockets)
                try
                    obj.ClientSockets{i}.close();
                catch
                end
            end

            obj.ClientKeys = string.empty(1, 0);
            obj.ClientSockets = {};
            obj.ClientAccumulators = {};
        end

        function onTimerError(obj, evt)
            disp("[matlab-http-server ERROR] JavaSocketTransport timer error: " + evt.Data.Message);
            obj.stop();
        end

        function tf = isTimeoutError(~, ME)
            message = string(ME.message);
            tf = contains(message, "timed out", IgnoreCase=true) || ...
                contains(message, "SocketTimeoutException", IgnoreCase=true);
        end

        function tf = isWouldBlockError(~, ME)
            message = string(ME.message);
            tf = contains(message, "would block", IgnoreCase=true) || ...
                contains(message, "resource temporarily unavailable", IgnoreCase=true);
        end
    end
end
