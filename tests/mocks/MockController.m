classdef MockController < mhs.ApiController
    methods (Access = protected)
        function registerRoutes(obj)
            obj.get('/test', @obj.handleTest);
            obj.post('/api/echo', @obj.handleEcho);
        end
    end
    methods
        function res = handleTest(~, ~, res)
            res.send("test");
        end
        function res = handleEcho(~, req, res)
            res.json(req.Body);
        end
    end
end
