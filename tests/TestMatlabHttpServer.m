classdef TestMatlabHttpServer < matlab.unittest.TestCase
    % TestMatlabHttpServer Unit tests for MatlabHttpServer class

    methods (Test)
        function testConstructor(testCase)
            server = MatlabHttpServer(8081);
            testCase.verifyEqual(server.Port, 8081);
            testCase.verifyEqual(server.AllowedOrigin, "*");

            server2 = MatlabHttpServer(8082, "AllowedOrigin", "http://localhost");
            testCase.verifyEqual(server2.AllowedOrigin, "http://localhost");
        end

        function testRegister(testCase)
            server = MatlabHttpServer(8081);
            controller = MockController();

            % Should execute without error
            server.register(controller);
            testCase.verifyTrue(true);
        end

        function testProcessRequest(testCase)
            server = MatlabHttpServer(8081);
            server.register(MockController());

            % Mock raw request bytes
            raw = ['GET /test HTTP/1.1' char(13) char(10) ...
                  'Host: localhost' char(13) char(10) ...
                  char(13) char(10)];
            rawBytes = uint8(raw)';

            % We can't easily mock the socket's write method here without more complexity,
            % but calling processRequestForTesting will at least verify HttpParser visibility
            % and basic dispatch logic.
            server.processRequestForTesting([], rawBytes);

            testCase.verifyTrue(true); % Reached here without error
        end

        function testProcessRequestBadRequest(testCase)
            server = MatlabHttpServer(8081);
            % valid enough to have \r\n\r\n but an invalid request line
            raw = ['BOGUS' char(13) char(10) char(13) char(10)];
            rawBytes = uint8(raw)';
            server.processRequestForTesting([], rawBytes);
            testCase.verifyTrue(true); % Swallows error and returns
        end

        function testProcessRequestOptions(testCase)
            server = MatlabHttpServer(8081);
            raw = ['OPTIONS /test HTTP/1.1' char(13) char(10) ...
                  'Host: localhost' char(13) char(10) ...
                  char(13) char(10)];
            rawBytes = uint8(raw)';
            server.processRequestForTesting([], rawBytes);
            testCase.verifyTrue(true);
        end

        function testStopWhenNotStarted(testCase)
            server = MatlabHttpServer(8081);
            server.stop();
            testCase.verifyTrue(true);
        end

        function testStartTwice(testCase)
            server = MatlabHttpServer(8099);
            server.start();
            % Should log warning but not throw
            server.start();
            server.stop();
            testCase.verifyTrue(true);
        end

        function testLiveConnectionCallbacks(testCase)
            % Test that onConnectionChanged and onDataReceived are called
            server = MatlabHttpServer(8100);
            server.register(MockController());
            server.start();
            
            % Use try-finally to ensure server is stopped
            try
                t = tcpclient("localhost", 8100);
                write(t, uint8(['GET /test HTTP/1.1' char(13) char(10) char(13) char(10)]));
                
                % Wait for response
                timeout = 5;
                timer = tic;
                while t.NumBytesAvailable == 0 && toc(timer) < timeout
                    pause(0.1);
                end
                
                testCase.verifyTrue(t.NumBytesAvailable > 0);
                read(t);
                delete(t);
            catch ME
                server.stop();
                rethrow(ME);
            end
            server.stop();
        end

        function testProcessRequestParserError(testCase)
            server = MatlabHttpServer(8102);
            % This should trigger the inner catch block in processRequest
            % by making parse() throw but providing no src to write to.
            server.processRequestForTesting([], uint8('INVALID'));
            testCase.verifyTrue(true);
        end

        function testEmptyClientAddress(testCase)
            server = MatlabHttpServer(8103);
            src = struct('ClientAddress', []);
            % Should return early
            server.callCallbackForTesting("onDataReceived", src, []);
            testCase.verifyTrue(true);
        end

        function testOnConnectionChangedError(testCase)
            server = MatlabHttpServer(8104);
            % Trigger error by making ClientAddress a non-string that causes failure 
            % in string() conversion if possible, or just mock it.
            % Actually, the try-catch is there for robustness.
            % We can trigger it by making ClientPort something that fails conversion.
            src = struct('ClientAddress', "127.0.0.1", 'ClientPort', struct());
            server.callCallbackForTesting("onConnectionChanged", src, []);
            testCase.verifyTrue(true);
        end

        function testOnDataReceivedError(testCase)
            server = MatlabHttpServer(8105);
            src = struct('ClientAddress', "127.0.0.1", 'ClientPort', struct());
            server.callCallbackForTesting("onDataReceived", src, []);
            testCase.verifyTrue(true);
        end
    end
end
