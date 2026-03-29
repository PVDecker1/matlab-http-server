classdef ApiTestCase < handle
    % ApiTestCase Mixin helper for mhs.ApiController unit tests
    %   Provides HTTP dispatch helpers and response assertion methods for
    %   controller-focused tests. Use alongside matlab.unittest.TestCase:
    %
    %     classdef TestMyController < matlab.unittest.TestCase & mhs.ApiTestCase
    %
    %   Each dispatch uses a fresh Router and a socketless HttpResponse
    %   instance.

    properties (Access = protected)
        TestAllowedOrigin (1,1) string = "*"
    end

    methods
        function res = GET(tc, controller, path, options)
            % GET Dispatch a GET request to a controller.
            arguments
                tc
                controller (1,1) mhs.ApiController
                path (1,1) string
                options.Headers = struct()
            end

            req = tc.buildRequest("GET", path, options.Headers, []);
            res = tc.dispatch(controller, req);
        end

        function res = POST(tc, controller, path, body, options)
            % POST Dispatch a POST request to a controller.
            arguments
                tc
                controller (1,1) mhs.ApiController
                path (1,1) string
                body = []
                options.Headers = struct()
            end

            req = tc.buildRequest("POST", path, options.Headers, body);
            res = tc.dispatch(controller, req);
        end

        function res = PUT(tc, controller, path, body, options)
            % PUT Dispatch a PUT request to a controller.
            arguments
                tc
                controller (1,1) mhs.ApiController
                path (1,1) string
                body = []
                options.Headers = struct()
            end

            req = tc.buildRequest("PUT", path, options.Headers, body);
            res = tc.dispatch(controller, req);
        end

        function res = DELETE(tc, controller, path, options)
            % DELETE Dispatch a DELETE request to a controller.
            arguments
                tc
                controller (1,1) mhs.ApiController
                path (1,1) string
                options.Headers = struct()
            end

            req = tc.buildRequest("DELETE", path, options.Headers, []);
            res = tc.dispatch(controller, req);
        end

        function res = PATCH(tc, controller, path, body, options)
            % PATCH Dispatch a PATCH request to a controller.
            arguments
                tc
                controller (1,1) mhs.ApiController
                path (1,1) string
                body = []
                options.Headers = struct()
            end

            req = tc.buildRequest("PATCH", path, options.Headers, body);
            res = tc.dispatch(controller, req);
        end

        function verifyStatus(tc, res, expectedStatus)
            % VERIFYSTATUS Assert the response has the expected status code.
            arguments
                tc
                res (1,1) mhs.HttpResponse
                expectedStatus (1,1) double
            end

            [actualStatus, ~, ~] = res.getRawResponseForTesting();
            tc.verifyEqual(actualStatus, expectedStatus, ...
                sprintf("Expected status %d but got %d", ...
                expectedStatus, actualStatus));
        end

        function verifyOk(tc, res)
            % VERIFYOK Assert the response status is 200.
            tc.verifyStatus(res, 200);
        end

        function verifyCreated(tc, res)
            % VERIFYCREATED Assert the response status is 201.
            tc.verifyStatus(res, 201);
        end

        function verifyNotFound(tc, res)
            % VERIFYNOTFOUND Assert the response status is 404.
            tc.verifyStatus(res, 404);
        end

        function verifyBadRequest(tc, res)
            % VERIFYBADREQUEST Assert the response status is 400.
            tc.verifyStatus(res, 400);
        end

        function data = decodeJson(~, res)
            % DECODEJSON Decode the response body as JSON.
            arguments
                ~
                res (1,1) mhs.HttpResponse
            end

            [~, ~, bodyBytes] = res.getRawResponseForTesting();
            bodyStr = string(native2unicode(bodyBytes', "utf-8"));
            try
                data = jsondecode(bodyStr);
            catch ME
                error("ApiTestCase:InvalidJsonResponse", ...
                    "Response body is not valid JSON: %s Body: %s", ...
                    ME.message, bodyStr);
            end
        end

        function verifyHeader(tc, res, headerName, expectedValue)
            % VERIFYHEADER Assert a response header has the expected value.
            arguments
                tc
                res (1,1) mhs.HttpResponse
                headerName (1,1) string
                expectedValue (1,1) string
            end

            [~, headers, ~] = res.getRawResponseForTesting();
            tc.verifyTrue(isKey(headers, headerName), ...
                sprintf('Header "%s" not present in response', headerName));
            tc.verifyEqual(string(headers(headerName)), expectedValue);
        end

        function verifyContentType(tc, res, expectedType)
            % VERIFYCONTENTTYPE Assert the Content-Type header matches.
            arguments
                tc
                res (1,1) mhs.HttpResponse
                expectedType (1,1) string
            end

            tc.verifyHeader(res, "Content-Type", expectedType);
        end

        function verifyBodyContains(tc, res, substring)
            % VERIFYBODYCONTAINS Assert the body contains a substring.
            arguments
                tc
                res (1,1) mhs.HttpResponse
                substring (1,1) string
            end

            [~, ~, bodyBytes] = res.getRawResponseForTesting();
            bodyStr = string(native2unicode(bodyBytes', "utf-8"));
            tc.verifyTrue(contains(bodyStr, substring), ...
                sprintf('Body does not contain "%s".\nBody: %s', ...
                substring, bodyStr));
        end
    end

    methods (Access = private)
        function req = buildRequest(~, method, path, headers, body)
            % BUILDREQUEST Construct a test HttpRequest.
            arguments
                ~
                method (1,1) string
                path (1,1) string
                headers = struct()
                body = []
            end

            [cleanPath, queryParams] = parsePathAndQuery(path);
            headerDict = dictionary(string.empty, string.empty);
            if isstruct(headers)
                fields = fieldnames(headers);
                for i = 1:numel(fields)
                    headerDict(string(fields{i})) = string(headers.(fields{i}));
                end
            elseif isa(headers, "dictionary")
                keys = headers.keys();
                for i = 1:numel(keys)
                    key = string(keys(i));
                    headerDict(key) = string(headers(key));
                end
            end

            parsedBody = body;
            if isstruct(body) || (isnumeric(body) && ~isempty(body))
                headerDict("Content-Type") = "application/json";
                parsedBody = jsondecode(jsonencode(body));
            elseif ischar(body) || isstring(body)
                headerDict("Content-Type") = "text/plain";
                parsedBody = string(body);
            end

            req = mhs.HttpRequest(method, cleanPath, headerDict, parsedBody, ...
                queryParams, dictionary(string.empty, string.empty));
        end

        function res = dispatch(tc, controller, req)
            % DISPATCH Register controller in a fresh Router and dispatch.
            arguments
                tc
                controller (1,1) mhs.ApiController
                req (1,1) mhs.HttpRequest
            end

            router = mhs.Router();
            router.register(controller);
            res = mhs.HttpResponse(tc.TestAllowedOrigin);
            router.dispatch(req, res);
        end
    end
end

function [cleanPath, queryParams] = parsePathAndQuery(path)
arguments
    path (1,1) string
end

queryParams = dictionary(string.empty, string.empty);
cleanPath = path;

if ~contains(path, "?")
    return;
end

cleanPath = extractBefore(path, "?");
queryString = extractAfter(path, "?");
if strlength(queryString) == 0
    return;
end

pairs = split(queryString, "&");
for i = 1:numel(pairs)
    pair = pairs(i);
    if contains(pair, "=")
        key = extractBefore(pair, "=");
        value = extractAfter(pair, "=");
    else
        key = pair;
        value = "";
    end

    if strlength(key) == 0
        continue;
    end
    queryParams(key) = value;
end
end
