classdef TestBufferAccumulator < matlab.unittest.TestCase
    % TestBufferAccumulator Unit tests for BufferAccumulator class

    methods (Test)
        function testSingleAddComplete(testCase)
            ba = mhs.internal.BufferAccumulator();
            raw = ['GET / HTTP/1.1' char(13) char(10) char(13) char(10)];
            ba.add(uint8(raw));
            testCase.verifyTrue(ba.isComplete());
        end

        function testHeaderInChunks(testCase)
            ba = mhs.internal.BufferAccumulator();
            ba.add(uint8(['GET / HTTP/1.1' char(13)]));
            testCase.verifyFalse(ba.isComplete());
            ba.add(uint8([char(10) char(13) char(10)]));
            testCase.verifyTrue(ba.isComplete());
        end

        function testBodyInChunks(testCase)
            ba = mhs.internal.BufferAccumulator();
            header = ['POST / HTTP/1.1' char(13) char(10) ...
                      'Content-Length: 10' char(13) char(10) ...
                      char(13) char(10)];
            ba.add(uint8(header));
            testCase.verifyFalse(ba.isComplete());
            
            ba.add(uint8('12345'));
            testCase.verifyFalse(ba.isComplete());
            
            ba.add(uint8('67890'));
            testCase.verifyTrue(ba.isComplete());
        end

        function testNoBodyCompleteAfterHeaders(testCase)
            ba = mhs.internal.BufferAccumulator();
            % Content-Length absent
            raw = ['GET / HTTP/1.1' char(13) char(10) ...
                   'Host: localhost' char(13) char(10) ...
                   char(13) char(10)];
            ba.add(uint8(raw));
            testCase.verifyTrue(ba.isComplete());
        end

        function testContentLengthZero(testCase)
            ba = mhs.internal.BufferAccumulator();
            raw = ['POST / HTTP/1.1' char(13) char(10) ...
                   'Content-Length: 0' char(13) char(10) ...
                   char(13) char(10)];
            ba.add(uint8(raw));
            testCase.verifyTrue(ba.isComplete());
        end

        function testResetAllowsReuse(testCase)
            ba = mhs.internal.BufferAccumulator();
            ba.add(uint8(['GET / HTTP/1.1' char(13) char(10) char(13) char(10)]));
            testCase.verifyTrue(ba.isComplete());
            
            ba.reset();
            testCase.verifyFalse(ba.isComplete());
            testCase.verifyEmpty(ba.getBuffer());
            
            ba.add(uint8(['GET /again HTTP/1.1' char(13) char(10) char(13) char(10)]));
            testCase.verifyTrue(ba.isComplete());
            testCase.verifyTrue(contains(string(char(ba.getBuffer()')), "/again"));
        end
    end
end
