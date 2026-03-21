classdef TestHttpStatus < matlab.unittest.TestCase
    methods (Test)
        function testPhrases(testCase)
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(200), "OK");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(201), "Created");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(404), "Not Found");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(500), "Internal Server Error");
        end

        function testKnownCodes(testCase)
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(200), "OK");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(201), "Created");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(202), "Accepted");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(204), "No Content");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(400), "Bad Request");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(401), "Unauthorized");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(403), "Forbidden");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(404), "Not Found");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(405), "Method Not Allowed");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(500), "Internal Server Error");
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(501), "Not Implemented");
        end

        function testUnknownCode(testCase)
            testCase.verifyEqual(mhs.HttpStatus.getPhrase(999), "Unknown");
        end

        function testConstants(testCase)
            testCase.verifyEqual(mhs.HttpStatus.OK, 200);
            testCase.verifyEqual(mhs.HttpStatus.NotFound, 404);
            testCase.verifyEqual(mhs.HttpStatus.InternalServerError, 500);
        end
    end
end
