classdef MockServerSocket < handle
    properties
        ThrowMessage string = ""
        ThrowId string = "MockServerSocket:AcceptFailed"
        Closed (1,1) logical = false
        ThrowOnClose (1,1) logical = false
    end

    methods
        function obj = MockServerSocket(throwMessage)
            if nargin >= 1
                obj.ThrowMessage = string(throwMessage);
            end
        end

        function socket = accept(obj)
            if strlength(obj.ThrowMessage) > 0
                error(char(obj.ThrowId), "%s", obj.ThrowMessage);
            end
            socket = [];
        end

        function close(obj)
            if obj.ThrowOnClose
                error("MockServerSocket:CloseFailed", "close failed");
            end
            obj.Closed = true;
        end

        function setSoTimeout(~, ~)
        end
    end
end
