classdef TestApiController < matlab.unittest.TestCase
    % TestApiController Unit tests for ApiController class

    methods (Test)
        function testRouteRegistration(testCase)
            ctrl = MockApiController();
            routes = ctrl.Routes;

            testCase.verifyEqual(numel(routes), 5);

            methods = [routes.Method];
            paths = [routes.Path];

            testCase.verifyTrue(ismember("GET", methods));
            testCase.verifyTrue(ismember("POST", methods));
            testCase.verifyTrue(ismember("PUT", methods));
            testCase.verifyTrue(ismember("DELETE", methods));
            testCase.verifyTrue(ismember("PATCH", methods));

            testCase.verifyTrue(ismember("/get", paths));
        end
    end
end
