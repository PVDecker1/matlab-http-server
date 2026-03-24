classdef TransportEventData < event.EventData
    properties
        ClientKey (1,1) string  % Unique client identifier (e.g. "127.0.0.1:54321")
        RawBytes  (:,1) uint8   % Complete raw HTTP request bytes
        Socket                  % Transport-specific socket/pipe handle for writing response
    end

    methods
        function obj = TransportEventData(clientKey, rawBytes, socket)
            arguments
                clientKey (1,1) string
                rawBytes  (:,1) uint8
                socket
            end
            obj.ClientKey = clientKey;
            obj.RawBytes  = rawBytes;
            obj.Socket    = socket;
        end
    end
end
