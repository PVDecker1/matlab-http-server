classdef TestCorsHandler < matlab.unittest.TestCase
    % TestCorsHandler Unit tests for CorsHandler class

    methods (Test)
        function testGetCorsHeadersDefaultOrigin(testCase)
            hdrs = mhs.internal.CorsHandler.getCorsHeaders();
            testCase.verifyEqual(hdrs("Access-Control-Allow-Origin"), "*");
        end

        function testGetCorsHeadersCustomOrigin(testCase)
            hdrs = mhs.internal.CorsHandler.getCorsHeaders("http://localhost:5173");
            testCase.verifyEqual(hdrs("Access-Control-Allow-Origin"), "http://localhost:5173");
        end

        function testGetCorsHeadersHasMethods(testCase)
            hdrs = mhs.internal.CorsHandler.getCorsHeaders();
            methods = hdrs("Access-Control-Allow-Methods");
            testCase.verifyTrue(contains(methods, "GET"));
            testCase.verifyTrue(contains(methods, "POST"));
            testCase.verifyTrue(contains(methods, "DELETE"));
        end

        function testGetCorsHeadersHasAllowHeaders(testCase)
            hdrs = mhs.internal.CorsHandler.getCorsHeaders();
            headers = hdrs("Access-Control-Allow-Headers");
            testCase.verifyTrue(contains(headers, "Content-Type"));
        end

        function testHandlePreflightStatus(testCase)
            res = mhs.HttpResponse();
            mhs.internal.CorsHandler.handlePreflight(res);
            [code, ~, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 200);
            testCase.verifyTrue(res.isSent());
        end

        function testHandlePreflightContentLengthZero(testCase)
            res = mhs.HttpResponse();
            mhs.internal.CorsHandler.handlePreflight(res);
            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(hdrs("Content-Length"), "0");
        end

        function testHandlePreflightIsSent(testCase)
            res = mhs.HttpResponse();
            mhs.internal.CorsHandler.handlePreflight(res);
            testCase.verifyTrue(res.isSent());
        end
    end
end
