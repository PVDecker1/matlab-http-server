classdef MockSocket < handle
    properties
        OutputStream
        InputStream
        ThrowOnGetOutputStream (1,1) logical = false
        ThrowOnGetInputStream (1,1) logical = false
        Closed (1,1) logical = false
    end

    methods
        function obj = MockSocket(varargin)
            if nargin >= 1
                obj.OutputStream = varargin{1};
            end
            if nargin >= 2
                obj.InputStream = varargin{2};
            end
        end

        function stream = getOutputStream(obj)
            if obj.ThrowOnGetOutputStream
                error("MockSocket:GetOutputFailed", "getOutputStream failed");
            end
            stream = obj.OutputStream;
        end

        function stream = getInputStream(obj)
            if obj.ThrowOnGetInputStream
                error("MockSocket:GetInputFailed", "getInputStream failed");
            end
            stream = obj.InputStream;
        end

        function close(obj)
            obj.Closed = true;
        end
    end
end
