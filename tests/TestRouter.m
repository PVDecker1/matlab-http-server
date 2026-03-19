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

        function testParameterlessRouteMatches(testCase)
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

        function testSingleParamExtraction(testCase)
            router = mhs.Router();
            ctrl = MockRouteController();
            router.register(ctrl);

            req = mhs.HttpRequest("GET", "/api/users/123");
            res = mhs.HttpResponse();

            handled = router.dispatch(req, res);

            testCase.verifyTrue(handled);
            testCase.verifyEqual(req.PathParams("id"), "123");
        end

        function testMultipleParamsExtraction(testCase)
            router = mhs.Router();
            ctrl = MockRouteController();
            router.register(ctrl);

            req = mhs.HttpRequest("GET", "/api/orgs/myorg/users/456");
            res = mhs.HttpResponse();

            handled = router.dispatch(req, res);

            testCase.verifyTrue(handled);
            testCase.verifyEqual(req.PathParams("orgId"), "myorg");
            testCase.verifyEqual(req.PathParams("userId"), "456");
        end

        function testWrongMethodNoMatch(testCase)
            router = mhs.Router();
            ctrl = MockRouteController();
            router.register(ctrl);

            % /api/users has POST, but we try GET
            req = mhs.HttpRequest("GET", "/api/users");
            res = mhs.HttpResponse();

            handled = router.dispatch(req, res);

            testCase.verifyFalse(handled);
            [code, ~, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 404);
        end

        function testDuplicateRouteBehavior(testCase)
            % Duplicate route registration — current behavior: first registered wins.
            % No error is thrown. This is a known limitation.
            router = mhs.Router();
            ctrl = MockRouteController();
            router.register(ctrl);

            req = mhs.HttpRequest("GET", "/api/duplicate");
            res = mhs.HttpResponse();

            handled = router.dispatch(req, res);

            testCase.verifyTrue(handled);
            [~, ~, body] = res.getRawResponseForTesting();
            testCase.verifyEqual(string(char(body')), "first");
        end

        function testRouteOrderingHazard(testCase)
            % Route ordering hazard test.
            % /api/users/:id registered BEFORE /api/users/me will match 'me' as an id.
            % This is a known limitation — specific routes must be registered before 
            % parameterized ones to avoid being shadowed.
            router = mhs.Router();
            ctrl = MockRouteController();
            router.register(ctrl);

            req = mhs.HttpRequest("GET", "/api/users/me");
            res = mhs.HttpResponse();

            handled = router.dispatch(req, res);

            testCase.verifyTrue(handled);
            % Assert that /api/users/me was captured by the :id handler, not getMe
            testCase.verifyEqual(req.PathParams("id"), "me");
            
            [~, ~, body] = res.getRawResponseForTesting();
            bodyStr = string(char(body'));
            % The :id handler returns JSON with userId
            testCase.verifyTrue(contains(bodyStr, '"userId":"me"'));
            testCase.verifyFalse(contains(bodyStr, "this is me"));
        end

        function testPatchMethod(testCase)
            router = mhs.Router();
            ctrl = MockRouteController();
            router.register(ctrl);

            req = mhs.HttpRequest("PATCH", "/api/users/123");
            res = mhs.HttpResponse();

            handled = router.dispatch(req, res);

            testCase.verifyTrue(handled);
            [~, ~, body] = res.getRawResponseForTesting();
            testCase.verifyEqual(string(char(body')), "patched 123");
        end

        function testHandlerError(testCase)
            router = mhs.Router();
            ctrl = MockRouteController();
            router.register(ctrl);

            req = mhs.HttpRequest("GET", "/api/error");
            res = mhs.HttpResponse();

            % dispatch should catch error and return 500
            handled = router.dispatch(req, res);

            testCase.verifyTrue(handled);
            [code, ~, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 500);
        end
    end
end
