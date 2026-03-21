classdef MockRouteController < mhs.ApiController
    methods (Access = protected)
        function registerRoutes(obj)
            obj.get('/api/ping', @obj.ping);
            obj.get('/api/users/:id', @obj.getUser);
            obj.get('/api/users/me', @obj.getMe);
            obj.get('/api/orgs/:orgId/users/:userId', @obj.getOrgUser);
            obj.post('/api/users', @obj.createUser);
            obj.patch('/api/users/:id', @obj.patchUser);
            obj.get('/api/error', @obj.throwError);
            obj.get('/api/duplicate', @obj.duplicate1);
            obj.get('/api/duplicate', @obj.duplicate2);
        end
    end
    methods
        function res = ping(~, ~, res)
            res.send("pong");
        end
        function res = getUser(~, req, res)
            id = req.PathParams("id");
            res.json(struct('userId', id));
        end
        function res = getMe(~, ~, res)
            res.send("this is me");
        end
        function res = getOrgUser(~, req, res)
            orgId = req.PathParams("orgId");
            userId = req.PathParams("userId");
            res.json(struct('orgId', orgId, 'userId', userId));
        end
        function res = createUser(~, ~, res)
            res.status(201).send("created");
        end
        function res = patchUser(~, req, res)
            id = req.PathParams("id");
            res.send("patched " + id);
        end
        function res = throwError(~, ~, ~)
            error("Mock:Error", "Intentional error");
        end
        function res = duplicate1(~, ~, res)
            res.send("first");
        end
        function res = duplicate2(~, ~, res)
            res.send("second");
        end
    end
end
