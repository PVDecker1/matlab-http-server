classdef HttpRequest
    % HttpRequest Represents an incoming HTTP request
    %   A value class containing parsed HTTP request information including
    %   the method, path, headers, query parameters, body, and extracted
    %   path parameters.

    properties
        Method (1,1) string = ""
        Path (1,1) string = ""
        Headers
        Body
        QueryParams
        PathParams
    end

    methods
        function obj = HttpRequest(method, path, headers, body, queryParams, pathParams)
            % HTTPREQUEST Construct an instance of HttpRequest
            arguments
                method (1,1) string = ""
                path (1,1) string = ""
                headers = containers.Map('KeyType', 'char', 'ValueType', 'char')
                body = []
                queryParams = containers.Map('KeyType', 'char', 'ValueType', 'char')
                pathParams = containers.Map('KeyType', 'char', 'ValueType', 'char')
            end

            obj.Method = method;
            obj.Path = path;
            obj.Headers = headers;
            obj.Body = body;
            obj.QueryParams = queryParams;
            obj.PathParams = pathParams;
        end
    end
end