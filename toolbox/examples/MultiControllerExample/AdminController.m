classdef AdminController < mhs.ApiController
    methods (Access = protected)
        function registerRoutes(obj)
            obj.get('/api/admin/status', @obj.getStatus);
        end
    end
    methods
        function res = getStatus(~, ~, res)
            res.json(struct('system', 'online', 'load', rand()));
        end
    end
end