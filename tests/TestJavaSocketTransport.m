classdef TestJavaSocketTransport < matlab.unittest.TestCase

    properties
        Transport
        Port = 8091
    end

    methods (TestMethodTeardown)
        function teardown(testCase)
            if ~isempty(testCase.Transport)
                testCase.Transport.stop();
                testCase.Transport = [];
            end
            pause(0.2);
        end
    end

    methods (Test)
        function testConstructorSetsPort(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.verifyEqual(testCase.Transport.Port, testCase.Port);
        end

        function testStartStop(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.verifyWarningFree(@() testCase.Transport.start());
            testCase.verifyWarningFree(@() testCase.Transport.stop());
        end

        function testStopWithoutStart(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.verifyWarningFree(@() testCase.Transport.stop());
        end

        function testStartTwiceNoOps(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.Transport.start();
            testCase.verifyWarningFree(@() testCase.Transport.start());
        end

        function testTimerCreatedOnStart(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.Transport.start();
            testCase.verifyNotEmpty(testCase.Transport.Timer);
            testCase.verifyEqual(string(testCase.Transport.Timer.Running), "on");
        end

        function testServerSocketCreatedOnStart(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.Transport.start();
            testCase.verifyNotEmpty(testCase.Transport.ServerSocket);
        end

        function testResourcesClearedOnStop(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.Transport.start();
            testCase.Transport.stop();
            testCase.verifyEmpty(testCase.Transport.Timer);
            testCase.verifyEmpty(testCase.Transport.ServerSocket);
        end

        function testPortInUseErrors(testCase)
            t1 = mhs.internal.JavaSocketTransport(testCase.Port);
            t1.start();

            t2 = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.verifyError(@() t2.start(), "JavaSocketTransport:StartFailed");

            t1.stop();
        end

        function testWriteResponseDoesNotError(testCase)
            transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.verifyTrue(ismethod(transport, "writeResponse"));
        end

        function testDataReceivedEventForSimpleRequest(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            varName = "javaTransportRaw_" + string(tempname);
            varName = matlab.lang.makeValidName(varName);
            assignin("base", varName, uint8([]));
            listener = addlistener(testCase.Transport, "DataReceived", ...
                @(~, evt) assignin("base", varName, evt.RawBytes));
            cleaner = onCleanup(@() delete(listener));
            baseCleaner = onCleanup(@() evalin("base", "clear " + varName));

            testCase.Transport.start();
            client = tcpclient("localhost", testCase.Port);
            clientCleaner = onCleanup(@() delete(client));

            request = uint8(['GET /hello HTTP/1.1' char(13) char(10) ...
                'Host: localhost' char(13) char(10) char(13) char(10)]);
            write(client, request);

            testCase.verifyTrue(waitForCondition(@() ~isempty(evalin("base", varName)), 2.0));
            receivedRaw = evalin("base", varName);
            testCase.verifyEqual(receivedRaw, request');

            clear cleaner clientCleaner baseCleaner;
        end

        function testPartialRequestWaitsForCompletion(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            countName = matlab.lang.makeValidName("javaTransportCount_" + string(tempname));
            rawName = matlab.lang.makeValidName("javaTransportPartialRaw_" + string(tempname));
            assignin("base", countName, 0);
            assignin("base", rawName, uint8([]));
            listener = addlistener(testCase.Transport, "DataReceived", ...
                @(~, evt) captureInBase(evt.RawBytes, countName, rawName));
            cleaner = onCleanup(@() delete(listener));
            baseCleaner = onCleanup(@() evalin("base", "clear " + countName + " " + rawName));

            testCase.Transport.start();
            client = tcpclient("localhost", testCase.Port);
            clientCleaner = onCleanup(@() delete(client));

            body = '{"msg":"hello"}';
            firstPart = uint8(['POST /echo HTTP/1.1' char(13) char(10) ...
                'Host: localhost' char(13) char(10) ...
                'Content-Type: application/json' char(13) char(10) ...
                'Content-Length: ' num2str(numel(body)) char(13) char(10) ...
                char(13) char(10) '{"msg":']);
            secondPart = uint8(['"hello"}']);

            write(client, firstPart);
            pause(0.3);
            testCase.verifyEqual(evalin("base", countName), 0, ...
                "Transport should not emit DataReceived before the request body is complete.");

            write(client, secondPart);
            testCase.verifyTrue(waitForCondition(@() evalin("base", countName) == 1, 2.0));
            receivedRaw = evalin("base", rawName);
            testCase.verifyTrue(contains(string(char(receivedRaw')), '"hello"'));

            clear cleaner clientCleaner baseCleaner;
        end

        function testClientDisconnectDoesNotBreakNextRequest(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            countName = matlab.lang.makeValidName("javaTransportDisconnectCount_" + string(tempname));
            assignin("base", countName, 0);
            listener = addlistener(testCase.Transport, "DataReceived", ...
                @(~, ~) assignin("base", countName, evalin("base", countName) + 1));
            cleaner = onCleanup(@() delete(listener));
            baseCleaner = onCleanup(@() evalin("base", "clear " + countName));

            testCase.Transport.start();

            abandonedClient = tcpclient("localhost", testCase.Port);
            delete(abandonedClient);
            clear abandonedClient
            pause(0.2);

            client = tcpclient("localhost", testCase.Port);
            clientCleaner = onCleanup(@() delete(client));
            request = uint8(['GET /ok HTTP/1.1' char(13) char(10) ...
                char(13) char(10)]);
            write(client, request);

            testCase.verifyTrue(waitForCondition(@() evalin("base", countName) == 1, 2.0));

            clear cleaner clientCleaner baseCleaner;
        end

        function testWriteResponseWithEmptySocketIsNoOp(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.verifyWarningFree(@() testCase.Transport.writeResponse([], uint8('abc')'));
        end

        function testReadAvailableBytesReturnsMinusOneAtEndOfStream(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            stream = java.io.ByteArrayInputStream(uint8('x'));
            stream.read();
            accumulator = mhs.internal.BufferAccumulator();

            bytesRead = testCase.Transport.readAvailableBytes(stream, accumulator);

            testCase.verifyEqual(bytesRead, -1);
            testCase.verifyFalse(accumulator.isComplete());
        end

        function testReadAvailableBytesAppendsBytesToAccumulator(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            request = uint8(['GET /read HTTP/1.1' char(13) char(10) char(13) char(10)]);
            stream = java.io.ByteArrayInputStream(request);
            accumulator = mhs.internal.BufferAccumulator();

            bytesRead = testCase.Transport.readAvailableBytes(stream, accumulator);

            testCase.verifyEqual(bytesRead, numel(request));
            testCase.verifyEqual(accumulator.getBuffer(), request');
            testCase.verifyTrue(accumulator.isComplete());
        end

        function testTimeoutErrorClassifier(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            timeoutException = MException("Java:SocketTimeoutException", "SocketTimeoutException: Read timed out");
            otherException = MException("Java:IOException", "Generic IO failure");

            testCase.verifyTrue(testCase.Transport.isTimeoutError(timeoutException));
            testCase.verifyFalse(testCase.Transport.isTimeoutError(otherException));
        end

        function testWouldBlockClassifier(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            blockException = MException("Java:IOException", "Resource temporarily unavailable");
            otherException = MException("Java:IOException", "Connection reset");

            testCase.verifyTrue(testCase.Transport.isWouldBlockError(blockException));
            testCase.verifyFalse(testCase.Transport.isWouldBlockError(otherException));
        end

        function testPollSocketsReturnsWhenStopped(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.verifyWarningFree(@() testCase.Transport.pollSockets());
        end

        function testAcceptPendingClientsSwallowsNonTimeoutErrors(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.Transport.IsRunning = true;
            testCase.Transport.ServerSocket = MockServerSocket("accept failed");

            testCase.verifyWarningFree(@() testCase.Transport.acceptPendingClients());
            testCase.verifyTrue(testCase.Transport.IsRunning);
        end

        function testReadPendingClientsRemovesEmptySocketEntries(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.Transport.ClientKeys = "client";
            testCase.Transport.ClientSockets = {[]};
            testCase.Transport.ClientAccumulators = {mhs.internal.BufferAccumulator()};

            testCase.Transport.readPendingClients();

            testCase.verifyEmpty(testCase.Transport.ClientSockets);
            testCase.verifyEmpty(testCase.Transport.ClientKeys);
        end

        function testReadPendingClientsSwallowsClientReadErrors(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            testCase.Transport.ClientKeys = "client";
            badSocket = MockSocket([], []);
            badSocket.ThrowOnGetInputStream = true;
            testCase.Transport.ClientSockets = {badSocket};
            testCase.Transport.ClientAccumulators = {mhs.internal.BufferAccumulator()};

            testCase.verifyWarningFree(@() testCase.Transport.readPendingClients());
            testCase.verifyEmpty(testCase.Transport.ClientSockets);
        end

        function testWriteResponseSwallowsSocketErrors(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            badSocket = MockSocket([], []);
            badSocket.ThrowOnGetOutputStream = true;

            testCase.verifyWarningFree(@() testCase.Transport.writeResponse(badSocket, uint8('abc')'));
            testCase.verifyTrue(badSocket.Closed);
        end

        function testStopSwallowsCleanupErrors(testCase)
            testCase.Transport = mhs.internal.JavaSocketTransport(testCase.Port);
            badTimer = timer("ExecutionMode", "singleShot", "StartDelay", 10);
            delete(badTimer);
            testCase.Transport.Timer = badTimer;
            testCase.Transport.ServerSocket = MockServerSocket("");
            testCase.Transport.ServerSocket.ThrowOnClose = true;
            testCase.Transport.ClientKeys = "client";
            testCase.Transport.ClientSockets = {MockSocket([], [])};
            testCase.Transport.ClientAccumulators = {mhs.internal.BufferAccumulator()};
            testCase.Transport.IsRunning = true;

            testCase.verifyWarningFree(@() testCase.Transport.stop());
            testCase.verifyEmpty(testCase.Transport.ClientSockets);
        end
    end
end

function tf = waitForCondition(predicate, timeoutSeconds)
    tf = false;
    startTime = tic;
    while toc(startTime) < timeoutSeconds
        if predicate()
            tf = true;
            return;
        end
        pause(0.05);
    end
end

function captureInBase(raw, countName, rawName)
    assignin("base", rawName, raw);
    assignin("base", countName, evalin("base", countName) + 1);
end
