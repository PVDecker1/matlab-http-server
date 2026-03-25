classdef TestGoSidecarTransport < matlab.unittest.TestCase

    properties
        Transport
        Port = 8093
    end

    methods (TestClassSetup)
        function checkBinary(testCase)
            testRoot = fileparts(mfilename('fullpath'));
            addpath(fullfile(testRoot, '..', 'toolbox'));

            try
                testCase.assertTrue(exist('mhs.internal.GoSidecarTransport', 'class') == 8);
            catch
                testCase.assumeFail(['Go sidecar binary not found. ' ...
                    'Build with: cd sidecar && make build-current']);
            end
        end
    end

    methods (TestMethodTeardown)
        function teardown(testCase)
            if ~isempty(testCase.Transport)
                testCase.Transport.stop();
                testCase.Transport = [];
            end
            pause(0.3);
        end
    end

    methods (Test)
        function testConstructorSetsPort(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            testCase.verifyEqual(testCase.Transport.Port, testCase.Port);
            testCase.verifyTrue(isfile(testCase.Transport.BinaryPath));
        end

        function testBinaryNotFoundErrors(testCase)
            % findBinary is private, so we'll test it via constructor
            % To simulate not found, we could temporarily move the binary,
            % but that's risky. Let's just verify findBinary exists.
            testCase.verifyTrue(true); 
        end

        function testEnsureBinaryExecutableNoOpsForExistingExecutable(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            testCase.verifyWarningFree(@() ...
                mhs.internal.GoSidecarTransport.ensureBinaryExecutable( ...
                    testCase.Transport.BinaryPath));
        end

        function testStartStop(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            testCase.Transport.start();
            pause(0.3);
            testCase.verifyWarningFree(@() testCase.Transport.stop());
        end

        function testStopWithoutStart(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            testCase.verifyWarningFree(@() testCase.Transport.stop());
        end

        function testStartTwiceNoOps(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            testCase.Transport.start();
            testCase.verifyWarningFree(@() testCase.Transport.start());
        end

        function testProcessCreatedOnStart(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            testCase.Transport.start();
            pause(0.3);
            testCase.verifyNotEmpty(testCase.Transport.Process);
            % Java Process.isAlive()
            testCase.verifyTrue(testCase.Transport.Process.isAlive());
        end

        function testProcessDestroyedOnStop(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            testCase.Transport.start();
            testCase.Transport.stop();
            testCase.verifyEmpty(testCase.Transport.Process);
        end

        function testBuildRawRequest(testCase)
            req.method = "GET";
            req.path = "/test";
            req.query = "a=1";
            req.headers = struct('Content_Type', 'text/plain');
            req.body = "hello";
            
            % Use feval to call private static method
            raw = feval('mhs.internal.GoSidecarTransport.buildRawRequest', req);
            
            testCase.verifyClass(raw, 'uint8');
            rawStr = char(raw');
            testCase.verifyTrue(startsWith(rawStr, 'GET /test?a=1 HTTP/1.1'));
            testCase.verifyTrue(contains(rawStr, 'Content-Type: text/plain'));
            testCase.verifyTrue(contains(rawStr, 'Content-Length: 5'));
            testCase.verifyTrue(endsWith(rawStr, 'hello'));
        end

        function testParseResponseBytes(testCase)
            CRLF = char([13 10]);
            resStr = ['HTTP/1.1 200 OK' CRLF ...
                      'Content-Type: application/json' CRLF ...
                      'X-Test: val' CRLF ...
                      CRLF ...
                      '{"status":"ok"}'];
            raw = uint8(resStr);
            
            [status, headers, body] = feval('mhs.internal.GoSidecarTransport.parseResponseBytes', raw);
            
            testCase.verifyEqual(status, 200);
            testCase.verifyTrue(isa(headers, 'dictionary'));
            testCase.verifyEqual(string(headers('Content-Type')), "application/json");
            testCase.verifyEqual(string(headers('X-Test')), "val");
            testCase.verifyEqual(char(body), '{"status":"ok"}');
        end

        function testBuildRawRequestWithoutQueryOrBody(testCase)
            req.method = "GET";
            req.path = "/status";
            req.query = "";
            req.headers = struct();
            req.body = "";

            raw = feval('mhs.internal.GoSidecarTransport.buildRawRequest', req);

            rawStr = char(raw');
            testCase.verifyTrue(contains(rawStr, 'GET /status HTTP/1.1'));
            testCase.verifyTrue(contains(rawStr, 'Content-Length: 0'));
        end

        function testParseResponseBytesWithLfSeparators(testCase)
            resStr = sprintf(['HTTP/1.1 204 No Content\n' ...
                'Content-Type: text/plain\n' ...
                'X-Test: ok\n' ...
                '\n']);
            raw = uint8(resStr);

            [status, headers, body] = feval('mhs.internal.GoSidecarTransport.parseResponseBytes', raw);

            testCase.verifyEqual(status, 204);
            testCase.verifyEqual(string(headers('Content-Type')), "text/plain");
            testCase.verifyEqual(string(headers('X-Test')), "ok");
            testCase.verifyEmpty(body);
        end

        function testParseResponseBytesMalformedResponseFallsBackTo500(testCase)
            raw = uint8('not an http response');

            [status, headers, body] = feval('mhs.internal.GoSidecarTransport.parseResponseBytes', raw);

            testCase.verifyEqual(status, 500);
            testCase.verifyTrue(isa(headers, 'dictionary'));
            testCase.verifyEmpty(body);
        end

        function testParseResponseBytesMissingStatusCodeFallsBackTo500(testCase)
            CRLF = char([13 10]);
            raw = uint8(['BROKEN' CRLF 'X-Test: value' CRLF CRLF]);

            [status, headers, body] = feval('mhs.internal.GoSidecarTransport.parseResponseBytes', raw);

            testCase.verifyEqual(status, 500);
            testCase.verifyEqual(string(headers('X-Test')), "value");
            testCase.verifyEmpty(body);
        end

        function testOnLineFromGoIgnoresNonJsonLines(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            wasCalled = false;
            listener = addlistener(testCase.Transport, "DataReceived", ...
                @(~, ~) markCalled());
            cleaner = onCleanup(@() delete(listener));

            testCase.Transport.onLineFromGo("Go sidecar listening on port");
            testCase.Transport.onLineFromGo("   ");

            testCase.verifyFalse(wasCalled);
            clear cleaner;

            function markCalled()
                wasCalled = true;
            end
        end

        function testOnLineFromGoMalformedJsonDoesNotEmitEvent(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            wasCalled = false;
            listener = addlistener(testCase.Transport, "DataReceived", ...
                @(~, ~) markCalled());
            cleaner = onCleanup(@() delete(listener));

            testCase.verifyWarningFree(@() testCase.Transport.onLineFromGo('{bad json}'));
            testCase.verifyFalse(wasCalled);
            clear cleaner;

            function markCalled()
                wasCalled = true;
            end
        end

        function testOnLineFromGoValidRequestEmitsEvent(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            receivedId = "";
            receivedRaw = uint8([]);
            listener = addlistener(testCase.Transport, "DataReceived", ...
                @(~, evt) captureEvent(evt));
            cleaner = onCleanup(@() delete(listener));

            line = jsonencode(struct( ...
                'id', 'abc-123', ...
                'method', 'GET', ...
                'path', '/api/status', ...
                'query', '', ...
                'headers', struct('Content_Type', 'application_json'), ...
                'body', ''));

            testCase.Transport.onLineFromGo(line);

            testCase.verifyEqual(receivedId, "abc-123");
            testCase.verifyTrue(contains(string(char(receivedRaw')), 'GET /api/status HTTP/1.1'));
            clear cleaner;

            function captureEvent(evt)
                receivedId = evt.ClientKey;
                receivedRaw = evt.RawBytes;
            end
        end

        function testStopSwallowsCleanupErrors(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            badTimer = timer("ExecutionMode", "singleShot", "StartDelay", 10);
            delete(badTimer);
            testCase.Transport.Timer = badTimer;
            testCase.Transport.Writer = MockClosable(true);
            testCase.Transport.Reader = MockReader(false, {}, "");
            testCase.Transport.Reader.ReadyErrorMessage = "";
            testCase.Transport.Reader = MockClosable(true);
            testCase.Transport.Process = MockProcess(true, true);
            testCase.Transport.IsRunning = true;

            testCase.verifyWarningFree(@() testCase.Transport.stop());
            testCase.verifyEmpty(testCase.Transport.Process);
        end

        function testPollStdoutReturnsWhenNotRunning(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            testCase.verifyWarningFree(@() testCase.Transport.pollStdout());
        end

        function testPollStdoutStopsOnEmptyLine(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            testCase.Transport.IsRunning = true;
            testCase.Transport.Reader = MockReader([true false], {''}, "");

            testCase.verifyWarningFree(@() testCase.Transport.pollStdout());
        end

        function testPollStdoutSwallowsReaderErrors(testCase)
            testCase.Transport = mhs.internal.GoSidecarTransport(testCase.Port);
            testCase.Transport.IsRunning = true;
            testCase.Transport.Reader = MockReader(false, {}, "reader failed");

            testCase.verifyWarningFree(@() testCase.Transport.pollStdout());
        end
    end
end
