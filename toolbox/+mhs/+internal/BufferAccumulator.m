classdef BufferAccumulator < handle
    % BufferAccumulator Accumulates partial TCP reads into complete HTTP requests
    %   Detects header and body completion based on HTTP specification.

    properties (Access = private)
        Buffer (:,1) uint8 = uint8([])
        HeaderEndIndex (1,1) double = -1
        ContentLength (1,1) double = -1
    end

    methods
        function obj = BufferAccumulator()
            % BUFFERACCUMULATOR Construct an instance
        end

        function add(obj, bytes)
            % ADD Append raw bytes to the buffer
            arguments
                obj (1,1) mhs.internal.BufferAccumulator
                bytes (:,1) uint8
            end

            obj.Buffer = [obj.Buffer; bytes];

            % Check for header end if not found yet
            if obj.HeaderEndIndex == -1
                obj.findHeaderEnd();
            end

            % Extract Content-Length once headers are received
            if obj.HeaderEndIndex ~= -1 && obj.ContentLength == -1
                obj.extractContentLength();
            end
        end

        function complete = isComplete(obj)
            % ISCOMPLETE Check if the full HTTP request has been received
            arguments
                obj (1,1) mhs.internal.BufferAccumulator
            end

            if obj.HeaderEndIndex == -1
                complete = false;
                return;
            end

            if obj.ContentLength > 0
                % Body size is ContentLength + headers length
                bodyReceived = numel(obj.Buffer) - obj.HeaderEndIndex;
                complete = bodyReceived >= obj.ContentLength;
            else
                % No body
                complete = true;
            end
        end

        function bytes = getBuffer(obj)
            % GETBUFFER Get the accumulated raw bytes
            arguments
                obj (1,1) mhs.internal.BufferAccumulator
            end
            bytes = obj.Buffer;
        end

        function reset(obj)
            % RESET Clear the buffer
            arguments
                obj (1,1) mhs.internal.BufferAccumulator
            end
            obj.Buffer = uint8([]);
            obj.HeaderEndIndex = -1;
            obj.ContentLength = -1;
        end
    end

    methods (Access = private)
        function findHeaderEnd(obj)
            % FINDHEADEREND Look for '\r\n\r\n' marking the end of headers
            arguments
                obj (1,1) mhs.internal.BufferAccumulator
            end

            % Sequence \r\n\r\n is [13 10 13 10]
            seq = uint8([13 10 13 10]);

            for i = 1:(numel(obj.Buffer) - 3)
                if isequal(obj.Buffer(i:i+3), seq')
                    obj.HeaderEndIndex = i + 3;
                    return;
                end
            end
        end

        function extractContentLength(obj)
            % EXTRACTCONTENTLENGTH Parse the Content-Length header
            arguments
                obj (1,1) mhs.internal.BufferAccumulator
            end

            headerBytes = obj.Buffer(1:obj.HeaderEndIndex);
            headerStr = string(native2unicode(headerBytes', 'utf-8'));

            % Find Content-Length case-insensitively
            lines = split(headerStr, string(char([13 10])));

            for i = 1:numel(lines)
                line = lines(i);
                if startsWith(lower(line), "content-length:")
                    valStr = strip(extractAfter(line, ":"));
                    val = str2double(valStr);
                    if ~isnan(val)
                        obj.ContentLength = val;
                        return;
                    end
                end
            end

            % Not found or invalid
            obj.ContentLength = 0;
        end
    end
end