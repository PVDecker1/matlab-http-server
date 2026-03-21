classdef TestHttpRequest < matlab.unittest.TestCase
    % TestHttpRequest Unit tests for HttpRequest class

    methods (Test)
        function testConstructor(testCase)
            req = mhs.HttpRequest("GET", "/test");
            testCase.verifyEqual(req.Method, "GET");
            testCase.verifyEqual(req.Path, "/test");
            testCase.verifyTrue(isa(req.Headers, 'dictionary'));
            testCase.verifyTrue(isa(req.QueryParams, 'dictionary'));
            testCase.verifyTrue(isa(req.PathParams, 'dictionary'));
        end

        function testDefaultConstructor(testCase)
            req = mhs.HttpRequest();
            testCase.verifyEqual(req.Method, "");
            testCase.verifyEqual(req.Path, "");
        end

        function testManualPropertyAssignment(testCase)
            req = mhs.HttpRequest();
            req.Method = "POST";
            req.Path = "/api";
            req.Body = "hello";
            testCase.verifyEqual(req.Method, "POST");
            testCase.verifyEqual(req.Path, "/api");
            testCase.verifyEqual(req.Body, "hello");
        end
    end
end
