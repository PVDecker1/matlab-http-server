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
