classdef BasicController < mhs.ApiController
    methods (Access = protected)
        function registerRoutes(obj)
            obj.get('/api/hello', @obj.getHello);
            obj.post('/api/echo', @obj.postEcho);
            obj.get('/api/users/:id', @obj.getUserById);
        end
    end

    methods
        function res = getHello(~, ~, res)
            res.json(struct('message', 'Hello from MATLAB HTTP Server'));
        end

        function res = postEcho(~, req, res)
            res.json(req.Body);
        end

        function res = getUserById(~, req, res)
            id = req.PathParams('id');
            res.json(struct('id', id, 'name', 'Test User'));
        end
    end
end