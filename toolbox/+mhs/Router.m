classdef Router < handle
    % Router Dispatches HTTP requests to appropriate ApiController methods
    %   Aggregates ApiController instances, stores their routes, matches
    %   incoming HttpRequest paths, and extracts path parameters.

    properties (Access = private)
        Routes (1,:) struct = struct('Method', {}, 'Pattern', {}, 'Handler', {}, 'ParamNames', {})
    end

    methods
        function obj = Router()
            % ROUTER Construct an instance of Router
        end

        function register(obj, controller)
            % REGISTER Register all routes from an ApiController instance
            arguments
                obj (1,1) mhs.Router
                controller (1,1) mhs.ApiController
            end

            for i = 1:numel(controller.Routes)
                route = controller.Routes(i);

                % Convert route path to regex and extract param names
                [pattern, paramNames] = obj.pathToRegex(route.Path);

                newRoute.Method = route.Method;
                newRoute.Pattern = pattern;
                newRoute.Handler = route.Handler;
                newRoute.ParamNames = paramNames;

                obj.Routes(end+1) = newRoute;
            end
        end

        function handled = dispatch(obj, req, res)
            % DISPATCH Find matching route and execute handler
            arguments
                obj (1,1) mhs.Router
                req (1,1) mhs.HttpRequest
                res (1,1) mhs.HttpResponse
            end

            handled = false;

            for i = 1:numel(obj.Routes)
                route = obj.Routes(i);

                % Match method
                if strcmpi(req.Method, route.Method)
                    % Match path pattern using 'once' for initial check
                    match = regexp(req.Path, route.Pattern, 'once');

                    if ~isempty(match)
                        % Route matched!
                        handled = true;

                        % Extract path parameters if any are defined
                        if ~isempty(route.ParamNames)
                            tokens = regexp(req.Path, route.Pattern, 'tokens', 'once');
                            for j = 1:numel(route.ParamNames)
                                req.PathParams(route.ParamNames(j)) = string(tokens{j});
                            end
                        end

                        % Call handler
                        try
                            % Ensure handler receives and returns res
                            res = route.Handler(req, res);

                            % Fallback for users who forget to return res but it writes
                            if ~res.isSent()
                                res.write();
                            end
                        catch ME
                            disp("[matlab-http-server ERROR] Handler error: " + ME.message);
                            if ~res.isSent()
                                res.status(500).send("Internal Server Error");
                            end
                        end

                        return;
                    end
                end
            end

            % If no route matched
            if ~res.isSent()
                res.status(404).send("Not Found");
            end
        end
    end

    methods (Access = private)
        function [pattern, paramNames] = pathToRegex(~, path)
            % PATHTOREGEX Convert path string with :param to regular expression
            arguments
                ~
                path (1,1) string
            end

            paramNames = string.empty();

            % Split path by '/'
            parts = split(path, '/');
            regexParts = string.empty();

            for i = 1:numel(parts)
                part = parts(i);
                if startsWith(part, ":")
                    % Extract param name
                    paramNames(end+1) = extractAfter(part, 1);
                    % Add token capture to regex
                    regexParts(end+1) = "([^/]+)";
                else
                    regexParts(end+1) = part;
                end
            end

            % Join parts with '\/' and add start/end anchors
            pattern = "^" + join(regexParts, "/") + "$";
        end
    end
end