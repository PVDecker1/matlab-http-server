classdef HttpStatus
    % HttpStatus Named HTTP status code constants

    properties (Constant)
        OK = 200
        Created = 201
        Accepted = 202
        NoContent = 204

        BadRequest = 400
        Unauthorized = 401
        Forbidden = 403
        NotFound = 404
        MethodNotAllowed = 405

        InternalServerError = 500
        NotImplemented = 501
    end

    methods (Static)
        function phrase = getPhrase(code)
            % GETPHRASE Returns the standard HTTP reason phrase for a status code
            arguments
                code (1,1) double
            end

            switch code
                case 200
                    phrase = "OK";
                case 201
                    phrase = "Created";
                case 202
                    phrase = "Accepted";
                case 204
                    phrase = "No Content";
                case 400
                    phrase = "Bad Request";
                case 401
                    phrase = "Unauthorized";
                case 403
                    phrase = "Forbidden";
                case 404
                    phrase = "Not Found";
                case 405
                    phrase = "Method Not Allowed";
                case 500
                    phrase = "Internal Server Error";
                case 501
                    phrase = "Not Implemented";
                otherwise
                    phrase = "Unknown";
            end
        end
    end
end