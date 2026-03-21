classdef TestStaticFileHandler < matlab.unittest.TestCase
    properties
        TempDir
        Handler
    end

    methods (TestMethodSetup)
        function setup(testCase)
            % Create a unique temp directory for each test
            testCase.TempDir = fullfile(tempdir, "mhs_test_" + string(datetime('now', 'Format', 'yyyyMMdd_HHmmss_SSS')));
            mkdir(testCase.TempDir);
            testCase.Handler = mhs.StaticFileHandler(testCase.TempDir);
        end
    end

    methods (TestMethodTeardown)
        function teardown(testCase)
            if isfolder(testCase.TempDir)
                rmdir(testCase.TempDir, 's');
            end
        end
    end

    methods (Test)
        function testServesHtmlFile(testCase)
            % Write an index.html to the temp dir
            content = "<html><body>Hello World</body></html>";
            filePath = fullfile(testCase.TempDir, "index.html");
            fid = fopen(filePath, 'w');
            fprintf(fid, '%s', content);
            fclose(fid);

            req = mhs.HttpRequest();
            req.Path = "/index.html";
            req.Method = "GET";
            res = mhs.HttpResponse();

            handled = testCase.Handler.handle(req, res);

            testCase.verifyTrue(handled);
            [code, ~, body] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 200);
            
            % Verify body matches
            expectedBody = unicode2native(char(content), 'utf-8')';
            testCase.verifyEqual(body, expectedBody);
        end

        function testSetsCorrectMimeTypeHtml(testCase)
            filePath = fullfile(testCase.TempDir, "test.html");
            fid = fopen(filePath, 'w');
            fprintf(fid, 'test');
            fclose(fid);

            req = mhs.HttpRequest();
            req.Path = "/test.html";
            res = mhs.HttpResponse();

            testCase.Handler.handle(req, res);
            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(hdrs("Content-Type"), "text/html; charset=utf-8");
        end

        function testSetsCorrectMimeTypeCss(testCase)
            filePath = fullfile(testCase.TempDir, "style.css");
            fid = fopen(filePath, 'w');
            fprintf(fid, 'body { color: red; }');
            fclose(fid);

            req = mhs.HttpRequest();
            req.Path = "/style.css";
            res = mhs.HttpResponse();

            testCase.Handler.handle(req, res);
            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(hdrs("Content-Type"), "text/css");
        end

        function testSetsCorrectMimeTypePng(testCase)
            filePath = fullfile(testCase.TempDir, "image.png");
            dummyBytes = uint8([137 80 78 71 13 10 26 10])'; % PNG signature
            fid = fopen(filePath, 'wb');
            fwrite(fid, dummyBytes, 'uint8');
            fclose(fid);

            req = mhs.HttpRequest();
            req.Path = "/image.png";
            res = mhs.HttpResponse();

            testCase.Handler.handle(req, res);
            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(hdrs("Content-Type"), "image/png");
        end

        function testDirectoryResolvesToIndexHtml(testCase)
            % Write subdir/index.html
            subdir = fullfile(testCase.TempDir, "subdir");
            mkdir(subdir);
            content = "Subdir content";
            filePath = fullfile(subdir, "index.html");
            fid = fopen(filePath, 'w');
            fprintf(fid, '%s', content);
            fclose(fid);

            req = mhs.HttpRequest();
            req.Path = "/subdir/";
            res = mhs.HttpResponse();

            handled = testCase.Handler.handle(req, res);
            testCase.verifyTrue(handled);
            
            [code, ~, body] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 200);
            expectedBody = unicode2native(char(content), 'utf-8')';
            testCase.verifyEqual(body, expectedBody);
            
            % Also test without trailing slash
            req.Path = "/subdir";
            res2 = mhs.HttpResponse();
            handled2 = testCase.Handler.handle(req, res2);
            testCase.verifyTrue(handled2);
            [~, ~, body2] = res2.getRawResponseForTesting();
            testCase.verifyEqual(body2, expectedBody);
        end

        function testMissingFileReturnsFalse(testCase)
            req = mhs.HttpRequest();
            req.Path = "/nonexistent.html";
            res = mhs.HttpResponse();

            handled = testCase.Handler.handle(req, res);
            testCase.verifyFalse(handled);
            testCase.verifyFalse(res.isSent());
        end

        function testPathTraversalBlocked(testCase)
            % This is a bit tricky to test cross-platform
            % Try to escape the root using ..
            req = mhs.HttpRequest();
            req.Path = "/../something_outside";
            res = mhs.HttpResponse();

            handled = testCase.Handler.handle(req, res);
            testCase.verifyTrue(handled);
            [code, ~, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 403);
        end

        function testUrlPrefixStripped(testCase)
            handler = mhs.StaticFileHandler(testCase.TempDir, UrlPrefix="/static/");
            
            filePath = fullfile(testCase.TempDir, "style.css");
            fid = fopen(filePath, 'w');
            fprintf(fid, 'css');
            fclose(fid);

            req = mhs.HttpRequest();
            req.Path = "/static/style.css";
            res = mhs.HttpResponse();

            handled = handler.handle(req, res);
            testCase.verifyTrue(handled);
            [code, ~, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(code, 200);
        end

        function testUrlPrefixMismatchReturnsFalse(testCase)
            handler = mhs.StaticFileHandler(testCase.TempDir, UrlPrefix="/static/");
            
            req = mhs.HttpRequest();
            req.Path = "/other/file.css";
            res = mhs.HttpResponse();

            handled = handler.handle(req, res);
            testCase.verifyFalse(handled);
        end

        function testUnknownExtensionServedAsOctetStream(testCase)
            filePath = fullfile(testCase.TempDir, "file.xyz");
            fid = fopen(filePath, 'w');
            fprintf(fid, 'binary stuff');
            fclose(fid);

            req = mhs.HttpRequest();
            req.Path = "/file.xyz";
            res = mhs.HttpResponse();

            testCase.Handler.handle(req, res);
            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(hdrs("Content-Type"), "application/octet-stream");
        end

        function testBinaryContentNotCorrupted(testCase)
            filePath = fullfile(testCase.TempDir, "image.png");
            % Create 256 bytes covering the whole range 0-255
            binaryBytes = uint8(0:255)';
            fid = fopen(filePath, 'wb');
            fwrite(fid, binaryBytes, 'uint8');
            fclose(fid);

            req = mhs.HttpRequest();
            req.Path = "/image.png";
            res = mhs.HttpResponse();

            testCase.Handler.handle(req, res);
            [~, ~, body] = res.getRawResponseForTesting();
            testCase.verifyEqual(body, binaryBytes);
        end

        function testConstructorWithAbsolutePath(testCase)
            % Test with a path that already looks absolute
            absPath = testCase.TempDir;
            handler = mhs.StaticFileHandler(absPath);
            % We can't easily check private properties, but we can check behavior
            
            filePath = fullfile(testCase.TempDir, "abs.txt");
            fid = fopen(filePath, 'w');
            fprintf(fid, 'abs');
            fclose(fid);
            
            req = mhs.HttpRequest();
            req.Path = "/abs.txt";
            res = mhs.HttpResponse();
            testCase.verifyTrue(handler.handle(req, res));
        end

        function testConstructorNormalizesPrefix(testCase)
            % Prefix without leading slash
            handler = mhs.StaticFileHandler(testCase.TempDir, UrlPrefix="static");
            
            filePath = fullfile(testCase.TempDir, "test.txt");
            fid = fopen(filePath, 'w');
            fprintf(fid, 'test');
            fclose(fid);
            
            req = mhs.HttpRequest();
            req.Path = "/static/test.txt";
            res = mhs.HttpResponse();
            testCase.verifyTrue(handler.handle(req, res));
        end

        function testHandleWithLeadingSlashes(testCase)
            % Test case where path starts with multiple slashes or prefix stripping 
            % results in a leading slash
            req = mhs.HttpRequest();
            req.Path = "//index.html";
            res = mhs.HttpResponse();
            
            % Create index.html
            fid = fopen(fullfile(testCase.TempDir, "index.html"), 'w');
            fprintf(fid, 'hello');
            fclose(fid);
            
            testCase.verifyTrue(testCase.Handler.handle(req, res));
        end

        function testDirectoryWithoutIndexReturnsFalse(testCase)
            % Subdirectory with NO index.html
            emptyDir = fullfile(testCase.TempDir, "empty");
            mkdir(emptyDir);
            
            req = mhs.HttpRequest();
            req.Path = "/empty/";
            res = mhs.HttpResponse();
            
            testCase.verifyFalse(testCase.Handler.handle(req, res));
        end

        function testHandleWithRootPath(testCase)
            % Requesting "/" should look for index.html in RootDir
            fid = fopen(fullfile(testCase.TempDir, "index.html"), 'w');
            fprintf(fid, 'root index');
            fclose(fid);
            
            req = mhs.HttpRequest();
            req.Path = "/";
            res = mhs.HttpResponse();
            
            testCase.verifyTrue(testCase.Handler.handle(req, res));
        end

        function testHandleWithNonExistentDirectoryReturnsFalse(testCase)
            req = mhs.HttpRequest();
            req.Path = "/nonexistent_dir/";
            res = mhs.HttpResponse();
            
            testCase.verifyFalse(testCase.Handler.handle(req, res));
        end

        function testHandleWithInvalidPathChar(testCase)
            % Passing a null character might trigger the catch block in java.io.File
            req = mhs.HttpRequest();
            req.Path = "/test" + char(0) + ".txt";
            res = mhs.HttpResponse();
            
            handled = testCase.Handler.handle(req, res);
            testCase.verifyFalse(handled);
        end

        function testSetsCorrectMimeTypeJpeg(testCase)
            filePath = fullfile(testCase.TempDir, "test.jpeg");
            fid = fopen(filePath, 'w');
            fprintf(fid, 'test');
            fclose(fid);

            req = mhs.HttpRequest();
            req.Path = "/test.jpeg";
            res = mhs.HttpResponse();

            testCase.Handler.handle(req, res);
            [~, hdrs, ~] = res.getRawResponseForTesting();
            testCase.verifyEqual(hdrs("Content-Type"), "image/jpeg");
        end
    end
end
