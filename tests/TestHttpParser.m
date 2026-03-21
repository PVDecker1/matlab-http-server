classdef TestHttpParser < matlab.unittest.TestCase
    % TestHttpParser Unit tests for HttpParser class

    methods (Test)
        function testGetWithQueryString(testCase)
            raw = ['GET /api/users?status=active HTTP/1.1' char(13) char(10) ...
                   'Host: localhost' char(13) char(10) ...
                   char(13) char(10)];
            req = mhs.internal.HttpParser.parse(uint8(raw)');
            testCase.verifyEqual(req.QueryParams("status"), "active");
        end

        function testGetWithMultipleQueryParams(testCase)
            raw = ['GET /api/users?status=active&role=admin HTTP/1.1' char(13) char(10) ...
                   'Host: localhost' char(13) char(10) ...
                   char(13) char(10)];
            req = mhs.internal.HttpParser.parse(uint8(raw)');
            testCase.verifyEqual(req.QueryParams("status"), "active");
            testCase.verifyEqual(req.QueryParams("role"), "admin");
        end

        function testPostWithValidJsonBody(testCase)
            rawBody = '{"name":"Austin","age":30}';
            raw = ['POST /api/users HTTP/1.1' char(13) char(10) ...
                   'Content-Type: application/json' char(13) char(10) ...
                   'Content-Length: ' num2str(numel(rawBody)) char(13) char(10) ...
                   char(13) char(10) ...
                   rawBody];
            req = mhs.internal.HttpParser.parse(uint8(raw)');
            testCase.verifyTrue(isstruct(req.Body));
            testCase.verifyEqual(string(req.Body.name), "Austin");
            testCase.verifyEqual(req.Body.age, 30);
        end

        function testPostWithMalformedJson(testCase)
            rawBody = '{"name":"Austin", "broken": }';
            raw = ['POST /api/users HTTP/1.1' char(13) char(10) ...
                   'Content-Type: application/json' char(13) char(10) ...
                   'Content-Length: ' num2str(numel(rawBody)) char(13) char(10) ...
                   char(13) char(10) ...
                   rawBody];
            testCase.verifyError(@() mhs.internal.HttpParser.parse(uint8(raw)'), 'HttpParser:InvalidJson');
        end

        function testPostWithTextPlainBody(testCase)
            rawBody = 'simple text body';
            raw = ['POST /api/text HTTP/1.1' char(13) char(10) ...
                   'Content-Type: text/plain' char(13) char(10) ...
                   'Content-Length: ' num2str(numel(rawBody)) char(13) char(10) ...
                   char(13) char(10) ...
                   rawBody];
            req = mhs.internal.HttpParser.parse(uint8(raw)');
            testCase.verifyEqual(req.Body, "simple text body");
        end

        function testPostWithNoContentType(testCase)
            rawBody = 'raw binary data';
            raw = ['POST /api/raw HTTP/1.1' char(13) char(10) ...
                   'Content-Length: ' num2str(numel(rawBody)) char(13) char(10) ...
                   char(13) char(10) ...
                   rawBody];
            req = mhs.internal.HttpParser.parse(uint8(raw)');
            testCase.verifyTrue(isa(req.Body, 'uint8'));
            testCase.verifyEqual(char(req.Body'), 'raw binary data');
        end

        function testUrlEncodedQueryParam(testCase)
            % %20 space encoding
            raw = ['GET /api/search?q=hello%20world HTTP/1.1' char(13) char(10) ...
                   char(13) char(10)];
            req = mhs.internal.HttpParser.parse(uint8(raw)');
            testCase.verifyEqual(req.QueryParams("q"), "hello world");
        end

        function testWindowsCmdCurlRobustness(testCase)
            % Body wrapped in single quotes: '{"key":"val"}'
            rawBody = '''{"name":"Austin"}''';
            raw = ['POST /api/users HTTP/1.1' char(13) char(10) ...
                   'Content-Type: application/json' char(13) char(10) ...
                   'Content-Length: ' num2str(numel(rawBody)) char(13) char(10) ...
                   char(13) char(10) ...
                   rawBody];
            req = mhs.internal.HttpParser.parse(uint8(raw)');
            testCase.verifyTrue(isstruct(req.Body));
            testCase.verifyEqual(string(req.Body.name), "Austin");
        end
    end
end
