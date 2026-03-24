classdef MockReader < handle
    properties
        ReadySequence (1,:) logical = false
        Lines (1,:) cell = {}
        ReadyErrorMessage string = ""
        LineIndex (1,1) double = 1
        ReadyIndex (1,1) double = 1
        Closed (1,1) logical = false
    end

    methods
        function obj = MockReader(readySequence, lines, readyErrorMessage)
            if nargin >= 1
                obj.ReadySequence = readySequence;
            end
            if nargin >= 2
                obj.Lines = lines;
            end
            if nargin >= 3
                obj.ReadyErrorMessage = string(readyErrorMessage);
            end
        end

        function tf = ready(obj)
            if strlength(obj.ReadyErrorMessage) > 0
                error("MockReader:ReadyFailed", "%s", obj.ReadyErrorMessage);
            end

            if obj.ReadyIndex <= numel(obj.ReadySequence)
                tf = obj.ReadySequence(obj.ReadyIndex);
                obj.ReadyIndex = obj.ReadyIndex + 1;
            else
                tf = false;
            end
        end

        function line = readLine(obj)
            if obj.LineIndex <= numel(obj.Lines)
                line = obj.Lines{obj.LineIndex};
                obj.LineIndex = obj.LineIndex + 1;
            else
                line = '';
            end
        end

        function close(obj)
            obj.Closed = true;
        end
    end
end
