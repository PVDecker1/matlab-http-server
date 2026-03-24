classdef (Abstract) TcpTransport < handle
% TcpTransport Abstract base class for HTTP transport implementations.
%   Defines the interface for starting and stopping the underlying
%   network layer. MatlabHttpServer depends only on this interface.
%
%   Concrete implementations:
%     mhs.internal.JavaSocketTransport  — java.net, base MATLAB, desktop
%     mhs.internal.GoSidecarTransport   — Go binary, base MATLAB, server

    events
        DataReceived       % Fired when a complete HTTP request is ready.
                           % EventData: mhs.internal.TransportEventData
    end

    properties (Abstract, SetAccess = protected)
        Port (1,1) double
    end

    methods (Abstract)
        start(obj)   % Start listening for connections
        stop(obj)    % Stop and release resources
        writeResponse(obj, socket, responseBytes)
        % Write raw HTTP response bytes back to the client.
        % socket: the Socket field from TransportEventData
        % responseBytes: complete raw HTTP response as uint8
    end
end
