classdef TestHttpResponse < matlab.unittest.TestCase
    % TestHttpResponse Unit tests for HttpResponse class

    methods (Test)
        function testSendPlainText(testCase)
            res = mhs.HttpResponse(); % No socket needed to test builder
            res.status(201).send("Hello World");

            [code, hdrs, body] = res.getRawResponseForTesting();

            testCase.verifyEqual(code, 201);
            testCase.verifyEqual(hdrs("Content-Type"), "text/plain");
            testCase.verifyEqual(hdrs("Content-Length"), "11");
            testCase.verifyEqual(char(body'), 'Hello World');
            testCase.verifyTrue(res.isSent());
        end

        function testSendJson(testCase)
            res = mhs.HttpResponse();
            data = struct('status', 'ok', 'count', 5);
            res.json(data);

            [code, hdrs, body] = res.getRawResponseForTesting();

            testCase.verifyEqual(code, 200);
            testCase.verifyEqual(hdrs("Content-Type"), "application/json");

            bodyStr = string(char(body'));
            decoded = jsondecode(bodyStr);
            testCase.verifyEqual(decoded.status, 'ok');
            testCase.verifyEqual(decoded.count, 5);
        end

        function testCustomHeaders(testCase)
            res = mhs.HttpResponse();
            res.header("X-Custom", "123").send("test");

            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(hdrs("X-Custom"), "123");
        end
    end
end