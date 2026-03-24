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

        function testDefaultTransportIsJava(testCase)
            server = MatlabHttpServer(8081);
            % Use metaclass to check private property
            mc = ?MatlabHttpServer;
            p = mc.PropertyList(strcmp({mc.PropertyList.Name}, 'Transport'));
            transport = server.(p.Name);
            testCase.verifyClass(transport, 'mhs.internal.JavaSocketTransport');
        end

        function testExplicitJavaTransport(testCase)
            server = MatlabHttpServer(8081, Transport="java");
            mc = ?MatlabHttpServer;
            p = mc.PropertyList(strcmp({mc.PropertyList.Name}, 'Transport'));
            transport = server.(p.Name);
            testCase.verifyClass(transport, 'mhs.internal.JavaSocketTransport');
        end

        function testExplicitGoTransport(testCase)
            try
                mhs.internal.GoSidecarTransport.findBinary();
            catch
                testCase.assumeFail('Go binary not found');
            end
            server = MatlabHttpServer(8081, Transport="go");
            mc = ?MatlabHttpServer;
            p = mc.PropertyList(strcmp({mc.PropertyList.Name}, 'Transport'));
            transport = server.(p.Name);
            testCase.verifyClass(transport, 'mhs.internal.GoSidecarTransport');
        end

        function testInvalidTransportErrors(testCase)
            testCase.verifyError(@() MatlabHttpServer(8081, Transport="bogus"), ...
                'MatlabHttpServer:invalidTransport');
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

            server.processRequestForTesting([], rawBytes);

            testCase.verifyTrue(true); % Reached here without error
        end

        function testProcessRequestWithNullSocket(testCase)
            server = MatlabHttpServer(8081);
            server.register(MockController());
            raw = ['GET /test HTTP/1.1' char(13) char(10) char(13) char(10)];
            rawBytes = uint8(raw)';
            % Verify it doesn't crash with null socket
            server.processRequestForTesting([], rawBytes);
            testCase.verifyTrue(true);
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
            % Should log warning or just work depending on transport
            server.start();
            server.stop();
            testCase.verifyTrue(true);
        end

        function testProcessRequestParserError(testCase)
            server = MatlabHttpServer(8102);
            % This should trigger the inner catch block in processRequest
            server.processRequestForTesting([], uint8('INVALID'));
            testCase.verifyTrue(true);
        end

        function testServeStaticRegisters(testCase)
            % Smoke test — confirms the method exists and accepts args
            server = MatlabHttpServer(8081);
            testCase.verifyWarningFree(@() server.serveStatic("."));
        end

        function testServeStaticWithUrlPrefix(testCase)
            server = MatlabHttpServer(8081);
            testCase.verifyWarningFree(@() server.serveStatic(".", UrlPrefix="/docs/"));
        end

        function testDeleteReleasesPortForReuse(testCase)
            port = 8105;

            server1 = MatlabHttpServer(port);
            server1.start();
            server1.stop();
            delete(server1);

            pause(0.2);

            server2 = MatlabHttpServer(port);
            testCase.verifyWarningFree(@() server2.start());
            server2.stop();
            delete(server2);
        end
    end
end
