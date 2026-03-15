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

classdef MockApiController < mhs.ApiController
    methods (Access = protected)
        function registerRoutes(obj)
            obj.get('/get', @obj.handler);
            obj.post('/post', @obj.handler);
            obj.put('/put', @obj.handler);
            obj.delete('/delete', @obj.handler);
            obj.patch('/patch', @obj.handler);
        end
    end
    methods
        function res = handler(~, ~, res)
            res.send("ok");
        end
    end
end