classdef TestJsonParsing < matlab.unittest.TestCase
    methods (Test)
        function testJsonWithQuotesRobustness(testCase)
            % This simulates the literal single quotes being sent in the body
            % as often happens with curl on Windows CMD.
            raw = "POST /echo HTTP/1.1" + char(13) + char(10) + ...
                  "Content-Type: application/json" + char(13) + char(10) + ...
                  "Content-Length: 13" + char(13) + char(10) + ...
                  char(13) + char(10) + ...
                  "'{" + char(34) + "msg" + char(34) + ":" + char(34) + "hi" + char(34) + "}'";
            rawBytes = uint8(char(raw))';

            % Now it should parse successfully because we strip the quotes
            req = mhs.internal.HttpParser.parse(rawBytes);
            testCase.verifyClass(req.Body, 'struct');
            testCase.verifyEqual(string(req.Body.msg), "hi");
        end

        function testJsonWithDoubleQuotesRobustness(testCase)
            raw = "POST /echo HTTP/1.1" + char(13) + char(10) + ...
                  "Content-Type: application/json" + char(13) + char(10) + ...
                  "Content-Length: 13" + char(13) + char(10) + ...
                  char(13) + char(10) + ...
                  char(34) + "{" + char(34) + "msg" + char(34) + ":" + char(34) + "hi" + char(34) + "}" + char(34);
            rawBytes = uint8(char(raw))';

            % Now it should parse successfully because we strip the quotes
            req = mhs.internal.HttpParser.parse(rawBytes);
            testCase.verifyClass(req.Body, 'struct');
            testCase.verifyEqual(string(req.Body.msg), "hi");
        end

        function testValidJson(testCase)
            raw = "POST /echo HTTP/1.1" + char(13) + char(10) + ...
                  "Content-Type: application/json" + char(13) + char(10) + ...
                  "Content-Length: 12" + char(13) + char(10) + ...
                  char(13) + char(10) + ...
                  "{" + char(34) + "msg" + char(34) + ":" + char(34) + "hi" + char(34) + "}";
            rawBytes = uint8(char(raw))';

            req = mhs.internal.HttpParser.parse(rawBytes);
            testCase.verifyClass(req.Body, 'struct');
            testCase.verifyEqual(string(req.Body.msg), "hi");
        end

        function testUnquotedKeyHint(testCase)
            % Simulate a common Windows CMD issue: missing double quotes around keys
            % {msg:"hi"} instead of {"msg":"hi"}
            raw = "POST /echo HTTP/1.1" + char(13) + char(10) + ...
                  "Content-Type: application/json" + char(13) + char(10) + ...
                  "Content-Length: 10" + char(13) + char(10) + ...
                  char(13) + char(10) + ...
                  "{msg:" + char(34) + "hi" + char(34) + "}";
            rawBytes = uint8(char(raw))';

            try
                mhs.internal.HttpParser.parse(rawBytes);
                testCase.verifyFail("Should have thrown HttpParser:InvalidJson");
            catch ME
                testCase.verifyEqual(ME.identifier, 'HttpParser:InvalidJson');
                testCase.verifyTrue(contains(ME.message, "HINT: If using curl on Windows CMD"));
            end
        end
    end
end
