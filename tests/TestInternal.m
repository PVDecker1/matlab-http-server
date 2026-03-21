classdef TestInternal < matlab.unittest.TestCase
    methods (Test)
        function testBufferAccumulator(testCase)
            ba = mhs.internal.BufferAccumulator();
            
            % Partial header
            ba.add(uint8(['GET / HTTP/1.1' char(13)]));
            testCase.verifyFalse(ba.isComplete());
            
            % Complete header, no body
            ba.add(uint8([char(10) char(13) char(10)]));
            testCase.verifyTrue(ba.isComplete());
            
            % Reset
            ba.reset();
            testCase.verifyFalse(ba.isComplete());
            
            % Content-Length
            req = ['POST / HTTP/1.1' char(13) char(10) ...
                   'Content-Length: 5' char(13) char(10) ...
                   char(13) char(10)];
            ba.add(uint8(req));
            testCase.verifyFalse(ba.isComplete());
            
            ba.add(uint8('hello'));
            testCase.verifyTrue(ba.isComplete());
            testCase.verifyEqual(numel(ba.getBuffer()), numel(req) + 5);
        end

        function testCorsHandler(testCase)
            res = mhs.HttpResponse();
            mhs.internal.CorsHandler.handlePreflight(res);
            [code, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 200);
            testCase.verifyEqual(hdrs("Content-Length"), "0");
        end

        function testHttpParser(testCase)
            % Query params and URL decoding
            raw = "GET /api/test?name=john%20doe&age=30 HTTP/1.1" + char(13) + char(10) + ...
                  "Content-Type: text/plain" + char(13) + char(10) + ...
                  char(13) + char(10) + ...
                  "some body text";
            req = mhs.internal.HttpParser.parse(uint8(char(raw))');
            
            testCase.verifyEqual(req.QueryParams("name"), "john doe");
            testCase.verifyEqual(req.QueryParams("age"), "30");
            testCase.verifyEqual(req.Body, "some body text");
            
            % Invalid request line
            badRaw = "BADREQUEST" + char(13) + char(10) + char(13) + char(10);
            testCase.verifyError(@() mhs.internal.HttpParser.parse(uint8(char(badRaw))'), 'HttpParser:InvalidRequestLine');
            
            % Empty body with content-type
            emptyRaw = "POST / HTTP/1.1" + char(13) + char(10) + ...
                       "Content-Type: application/json" + char(13) + char(10) + ...
                       char(13) + char(10);
            req2 = mhs.internal.HttpParser.parse(uint8(char(emptyRaw))');
            testCase.verifyEmpty(req2.Body);
        end
    end
end
