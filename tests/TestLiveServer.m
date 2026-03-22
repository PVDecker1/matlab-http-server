classdef (TestTags = {'RequiresInstrumentControl'}) TestLiveServer < matlab.unittest.TestCase
    % TestLiveServer End-to-end tests using live tcpserver and tcpclient
    %   This test verifies the full stack from socket to controller and back.

    properties
        Server
        Port = 8086
    end

    methods (TestMethodSetup)
        function startServer(testCase)
            % Skip these tests if Instrument Control Toolbox is missing (e.g. in CI)
            testCase.assumeTrue(~isempty(ver('instrument')), ...
                'Instrument Control Toolbox is required for live server tests.');

            testCase.Server = MatlabHttpServer(testCase.Port);
            testCase.Server.register(MockController());
            testCase.Server.start();
            % Small pause to allow server to bind to port
            pause(0.2);
        end
    end

    methods (TestMethodTeardown)
        function stopServer(testCase)
            if ~isempty(testCase.Server)
                testCase.Server.stop();
                delete(testCase.Server);
            end
            % Allow socket to be released
            pause(0.2);
        end
    end

    methods (Test)
        function testGetTest(testCase)
            t = tcpclient("localhost", testCase.Port);
            write(t, uint8(['GET /test HTTP/1.1' char(13) char(10) char(13) char(10)]));
            
            % Wait for response while allowing tcpserver callbacks to run
            resp = testCase.readResponse(t);
            testCase.verifyTrue(contains(resp, "test"));
        end

        function testPostEcho(testCase)
            t = tcpclient("localhost", testCase.Port);
            body = ['{' char(34) 'msg' char(34) ':' char(34) 'hi' char(34) '}'];
            req = ['POST /api/echo HTTP/1.1' char(13) char(10) ...
                   'Content-Type: application/json' char(13) char(10) ...
                   'Content-Length: ' num2str(numel(body)) char(13) char(10) ...
                   char(13) char(10) ...
                   body];
            
            write(t, uint8(req));
            
            resp = testCase.readResponse(t);
            % Extract body after \r\n\r\n
            parts = split(resp, char([13 10 13 10]));
            bodyOut = parts(2);
            decoded = jsondecode(bodyOut);
            testCase.verifyEqual(string(decoded.msg), "hi");
        end

        function testPostRobustJson(testCase)
            % This simulates what happens when curl on Windows CMD sends literal single quotes
            t = tcpclient("localhost", testCase.Port);
            
            % Quote wrapped JSON: '{"msg":"robust"}'
            body = ['' char(34) 'msg' char(34) ':' char(34) 'robust' char(34) ''];
            % Wait, body is '{"msg":"robust"}'
            body = ['''' '{' char(34) 'msg' char(34) ':' char(34) 'robust' char(34) '}' ''''];
            req = ['POST /api/echo HTTP/1.1' char(13) char(10) ...
                   'Content-Type: application/json' char(13) char(10) ...
                   'Content-Length: ' char(string(numel(body))) char(13) char(10) ...
                   char(13) char(10) ...
                   body];
            
            write(t, uint8(req));
            
            resp = testCase.readResponse(t);
            parts = split(resp, char([13 10 13 10]));
            bodyOut = parts(2);
            decoded = jsondecode(bodyOut);
            testCase.verifyEqual(string(decoded.msg), "robust");
        end

        function testMalformedRequestResilience(testCase)
            % Malformed HTTP request returns 400, server remains running
            t = tcpclient("localhost", testCase.Port);
            % Send something that will fail HttpParser.parse but has \r\n\r\n
            write(t, uint8(['NOT-HTTP' char(13) char(10) char(13) char(10)]));
            
            resp = testCase.readResponse(t);
            testCase.verifyTrue(contains(resp, "400 Bad Request"));
        end

        function testValidRequestAfterMalformed(testCase)
            % Send malformed then valid. 
            % Note: Server closes connection after each response.
            t1 = tcpclient("localhost", testCase.Port);
            write(t1, uint8(['GARBAGE' char(13) char(10) char(13) char(10)]));
            testCase.readResponse(t1);
            delete(t1);
            
            % Give server a moment to reset
            pause(0.2);
            
            t2 = tcpclient("localhost", testCase.Port);
            write(t2, uint8(['GET /test HTTP/1.1' char(13) char(10) char(13) char(10)]));
            resp = testCase.readResponse(t2);
            testCase.verifyTrue(contains(resp, "test"));
            testCase.verifyTrue(contains(resp, "200 OK"));
        end
    end

    methods (Access = private)
        function resp = readResponse(~, t)
            % Read data until connection closes or timeout, using pause 
            % to allow tcpserver background callbacks to fire.
            resp = "";
            timeout = 5; % seconds
            timer = tic;
            while toc(timer) < timeout
                if t.NumBytesAvailable > 0
                    bytes = read(t);
                    resp = resp + string(native2unicode(bytes, 'utf-8'));
                    % In our server, Connection is closed after response
                    if contains(resp, "Content-Length") && ...
                       numel(split(resp, char([13 10 13 10]))) > 1
                        break;
                    end
                end
                pause(0.1); % Crucial to let tcpserver process data
            end
        end
    end
end
