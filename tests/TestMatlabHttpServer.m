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
            raw = "GET /test HTTP/1.1" + char(13) + char(10) + ...
                  "Host: localhost" + char(13) + char(10) + ...
                  char(13) + char(10);
            rawBytes = uint8(char(raw))';

            % We can't easily mock the socket's write method here without more complexity,
            % but calling processRequestForTesting will at least verify HttpParser visibility
            % and basic dispatch logic.
            server.processRequestForTesting([], rawBytes);

            testCase.verifyTrue(true); % Reached here without error
        end
    end
end
