classdef ApiTestCaseController < mhs.ApiController
    % ApiTestCaseController Test controller used by TestApiTestCase

    methods (Access = protected)
        function registerRoutes(obj)
            obj.get("/test/hello", @obj.getHello);
            obj.post("/test/echo", @obj.postEcho);
            obj.put("/test/echo", @obj.putEcho);
            obj.patch("/test/echo", @obj.patchEcho);
            obj.delete("/test/resource", @obj.deleteResource);
            obj.get("/test/query", @obj.getQuery);
            obj.get("/test/users/:id", @obj.getUserById);
            obj.get("/test/created", @obj.getCreated);
            obj.get("/test/bad-request", @obj.getBadRequest);
            obj.get("/test/header", @obj.getHeaderEcho);
            obj.get("/test/struct-header", @obj.getStructHeaderEcho);
            obj.post("/test/text", @obj.postText);
            obj.get("/test/plain", @obj.getPlain);
        end
    end

    methods
        function res = getHello(~, ~, res)
            % GETHELLO Return a simple JSON payload.
            res.json(struct("message", "hello"));
        end

        function res = postEcho(~, req, res)
            % POSTECHO Echo the parsed request body.
            res.json(req.Body);
        end

        function res = putEcho(~, req, res)
            % PUTECHO Echo the parsed request body for PUT.
            res.json(req.Body);
        end

        function res = patchEcho(~, req, res)
            % PATCHECHO Echo the parsed request body for PATCH.
            res.json(req.Body);
        end

        function res = deleteResource(~, ~, res)
            % DELETERESOURCE Return a deletion confirmation payload.
            res.json(struct("deleted", true));
        end

        function res = getQuery(~, req, res)
            % GETQUERY Return a query parameter value.
            res.json(struct("key", req.QueryParams("key")));
        end

        function res = getUserById(~, req, res)
            % GETUSERBYID Return a path parameter value.
            res.json(struct("id", req.PathParams("id")));
        end

        function res = getCreated(~, ~, res)
            % GETCREATED Return a 201 response for helper verification.
            res.status(201).json(struct("created", true));
        end

        function res = getBadRequest(~, ~, res)
            % GETBADREQUEST Return a 400 response for helper verification.
            res.status(400).json(struct("error", "bad request"));
        end

        function res = getHeaderEcho(~, req, res)
            % GETHEADERECHO Return a caller-supplied request header value.
            res.header("X-Test-Header", req.Headers("X-Test-Header"));
            res.json(struct("ok", true));
        end

        function res = getStructHeaderEcho(~, req, res)
            % GETSTRUCTHEADERECHO Return a struct-compatible request header.
            res.header("X_Test_Header", req.Headers("X_Test_Header"));
            res.json(struct("ok", true));
        end

        function res = postText(~, req, res)
            % POSTTEXT Echo a plain-text request body.
            res.send(string(req.Body));
        end

        function res = getPlain(~, ~, res)
            % GETPLAIN Return a non-JSON response body.
            res.send("plain text");
        end
    end
end
