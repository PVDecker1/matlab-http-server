# Getting Started with matlab-http-server

This guide will walk you through installing the framework and building your first REST API in MATLAB.

## Installation

You have two primary ways to install `matlab-http-server`:

### Option 1: MATLAB Toolbox (.mltbx) - Recommended
1. Download the latest `.mltbx` file from the [Releases](https://github.com/PVDecker1/matlab-http-server/releases) page.
2. Double-click the file in MATLAB's Current Folder browser.
3. Follow the installation prompts. This adds the framework to your MATLAB path permanently.

### Option 2: Clone and Manual Path
1. Clone the repository: `git clone https://github.com/PVDecker1/matlab-http-server.git`
2. Add the `toolbox` folder to your path: `addpath('C:\path\to\matlab-http-server\toolbox')`

## Requirements

- **MATLAB R2022b or later**: The framework relies heavily on the `dictionary` type introduced in R2022b.
- **Instrument Control Toolbox**: Required for core networking functionality via `tcpserver`.
- **Parallel Computing Toolbox (Optional)**: Required if you want to use `parfeval` for non-blocking asynchronous handlers.

## Your First Controller

In `matlab-http-server`, you define API endpoints by subclassing `mhs.ApiController`. Create a file named `HelloController.m`:

```matlab
classdef HelloController < mhs.ApiController
    methods (Access = protected)
        function registerRoutes(obj)
            % Map URL paths to handler methods
            obj.get('/hello', @obj.sayHello);
            obj.post('/echo', @obj.echoData);
        end
    end

    methods
        function res = sayHello(~, ~, res)
            % res = sayHello(obj, req, res)
            % res is the response object you modify and return
            res.json(struct('message', 'Hello, MATLAB!'));
        end

        function res = echoData(~, req, res)
            % Access the request body via req.Body
            res.json(req.Body);
        end
    end
end
```

## Running the Server

Once your controller is defined, start the server and register an instance of it. Create a script named `startServer.m`:

```matlab
% Create the server on port 8080
server = MatlabHttpServer(8080);

% Register your controller
server.register(HelloController());

% Start listening for connections
server.start();

disp('Server is running at http://localhost:8080');
```

Run this script in MATLAB. You should see a message confirming the server has started.

## Testing Your API

Use `curl` or any API client (like Postman or Insomnia) to test your endpoints.

### GET Request
```bash
curl http://localhost:8080/hello
```
**Response:** `{"message":"Hello, MATLAB!"}`

### POST Request
**PowerShell / Linux / macOS:**
```bash
curl http://localhost:8080/echo -d '{"name":"Austin"}' -H "Content-Type: application/json"
```

**Windows CMD (Requires escaped quotes):**
```cmd
curl http://localhost:8080/echo -d "{\"name\":\"Austin\"}" -H "Content-Type: application/json"
```
**Response:** `{"name":"Austin"}`

## Exploring Examples

The framework includes several examples to demonstrate more advanced features:

- **BasicExample**: (`toolbox/examples/BasicExample/`) Shows basic routing, POST handling, and path parameters.
- **MultiControllerExample**: (`toolbox/examples/MultiControllerExample/`) Demonstrates how to split a large API into multiple controller classes.
- **StaticSiteExample**: (`toolbox/examples/StaticSiteExample/`) Shows how to serve a frontend (HTML/CSS) alongside your API.
- **SignalAnalyzer**: (`toolbox/examples/SignalAnalyzer/`) A complex example featuring a React frontend that interacts with MATLAB computational code.

To run an example, navigate to its folder in MATLAB and run the `run...` script.

## Next Steps

- **[Routing Guide](routing.md)**: Learn about path parameters, specific route ordering, and supported HTTP verbs.
- **[Request & Response Reference](request-response.md)**: Detailed documentation of the `HttpRequest` and `HttpResponse` classes.
- **[Static File Serving](static-file-serving.md)**: How to host your frontend assets directly from the server.
