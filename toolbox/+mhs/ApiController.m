classdef (Abstract) ApiController < handle
    % ApiController Abstract base class for API controllers
    %   Subclass this to define REST API endpoints. You must implement
    %   the abstract registerRoutes method to map paths to your handler
    %   methods using the obj.get(), obj.post(), etc. helpers.

    properties (Access = public)
        Routes (1,:) struct = struct('Method', {}, 'Path', {}, 'Handler', {})
    end

    methods (Abstract, Access = protected)
        % REGISTERROUTES Map HTTP verbs and paths to handler methods
        %   Override this method in your subclass to register your routes
        %   using obj.get(), obj.post(), obj.put(), obj.delete(), and
        %   obj.patch().
        registerRoutes(obj)
    end

    methods
        function obj = ApiController()
            % APICONTROLLER Construct an instance of ApiController
            %   The constructor automatically calls the abstract
            %   registerRoutes method implemented by subclasses.
            obj.registerRoutes();
        end
    end

    methods (Access = protected)
        function get(obj, path, handler)
            % GET Register a GET route
            arguments
                obj (1,1) mhs.ApiController
                path (1,1) string
                handler (1,1) function_handle
            end
            obj.register("GET", path, handler);
        end

        function post(obj, path, handler)
            % POST Register a POST route
            arguments
                obj (1,1) mhs.ApiController
                path (1,1) string
                handler (1,1) function_handle
            end
            obj.register("POST", path, handler);
        end

        function put(obj, path, handler)
            % PUT Register a PUT route
            arguments
                obj (1,1) mhs.ApiController
                path (1,1) string
                handler (1,1) function_handle
            end
            obj.register("PUT", path, handler);
        end

        function delete(obj, path, handler)
            % DELETE Register a DELETE route
            arguments
                obj (1,1) mhs.ApiController
                path (1,1) string
                handler (1,1) function_handle
            end
            obj.register("DELETE", path, handler);
        end

        function patch(obj, path, handler)
            % PATCH Register a PATCH route
            arguments
                obj (1,1) mhs.ApiController
                path (1,1) string
                handler (1,1) function_handle
            end
            obj.register("PATCH", path, handler);
        end
    end

    methods (Access = private)
        function register(obj, method, path, handler)
            % REGISTER Register a route
            arguments
                obj (1,1) mhs.ApiController
                method (1,1) string
                path (1,1) string
                handler (1,1) function_handle
            end

            newRoute.Method = method;
            newRoute.Path = path;
            newRoute.Handler = handler;

            obj.Routes(end+1) = newRoute;
        end
    end
end