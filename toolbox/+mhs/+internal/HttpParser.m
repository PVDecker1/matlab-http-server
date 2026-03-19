classdef HttpParser
    % HttpParser Parses raw uint8 HTTP request data into mhs.HttpRequest
    %   This is an internal implementation detail of the framework.

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
            queryParams = dictionary(string.empty, string.empty);
            if contains(fullPath, "?")
                parts = split(fullPath, "?");
                path = parts(1);
                queryString = parts(2);

                pairs = split(queryString, "&");
                for i = 1:numel(pairs)
                    pair = split(pairs(i), "=");
                    if numel(pair) == 2
                        key = urldecode(pair(1));
                        val = urldecode(pair(2));
                        queryParams(key) = val;
                    elseif numel(pair) == 1
                        key = urldecode(pair(1));
                        queryParams(key) = "";
                    end
                end
            end

            % Parse Headers
            headers = dictionary(string.empty, string.empty);
            for i = 2:numel(lines)
                line = lines(i);
                if isempty(line)
                    continue;
                end

                colonIdx = strfind(char(line), ':');
                if ~isempty(colonIdx)
                    key = strip(extractBefore(line, colonIdx(1)));
                    val = strip(extractAfter(line, colonIdx(1)));
                    headers(key) = val;
                end
            end

            % Parse Body based on Content-Type
            body = bodyBytes;
            if ~isempty(bodyBytes) && isKey(headers, "Content-Type") && contains(headers("Content-Type"), "application/json")
                bodyStr = string(native2unicode(bodyBytes', 'utf-8'));
                
                % Robustness: Strip leading/trailing whitespace and surrounding quotes
                % often injected by shell environments (like curl on Windows CMD)
                bodyStr = strip(bodyStr);
                
                % Handle multiple layers or single/double quote wrapping
                while (strlength(bodyStr) >= 2) && ...
                      ((startsWith(bodyStr, "'") && endsWith(bodyStr, "'")) || ...
                       (startsWith(bodyStr, char(34)) && endsWith(bodyStr, char(34))))
                    bodyStr = extractBetween(bodyStr, 2, strlength(bodyStr)-1);
                    bodyStr = strip(bodyStr);
                end
                
                try
                    body = jsondecode(bodyStr);
                catch ME
                    % Check for a common Windows CMD issue: missing double quotes around keys
                    if contains(ME.message, "expected quoted name")
                        hint = sprintf(' (HINT: If using curl on Windows CMD, ensure double quotes are escaped like "{\\"key\\":\\"val\\"}")');
                        error("HttpParser:InvalidJson", "Failed to parse JSON body: %s%s", ME.message, hint);
                    else
                        error("HttpParser:InvalidJson", "Failed to parse JSON body: %s", ME.message);
                    end
                end
            elseif ~isempty(bodyBytes) && isKey(headers, "Content-Type") && contains(headers("Content-Type"), "text/")
                body = string(native2unicode(bodyBytes', 'utf-8'));
            end

            % Empty PathParams initially, populated by Router
            pathParams = dictionary(string.empty, string.empty);

            req = mhs.HttpRequest(method, path, headers, body, queryParams, pathParams);
        end
    end
end

function decoded = urldecode(str)
    % Helper function for URL decoding
    % TODO: This loop-based replacement is O(n*m) and should be replaced 
    % with a vectorized approach for URLs with many encoded characters.
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
