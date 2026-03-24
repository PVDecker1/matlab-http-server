classdef HttpResponse < handle
    % HttpResponse Builder-style class for generating an HTTP response
    %   A handle class that provides methods to set the response status,
    %   send plain text, send JSON, and send custom headers, before writing
    %   the response back to the client socket.

    properties (Access = private)
        StatusCode (1,1) double = 200
        Headers
        Body (:,1) uint8 = uint8([])
        ResponseBytes (:,1) uint8 = uint8([])
        Sent (1,1) logical = false
    end

    properties
        AllowedOrigin (1,1) string = "*"
    end

    methods
        function obj = HttpResponse(allowedOrigin)
            % HTTPRESPONSE Construct an HttpResponse
            arguments
                allowedOrigin (1,1) string = "*"
            end

            obj.AllowedOrigin = allowedOrigin;

            % Set default headers
            obj.Headers = dictionary(string.empty, string.empty);
            obj.Headers("Content-Type") = "text/plain";
            obj.Headers("Connection") = "close";
        end

        function obj = status(obj, code)
            % STATUS Set the HTTP status code
            arguments
                obj (1,1) mhs.HttpResponse
                code (1,1) double
            end

            obj.StatusCode = code;
        end

        function obj = header(obj, name, value)
            % HEADER Set an HTTP header
            arguments
                obj (1,1) mhs.HttpResponse
                name (1,1) string
                value (1,1) string
            end

            obj.Headers(name) = value;
        end

        function obj = send(obj, text)
            % SEND Send a plain text response
            arguments
                obj (1,1) mhs.HttpResponse
                text (1,1) string
            end

            if obj.Sent
                return;
            end

            obj.Body = unicode2native(char(text), 'utf-8')';
            obj.write();
        end

        function obj = sendBytes(obj, bytes)
            % SENDBYTES Send raw binary bytes as the HTTP response body.
            %   Use for images, fonts, and other binary assets where UTF-8
            %   encoding must not be applied. For text responses use send() instead.
            arguments
                obj   (1,1) mhs.HttpResponse
                bytes (:,1) uint8
            end

            if obj.Sent
                return;
            end

            obj.Body = bytes;
            obj.write();
        end

        function obj = json(obj, data)
            % JSON Send a JSON response
            arguments
                obj (1,1) mhs.HttpResponse
                data
            end

            if obj.Sent
                return;
            end

            obj.header("Content-Type", "application/json");
            jsonStr = string(jsonencode(data));
            obj.Body = unicode2native(char(jsonStr), 'utf-8')';
            obj.write();
        end

        function write(obj)
            % WRITE Write the formulated HTTP response back to the socket
            arguments
                obj (1,1) mhs.HttpResponse
            end

            if obj.Sent
                return;
            end

            % Add essential headers before sending
            obj.header("Content-Length", string(numel(obj.Body)));

            % Add CORS headers
            corsHeaders = mhs.internal.CorsHandler.getCorsHeaders(obj.AllowedOrigin);
            headerKeys = corsHeaders.keys();
            for i = 1:numel(headerKeys)
                obj.header(headerKeys(i), corsHeaders(headerKeys(i)));
            end

            % Build response bytes
            phrase = mhs.HttpStatus.getPhrase(obj.StatusCode);
            statusLine = "HTTP/1.1 " + string(obj.StatusCode) + " " + phrase + char(13) + char(10);

            headerLines = "";
            hKeys = obj.Headers.keys();
            for i = 1:numel(hKeys)
                key = hKeys(i);
                val = obj.Headers(key);
                headerLines = headerLines + key + ": " + val + char(13) + char(10);
            end

            responseStr = statusLine + headerLines + char(13) + char(10);
            obj.ResponseBytes = [unicode2native(char(responseStr), 'utf-8'), obj.Body']';

            obj.Sent = true;
        end

        function bytes = getResponseBytes(obj)
            % GETRESPONSEBYTES Get the full raw HTTP response as a uint8 array.
            %   Returns the status line, headers, and body.
            arguments
                obj (1,1) mhs.HttpResponse
            end
            if ~obj.Sent
                obj.write();
            end
            bytes = obj.ResponseBytes;
        end

        function sent = isSent(obj)
            % ISSENT Check if the response has already been sent
            arguments
                obj (1,1) mhs.HttpResponse
            end
            sent = obj.Sent;
        end

        function [code, hdrs, body] = getRawResponseForTesting(obj)
            % GETRAWRESPONSEFORTESTING Get internal response state for unit testing
            arguments
                obj (1,1) mhs.HttpResponse
            end
            code = obj.StatusCode;
            hdrs = obj.Headers;
            body = obj.Body;
        end
    end
end