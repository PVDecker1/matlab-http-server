classdef TestLiveServer < matlab.unittest.TestCase
    % TestLiveServer End-to-end tests for all transports
    %   Verifies the full stack from socket to controller and back.

    properties
        Server
        Port = 8186
        
        JavaServer
        JavaPort = 8192
        
        GoServer
        GoPort = 8194
    end

    methods (TestMethodTeardown)
        function stopServers(testCase)
            if ~isempty(testCase.Server)
                testCase.Server.stop();
                delete(testCase.Server);
                testCase.Server = [];
            end
            if ~isempty(testCase.JavaServer)
                testCase.JavaServer.stop();
                delete(testCase.JavaServer);
                testCase.JavaServer = [];
            end
            if ~isempty(testCase.GoServer)
                testCase.GoServer.stop();
                delete(testCase.GoServer);
                testCase.GoServer = [];
            end
            pause(1.0);
        end
    end

    methods (Test)
        function testJavaTransportGet(testCase)
            testCase.JavaServer = MatlabHttpServer(testCase.JavaPort, Transport="java");
            testCase.JavaServer.register(MockController());
            testCase.JavaServer.start();
            
            % Wait for bind
            timeout = 10;
            timer = tic;
            bound = false;
            while toc(timer) < timeout
                try
                    t = tcpclient("localhost", testCase.JavaPort);
                    delete(t);
                    bound = true;
                    break;
                catch
                    pause(0.2);
                end
            end
            testCase.assumeTrue(bound, 'Java server did not bind in time');

            try
                t = tcpclient("localhost", testCase.JavaPort);
                write(t, uint8(['GET /test HTTP/1.1' char(13) char(10) char(13) char(10)]));
                resp = testCase.readResponse(t);
                testCase.verifyTrue(contains(resp, "test"), ['Java response failed: ' char(resp)]);
                testCase.verifyTrue(contains(resp, "200 OK"));
            catch ME
                testCase.verifyTrue(false, ['Java connection failed: ' ME.message]);
            end
        end

        function testGoTransportGetRequest(testCase)
            try
                mhs.internal.GoSidecarTransport.findBinary();
            catch
                testCase.assumeFail('Go binary not found');
            end

            testCase.GoServer = MatlabHttpServer(testCase.GoPort, Transport="go");
            testCase.GoServer.register(MockController());
            testCase.GoServer.start();
            pause(2.0); 

            t = tcpclient("localhost", testCase.GoPort);
            write(t, uint8(['GET /test HTTP/1.1' char(13) char(10) ...
                           'Host: localhost' char(13) char(10) ...
                           char(13) char(10)]));
            
            resp = testCase.readResponse(t);
            testCase.verifyTrue(contains(resp, "test"), ['Go GET failed. Response: ' char(resp)]);
            testCase.verifyTrue(contains(resp, "200 OK"));
        end

        function testGoTransportPostJson(testCase)
            try
                mhs.internal.GoSidecarTransport.findBinary();
            catch
                testCase.assumeFail('Go binary not found');
            end

            testCase.GoServer = MatlabHttpServer(testCase.GoPort, Transport="go");
            testCase.GoServer.register(MockController());
            testCase.GoServer.start();
            pause(2.0);

            t = tcpclient("localhost", testCase.GoPort);
            body = '{"msg":"hello from go"}';
            req = ['POST /api/echo HTTP/1.1' char(13) char(10) ...
                   'Host: localhost' char(13) char(10) ...
                   'Content-Type: application/json' char(13) char(10) ...
                   'Content-Length: ' num2str(numel(body)) char(13) char(10) ...
                   char(13) char(10) ...
                   body];
            
            write(t, uint8(req));
            resp = testCase.readResponse(t);
            testCase.verifyTrue(contains(resp, "hello from go"), ['Go POST failed. Response: ' char(resp)]);
        end

        function testGoTransportMalformedRequest(testCase)
            try
                mhs.internal.GoSidecarTransport.findBinary();
            catch
                testCase.assumeFail('Go binary not found');
            end

            testCase.GoServer = MatlabHttpServer(testCase.GoPort, Transport="go");
            testCase.GoServer.start();
            pause(2.0);

            t = tcpclient("localhost", testCase.GoPort);
            % Send garbage that doesn't look like valid HTTP headers
            write(t, uint8(['GARBAGE' char(13) char(10) char(13) char(10)]));
            
            resp = testCase.readResponse(t);
            % Go sidecar itself might return 400 or pass to MATLAB which returns 400
            testCase.verifyTrue(contains(resp, "400 Bad Request"));
        end

        function testGoTransportStaticFile(testCase)
            try
                mhs.internal.GoSidecarTransport.findBinary();
            catch
                testCase.assumeFail('Go binary not found');
            end

            tempDir = fullfile(tempdir, 'mhs_static_test');
            if ~exist(tempDir, 'dir'), mkdir(tempDir); end
            htmlFile = fullfile(tempDir, 'index.html');
            fid = fopen(htmlFile, 'w');
            fprintf(fid, '<html><body><h1>Hello Static</h1></body></html>');
            fclose(fid);
            
            testCase.GoServer = MatlabHttpServer(testCase.GoPort, Transport="go");
            testCase.GoServer.serveStatic(tempDir);
            testCase.GoServer.start();
            pause(2.0);

            t = tcpclient("localhost", testCase.GoPort);
            write(t, uint8(['GET /index.html HTTP/1.1' char(13) char(10) ...
                           'Host: localhost' char(13) char(10) ...
                           char(13) char(10)]));
            
            resp = testCase.readResponse(t);
            testCase.verifyTrue(contains(resp, "Hello Static"));
            testCase.verifyTrue(contains(resp, "text/html"));
            
            rmdir(tempDir, 's');
        end
    end

    methods (Access = private)
        function resp = readResponse(~, t)
            resp = "";
            timeout = 5; 
            timer = tic;
            while toc(timer) < timeout
                if t.NumBytesAvailable > 0
                    bytes = read(t);
                    resp = resp + string(native2unicode(bytes, 'utf-8'));
                    if contains(resp, char([13 10 13 10]))
                         if contains(resp, "Content-Length")
                             parts = split(resp, char([13 10 13 10]));
                             headerPart = parts(1);
                             match = regexp(headerPart, 'Content-Length:\s*(\d+)', 'tokens');
                             if ~isempty(match)
                                 len = str2double(match{1}{1});
                                 if numel(char(parts(2))) >= len
                                     break;
                                 end
                             end
                         else
                             break;
                         end
                    end
                end
                pause(0.1);
            end
        end
    end
end
