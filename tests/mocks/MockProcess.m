classdef MockProcess < handle
    properties
        ThrowOnDestroy (1,1) logical = false
        ThrowOnWaitFor (1,1) logical = false
        Destroyed (1,1) logical = false
    end

    methods
        function obj = MockProcess(varargin)
            if nargin >= 1
                obj.ThrowOnDestroy = varargin{1};
            end
            if nargin >= 2
                obj.ThrowOnWaitFor = varargin{2};
            end
        end

        function destroy(obj)
            obj.Destroyed = true;
            if obj.ThrowOnDestroy
                error("MockProcess:DestroyFailed", "destroy failed");
            end
        end

        function waitFor(obj)
            if obj.ThrowOnWaitFor
                error("MockProcess:WaitFailed", "waitFor failed");
            end
        end
    end
end
