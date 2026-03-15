classdef TestHttpRequest < matlab.unittest.TestCase
    % TestHttpRequest Unit tests for HttpRequest class

    methods (Test)
        function testConstructor(testCase)
            headers = dictionary();
            headers("Content-Type") = "application/json";

            queryParams = dictionary();
            queryParams("id") = "123";

            pathParams = dictionary();
            pathParams("user") = "austin";

            body = struct('name', 'test');

            req = mhs.HttpRequest("POST", "/api", headers, body, queryParams, pathParams);

            testCase.verifyEqual(req.Method, "POST");
            testCase.verifyEqual(req.Path, "/api");
            testCase.verifyEqual(req.Headers("Content-Type"), "application/json");
            testCase.verifyEqual(req.Body.name, 'test');
            testCase.verifyEqual(req.QueryParams("id"), "123");
            testCase.verifyEqual(req.PathParams("user"), "austin");
        end
    end
end