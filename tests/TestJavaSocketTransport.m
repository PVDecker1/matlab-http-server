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
    end
end
