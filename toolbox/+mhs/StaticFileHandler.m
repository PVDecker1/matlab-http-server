classdef StaticFileHandler < handle
    % STATICFILEHANDLER Maps URL paths to files on disk and serves them.
    %   Internal framework class. Serves static assets like HTML, CSS, 
    %   and images. Users do not construct this directly.

    properties (Access = private)
        RootDir   (1,1) string   % Absolute canonical path to the root directory
        UrlPrefix (1,1) string   % URL prefix to strip before filesystem lookup
    end

    methods
        function obj = StaticFileHandler(rootDir, options)
            arguments
                rootDir (1,1) string
                options.UrlPrefix (1,1) string = "/"
            end

            % Resolve rootDir to an absolute path
            if ~startsWith(rootDir, ["/", "\\", ":"]) && ~contains(rootDir, ":")
                rootDir = fullfile(pwd, rootDir);
            end
            
            % Canonicalize path
            try
                f = java.io.File(rootDir);
                obj.RootDir = string(f.getCanonicalPath());
            catch
                % Fallback if Java fails
                obj.RootDir = string(rootDir);
            end

            % Normalize UrlPrefix
            prefix = options.UrlPrefix;
            if ~startsWith(prefix, "/")
                prefix = "/" + prefix;
            end
            obj.UrlPrefix = prefix;
        end

        function handled = handle(obj, req, res)
            arguments
                obj (1,1) mhs.StaticFileHandler
                req (1,1) mhs.HttpRequest
                res (1,1) mhs.HttpResponse
            end

            % 1. Strip obj.UrlPrefix from req.Path
            if ~startsWith(req.Path, obj.UrlPrefix)
                handled = false;
                return;
            end

            % Get the part of the path after the prefix
            strippedPath = extractAfter(req.Path, strlength(obj.UrlPrefix));
            % Ensure it doesn't start with / for fullfile
            if startsWith(strippedPath, ["/", "\\"])
                strippedPath = extractAfter(strippedPath, 1);
            end

            % 2. Build the candidate filesystem path
            filePath = fullfile(obj.RootDir, strippedPath);

            % 3. Path traversal check
            try
                canonicalFilePath = string(java.io.File(filePath).getCanonicalPath());
                if ~startsWith(canonicalFilePath, obj.RootDir)
                    res.status(403).send("Forbidden");
                    handled = true;
                    return;
                end
            catch
                % If canonicalization fails, assume invalid path
                handled = false;
                return;
            end

            % 4. Directory resolution
            if isfolder(filePath)
                filePath = fullfile(filePath, "index.html");
                if ~isfile(filePath)
                    handled = false;
                    return;
                end
            end

            % 5. If filePath does not exist as a file, return false
            if ~isfile(filePath)
                handled = false;
                return;
            end

            % 6. Read file bytes using fread in binary mode
            fid = fopen(filePath, 'rb');
            if fid == -1
                handled = false;
                return;
            end
            bytes = fread(fid, '*uint8');
            fclose(fid);

            % 7. Set Content-Type header
            res.header("Content-Type", obj.getMimeType(filePath));

            % 8. Call res.sendBytes(bytes)
            % Note: sendBytes will be implemented in Step 3
            res.sendBytes(bytes);

            % 9. Set handled = true
            handled = true;
        end
    end

    methods (Static, Access = private)
        function mimeType = getMimeType(filePath)
            persistent mimeMap
            if isempty(mimeMap)
                mimeMap = dictionary(...
                    ".html", "text/html; charset=utf-8", ...
                    ".css",  "text/css", ...
                    ".js",   "application/javascript", ...
                    ".json", "application/json", ...
                    ".xml",  "application/xml", ...
                    ".svg",  "image/svg+xml", ...
                    ".png",  "image/png", ...
                    ".jpg",  "image/jpeg", ...
                    ".jpeg", "image/jpeg", ...
                    ".ico",  "image/x-icon", ...
                    ".woff", "font/woff", ...
                    ".woff2", "font/woff2", ...
                    ".ttf",  "font/ttf", ...
                    ".webp", "image/webp" ...
                );
            end

            [~, ~, ext] = fileparts(filePath);
            ext = lower(string(ext));
            
            if isKey(mimeMap, ext)
                mimeType = mimeMap(ext);
            else
                mimeType = "application/octet-stream";
            end
        end
    end
end
