classdef TestApiTestCase < matlab.unittest.TestCase & mhs.ApiTestCase
    % TestApiTestCase Unit tests for the ApiTestCase helper base class

    methods (Test)
        function testGetReturns200(testCase)
            res = testCase.GET(ApiTestCaseController(), "/test/hello");
            testCase.verifyOk(res);
        end

        function testGetJsonBody(testCase)
            res = testCase.GET(ApiTestCaseController(), "/test/hello");
            body = testCase.decodeJson(res);

            testCase.verifyEqual(string(body.message), "hello");
        end

        function testPostEchosBody(testCase)
            res = testCase.POST(ApiTestCaseController(), "/test/echo", ...
                struct("name", "Alice"));
            body = testCase.decodeJson(res);

            testCase.verifyEqual(string(body.name), "Alice");
        end

        function testPostAllowsOmittedBody(testCase)
            res = testCase.POST(ApiTestCaseController(), "/test/echo");

            testCase.verifyOk(res);
        end

        function testPutEchosBody(testCase)
            res = testCase.PUT(ApiTestCaseController(), "/test/echo", ...
                struct("name", "Bob"));
            body = testCase.decodeJson(res);

            testCase.verifyEqual(string(body.name), "Bob");
        end

        function testPutAllowsOmittedBody(testCase)
            res = testCase.PUT(ApiTestCaseController(), "/test/echo");

            testCase.verifyOk(res);
        end

        function testPatchEchosBody(testCase)
            res = testCase.PATCH(ApiTestCaseController(), "/test/echo", ...
                struct("name", "Carol"));
            body = testCase.decodeJson(res);

            testCase.verifyEqual(string(body.name), "Carol");
        end

        function testPatchAllowsOmittedBody(testCase)
            res = testCase.PATCH(ApiTestCaseController(), "/test/echo");

            testCase.verifyOk(res);
        end

        function testDeleteReturnsPayload(testCase)
            res = testCase.DELETE(ApiTestCaseController(), "/test/resource");
            body = testCase.decodeJson(res);

            testCase.verifyOk(res);
            testCase.verifyTrue(body.deleted);
        end

        function testNotFoundReturns404(testCase)
            res = testCase.GET(ApiTestCaseController(), "/test/unknown");
            testCase.verifyNotFound(res);
        end

        function testVerifyStatus(testCase)
            res = testCase.GET(ApiTestCaseController(), "/test/hello");
            testCase.verifyStatus(res, 200);
        end

        function testVerifyBodyContains(testCase)
            res = testCase.GET(ApiTestCaseController(), "/test/hello");
            testCase.verifyBodyContains(res, "hello");
        end

        function testVerifyContentTypeJson(testCase)
            res = testCase.GET(ApiTestCaseController(), "/test/hello");
            testCase.verifyContentType(res, "application/json");
        end

        function testVerifyCreated(testCase)
            res = testCase.GET(ApiTestCaseController(), "/test/created");
            testCase.verifyCreated(res);
        end

        function testVerifyBadRequest(testCase)
            res = testCase.GET(ApiTestCaseController(), "/test/bad-request");
            testCase.verifyBadRequest(res);
        end

        function testVerifyHeader(testCase)
            headers = dictionary("X-Test-Header", "abc123");
            res = testCase.GET(ApiTestCaseController(), "/test/header", ...
                Headers=headers);

            testCase.verifyHeader(res, "X-Test-Header", "abc123");
        end

        function testStructHeadersAreAccepted(testCase)
            res = testCase.GET(ApiTestCaseController(), "/test/struct-header", ...
                Headers=struct("X_Test_Header", "struct-value"));

            testCase.verifyHeader(res, "X_Test_Header", "struct-value");
        end

        function testQueryParamsAvailable(testCase)
            res = testCase.GET(ApiTestCaseController(), "/test/query?key=val");
            body = testCase.decodeJson(res);

            testCase.verifyEqual(string(body.key), "val");
        end

        function testPathParamsExtracted(testCase)
            res = testCase.GET(ApiTestCaseController(), "/test/users/42");
            body = testCase.decodeJson(res);

            testCase.verifyEqual(string(body.id), "42");
        end

        function testPostTextSetsPlainTextContentType(testCase)
            res = testCase.POST(ApiTestCaseController(), "/test/text", "hello");

            testCase.verifyContentType(res, "text/plain");
            testCase.verifyBodyContains(res, "hello");
        end

        function testDecodeJsonErrorsForPlainText(testCase)
            res = testCase.GET(ApiTestCaseController(), "/test/plain");

            testCase.verifyError(@() testCase.decodeJson(res), ...
                "ApiTestCase:InvalidJsonResponse");
        end
    end
end