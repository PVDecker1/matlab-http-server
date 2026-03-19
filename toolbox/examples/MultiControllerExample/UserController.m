classdef UserController < mhs.ApiController
    methods (Access = protected)
        function registerRoutes(obj)
            obj.get('/api/users', @obj.getUsers);
        end
    end
    methods
        function res = getUsers(~, ~, res)
            res.json(struct('users', ["Alice", "Bob"]));
        end
    end
end