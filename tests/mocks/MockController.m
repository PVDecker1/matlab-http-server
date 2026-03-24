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
            % req.Body might be uint8 (raw) or struct (already decoded by HttpParser)
            if isstruct(req.Body)
                res.json(req.Body);
            elseif isempty(req.Body)
                res.json(struct());
            else
                % Try decoding if it's raw bytes
                try
                    bodyStr = native2unicode(req.Body', 'utf-8');
                    res.json(jsondecode(bodyStr));
                catch
                    res.status(400).send("Invalid JSON echo");
                end
            end
        end
    end
end
