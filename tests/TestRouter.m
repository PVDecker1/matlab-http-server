classdef TestRouter < matlab.unittest.TestCase
    % TestRouter Unit tests for Router class

    methods (Test)
        function testExactMatch(testCase)
            router = mhs.Router();
            ctrl = MockRouteController();
            router.register(ctrl);

            req = mhs.HttpRequest("GET", "/api/ping");
            res = mhs.HttpResponse();

            handled = router.dispatch(req, res);

            testCase.verifyTrue(handled);
            [code, ~, body] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 200);
            testCase.verifyEqual(string(char(body')), "pong");
        end

        function testPathParameters(testCase)
            router = mhs.Router();
            ctrl = MockRouteController();
            router.register(ctrl);

            req = mhs.HttpRequest("GET", "/api/users/99");
            res = mhs.HttpResponse();

            handled = router.dispatch(req, res);

            testCase.verifyTrue(handled);
            [code, ~, body] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 200);

            bodyStr = string(char(body'));
            decoded = jsondecode(bodyStr);
            testCase.verifyEqual(string(decoded.userId), "99");
        end

        function testNotFound(testCase)
            router = mhs.Router();
            ctrl = MockRouteController();
            router.register(ctrl);

            req = mhs.HttpRequest("GET", "/api/missing");
            res = mhs.HttpResponse();

            handled = router.dispatch(req, res);

            testCase.verifyFalse(handled);
            [code, ~, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 404);
        end
    end
end
