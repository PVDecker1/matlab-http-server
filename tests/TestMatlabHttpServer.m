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
    end
end

classdef MockController < mhs.ApiController
    methods (Access = protected)
        function registerRoutes(obj)
            obj.get('/test', @obj.handleTest);
        end
    end
    methods
        function res = handleTest(~, ~, res)
            res.send("test");
        end
    end
end