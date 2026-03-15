classdef HttpParser
    % HttpParser Parses raw uint8 HTTP request data into mhs.HttpRequest
    %   This is a private implementation detail of the framework.

    methods (Static)
        function req = parse(rawBytes)
            % PARSE Parses a complete raw HTTP request byte array
            arguments
                rawBytes (:,1) uint8
            end

            % Locate double CRLF separating headers from body
            crlfcrlf = uint8([13 10 13 10]);
            idx = strfind(rawBytes', crlfcrlf);

            if isempty(idx)
                error("HttpParser:IncompleteRequest", "Headers not complete or missing double CRLF");
            end

            headerEndIdx = idx(1);
            headerBytes = rawBytes(1:headerEndIdx-1);
            bodyBytes = rawBytes(headerEndIdx+4:end);

            headerStr = string(native2unicode(headerBytes', 'utf-8'));
            lines = split(headerStr, string(char([13 10])));

            % Parse Request-Line
            requestLine = split(lines(1), " ");
            if numel(requestLine) < 2
                error("HttpParser:InvalidRequestLine", "Malformed request line");
            end

            method = requestLine(1);
            fullPath = requestLine(2);

            % Parse Query Parameters
            path = fullPath;
            queryParams = containers.Map('KeyType', 'char', 'ValueType', 'char');
            if contains(fullPath, "?")
                parts = split(fullPath, "?");
                path = parts(1);
                queryString = parts(2);

                pairs = split(queryString, "&");
                for i = 1:numel(pairs)
                    pair = split(pairs(i), "=");
                    if numel(pair) == 2
                        key = char(urldecode(pair(1)));
                        val = char(urldecode(pair(2)));
                        queryParams(key) = val;
                    elseif numel(pair) == 1
                        key = char(urldecode(pair(1)));
                        queryParams(key) = '';
                    end
                end
            end

            % Parse Headers
            headers = containers.Map('KeyType', 'char', 'ValueType', 'char');
            for i = 2:numel(lines)
                line = lines(i);
                if isempty(line)
                    continue;
                end

                colonIdx = strfind(char(line), ':');
                if ~isempty(colonIdx)
                    key = char(strip(extractBefore(line, colonIdx(1))));
                    val = char(strip(extractAfter(line, colonIdx(1))));
                    headers(key) = val;
                end
            end

            % Parse Body based on Content-Type
            body = bodyBytes;
            if ~isempty(bodyBytes) && isKey(headers, 'Content-Type') && contains(string(headers('Content-Type')), "application/json")
                try
                    bodyStr = string(native2unicode(bodyBytes', 'utf-8'));
                    body = jsondecode(bodyStr);
                catch
                    % Leave as raw bytes if parsing fails
                end
            elseif ~isempty(bodyBytes) && isKey(headers, 'Content-Type') && contains(string(headers('Content-Type')), "text/")
                body = string(native2unicode(bodyBytes', 'utf-8'));
            end

            % Empty PathParams initially, populated by Router
            pathParams = containers.Map('KeyType', 'char', 'ValueType', 'char');

            req = mhs.HttpRequest(method, path, headers, body, queryParams, pathParams);
        end
    end
end

function decoded = urldecode(str)
    % Helper function for URL decoding
    str = replace(str, "+", " ");

    % MATLAB does not have a built-in unescape, this handles simple %xx decoding
    hexVals = regexp(str, '%([0-9a-fA-F]{2})', 'tokens');
    for i = 1:numel(hexVals)
        token = hexVals{i}{1};
        charVal = char(hex2dec(token));
        str = replace(str, "%" + token, string(charVal));
    end
    decoded = str;
end