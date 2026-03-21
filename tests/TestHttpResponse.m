classdef TestHttpResponse < matlab.unittest.TestCase
    % TestHttpResponse Unit tests for HttpResponse class

    methods (Test)
        function testDefaultStatusCode(testCase)
            res = mhs.HttpResponse();
            [code, ~, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 200);
        end

        function testStatusChaining(testCase)
            res = mhs.HttpResponse();
            res.status(404);
            [code, ~, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 404);
        end

        function testHeaderSetter(testCase)
            res = mhs.HttpResponse();
            res.header("X-Custom", "value");
            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(hdrs("X-Custom"), "value");
        end

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

        function testSendSetsBody(testCase)
            res = mhs.HttpResponse();
            res.send("hello");
            [~, ~, body] = res.getRawResponseForTesting();
            testCase.verifyEqual(char(body'), 'hello');
            testCase.verifyTrue(res.isSent());
        end

        function testJsonSetsContentType(testCase)
            res = mhs.HttpResponse();
            res.json(struct('x', 1));
            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(hdrs("Content-Type"), "application/json");
        end

        function testJsonBodyContent(testCase)
            res = mhs.HttpResponse();
            res.json(struct('name', "Austin"));
            [~, ~, body] = res.getRawResponseForTesting();
            decoded = jsondecode(char(body'));
            testCase.verifyEqual(string(decoded.name), "Austin");
        end

        function testWriteIdempotent(testCase)
            res = mhs.HttpResponse();
            res.send("first");
            res.send("second");
            [~, ~, body] = res.getRawResponseForTesting();
            testCase.verifyEqual(char(body'), 'first');
        end

        function testIsSentFalseBeforeSend(testCase)
            res = mhs.HttpResponse();
            testCase.verifyFalse(res.isSent());
        end

        function testIsSentTrueAfterSend(testCase)
            res = mhs.HttpResponse();
            res.send("x");
            testCase.verifyTrue(res.isSent());
        end

        function testStatusJsonChaining(testCase)
            res = mhs.HttpResponse();
            res.status(201).json(struct('ok', true));
            [code, ~, body] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 201);
            decoded = jsondecode(char(body'));
            testCase.verifyTrue(decoded.ok);
        end

        function testCorsHeadersInjected(testCase)
            res = mhs.HttpResponse();
            res.send("");
            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyTrue(isKey(hdrs, "Access-Control-Allow-Origin"));
            testCase.verifyEqual(hdrs("Access-Control-Allow-Origin"), "*");
        end

        function testCustomAllowedOrigin(testCase)
            res = mhs.HttpResponse([], "http://localhost:3000");
            res.send("");
            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(hdrs("Access-Control-Allow-Origin"), "http://localhost:3000");
        end

        function testContentLengthSet(testCase)
            res = mhs.HttpResponse();
            res.send("hello");
            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(hdrs("Content-Length"), "5");
        end

        function testConnectionCloseHeader(testCase)
            res = mhs.HttpResponse();
            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(hdrs("Connection"), "close");
        end

        function testSendBytesBody(testCase)
            res = mhs.HttpResponse();
            bytes = uint8([1 2 3 4 5])';
            res.sendBytes(bytes);
            [~, ~, body] = res.getRawResponseForTesting();
            testCase.verifyEqual(body, bytes);
            testCase.verifyTrue(res.isSent());
        end

        function testSendBytesIdempotent(testCase)
            res = mhs.HttpResponse();
            bytes1 = uint8([1 2 3])';
            bytes2 = uint8([4 5 6])';
            res.sendBytes(bytes1);
            res.sendBytes(bytes2);
            [~, ~, body] = res.getRawResponseForTesting();
            testCase.verifyEqual(body, bytes1);
        end
    end
end
