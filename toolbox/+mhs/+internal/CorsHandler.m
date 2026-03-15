classdef CorsHandler
    % CorsHandler Generates CORS headers and handles OPTIONS preflight
    %   Static methods to provide consistent CORS headers across the server.

    methods (Static)
        function headers = getCorsHeaders(allowedOrigin)
            % GETCORSHEADERS Return a containers.Map of standard CORS headers
            arguments
                allowedOrigin (1,1) string = "*"
            end

            headers = containers.Map('KeyType', 'char', 'ValueType', 'char');
            headers('Access-Control-Allow-Origin') = char(allowedOrigin);
            headers('Access-Control-Allow-Methods') = 'GET, POST, PUT, DELETE, PATCH, OPTIONS';
            headers('Access-Control-Allow-Headers') = 'Content-Type, Authorization';
        end

        function handlePreflight(res)
            % HANDLEPREFLIGHT Send a 200 OK response for OPTIONS requests
            arguments
                res (1,1) mhs.HttpResponse
            end

            res.status(200);
            res.header("Content-Length", "0");
            res.send("");
        end
    end
end