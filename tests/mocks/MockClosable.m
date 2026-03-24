classdef MockClosable < handle
    properties
        ThrowOnClose (1,1) logical = false
        Closed (1,1) logical = false
    end

    methods
        function obj = MockClosable(varargin)
            if nargin > 0
                obj.ThrowOnClose = varargin{1};
            end
        end

        function close(obj)
            if obj.ThrowOnClose
                error("MockClosable:CloseFailed", "close failed");
            end
            obj.Closed = true;
        end
    end
end
