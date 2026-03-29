# matlab-http-server

A zero-dependency HTTP server framework for MATLAB, inspired by Flask. Build REST APIs and serve local or team-facing web applications entirely in MATLAB. The core goal is base-MATLAB HTTP serving with first-class static file serving, usable both from an open MATLAB session and in headless deployments.

[![MATLAB](https://img.shields.io/badge/MATLAB-R2022b%2B-blue)](https://www.mathworks.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/PVDecker1/matlab-http-server/actions/workflows/ci.yml/badge.svg)](https://github.com/PVDecker1/matlab-http-server/actions/workflows/ci.yml)
[![codecov](https://codecov.io/github/PVDecker1/matlab-http-server/graph/badge.svg?token=ZIFZET45CK)](https://codecov.io/github/PVDecker1/matlab-http-server)

---

## Documentation

- [Getting Started](toolbox/doc/getting-started.md)
- [Controller Testing With `mhs.ApiTestCase`](toolbox/doc/api-test-case.md)
- [Routing](toolbox/doc/routing.md)
- [Request & Response](toolbox/doc/request-response.md)
- [Static File Serving](toolbox/doc/static-file-serving.md)
- [Deployment](toolbox/doc/deployment.md)
- [Contributing](toolbox/doc/contributing.md)

---

## What It Is

`matlab-http-server` lets you define API endpoints by subclassing `mhs.ApiController` and implementing a `registerRoutes` method. A built-in HTTP server handles the socket layer, parses HTTP/1.1 requests, serves static assets, and dispatches to your registered handlers.

### Example App

The Signal Analyzer example shows the kind of same-origin frontend + MATLAB backend workflow this project is meant to support.

![Signal Analyzer demo](assets/SignalAnalyzer.gif)

```matlab
classdef MyController < mhs.ApiController
    methods
        function res = getHello(obj, req, res)
            res.json(struct('message', 'Hello from MATLAB'));
        end

        function res = postEcho(obj, req, res)
            res.json(req.Body);
        end
    end

    methods (Access = protected)
        function registerRoutes(obj)
            obj.get('/api/hello', @obj.getHello);
            obj.post('/api/echo', @obj.postEcho);
        end
    end
end
```

Start the server:

```matlab
server = MatlabHttpServer(8080);
server.register(MyController());
server.start();
```

Test it from your terminal:

```bash
# General / Linux / macOS / PowerShell (recommended)
curl http://localhost:8080/api/hello
curl http://localhost:8080/api/echo -d '{"msg":"hi"}' -H "Content-Type: application/json"

# Windows CMD (requires escaping)
curl http://localhost:8080/api/echo -d "{\"msg\":\"hi\"}" -H "Content-Type: application/json"
```

No config files, no external dependencies for core functionality, and no additional MATLAB products required by the framework itself beyond an appropriate MATLAB license.

---

## Project Goals

- Run the core server in base MATLAB without Instrument Control Toolbox.
- Avoid a Parallel Computing Toolbox dependency in the core server layer.
- Support both interactive use in a running MATLAB session and headless/server deployment.
- Support both REST APIs and static file serving as first-class features.
- Keep the Go sidecar transport optional, not required for basic usage.

---

## Getting Started

Start with the markdown guide at [`toolbox/doc/getting-started.md`](toolbox/doc/getting-started.md).
An interactive plain-text Live Script source is also available at [`toolbox/doc/GettingStarted.m`](toolbox/doc/GettingStarted.m).

### Installation

**Option 1 - MATLAB Toolbox (recommended):**
Download the latest `.mltbx` from [Releases](https://github.com/PVDecker1/matlab-http-server/releases) and double-click to install.

**Option 2 - Clone and add to path:**
```matlab
git clone https://github.com/PVDecker1/matlab-http-server.git
addpath(fullfile(pwd, 'matlab-http-server', 'toolbox'))
```

### Requirements

- MATLAB R2022b or later
- No toolboxes required for core server functionality
- Go binary (included precompiled in `toolbox/bin/`) required only when using the Go transport

---

## Transport Selection

`matlab-http-server` is designed around transport abstraction. The default path should work in base MATLAB, while the Go sidecar remains available as an explicit opt-in for automated or long-running MATLAB workflows.

```matlab
% Default transport
server = MatlabHttpServer(8080);

% Go sidecar transport
server = MatlabHttpServer(8080, Transport="go");
```

### Transport Intent

- The default Java transport currently runs as an in-process Java socket server coordinated by a MATLAB timer loop.
- The project no longer treats `tcpserver` as a core dependency path because it introduces an Instrument Control Toolbox dependency.
- The core server layer should not require Parallel Computing Toolbox.
- Async compute patterns inside user handlers may still use Parallel Computing Toolbox when the user opts into that separately.

---

## Defining Routes

Override the abstract `registerRoutes` method in your controller subclass and use the provided registration helpers to map HTTP verbs and paths to handler methods. MATLAB throws a clear error at instantiation time if `registerRoutes` is not implemented.

```matlab
methods (Access = protected)
    function registerRoutes(obj)
        obj.get('/api/users',        @obj.getUsers);
        obj.post('/api/users',       @obj.createUser);
        obj.get('/api/users/:id',    @obj.getUserById);
        obj.put('/api/users/:id',    @obj.updateUser);
        obj.delete('/api/users/:id', @obj.deleteUser);
    end
end
```

### Available Registration Helpers

| Method | HTTP Verb |
|---|---|
| `obj.get(path, handler)` | GET |
| `obj.post(path, handler)` | POST |
| `obj.put(path, handler)` | PUT |
| `obj.delete(path, handler)` | DELETE |
| `obj.patch(path, handler)` | PATCH |

### Path Parameters

Use `:param` syntax to capture dynamic path segments. Parameters are available via `req.PathParams`:

```matlab
classdef UserController < mhs.ApiController
    methods (Access = protected)
        function registerRoutes(obj)
            obj.get('/api/users/:id', @obj.getUserById);
        end
    end

    methods
        function res = getUserById(obj, req, res)
            id = req.PathParams("id");
            res.json(struct('id', id));
        end
    end
end
```

### Handler Signature

All handler methods must declare `res` as both input and output:

```matlab
function res = myHandler(obj, req, res)
    res.json(struct('ok', true));
end
```

---

## Request And Response

Every handler receives an `HttpRequest` and `HttpResponse` object.

**HttpRequest properties:** `Method`, `Path`, `Headers`, `Body`, `QueryParams`

**HttpResponse methods:**
```matlab
res.json(data)                    % 200 + JSON body
res.status(201).json(data)        % custom status + JSON
res.send(text)                    % plain text response
res.status(404).send('Not found') % plain text with status
```

---

## Static File Serving

Static file serving is part of the framework's intended feature set. `matlab-http-server` can serve HTML, CSS, JS, images, and other assets from a local directory. Static handlers are checked before the API router, allowing a frontend and API to share one MATLAB process.

```matlab
server = MatlabHttpServer(8080);
server.serveStatic("public/");
server.start();
```

Mixed API + static example:

```matlab
server = MatlabHttpServer(8080);
server.register(MyController()); % handles /api/...
server.serveStatic("public/");   % serves everything else; falls through to router if no file matches
server.start();
```

See [`toolbox/examples/StaticSiteExample/`](toolbox/examples/StaticSiteExample/) for a runnable demo and [Static File Serving Documentation](toolbox/doc/static-file-serving.md) for details.

---

## Multiple Controllers

```matlab
server = MatlabHttpServer(8080);
server.register(UserController());
server.register(AdminController());
server.start();
```

---

## CORS

CORS headers are handled automatically on every response. `OPTIONS` preflight requests are resolved at the server layer before reaching your controllers. Restrict the allowed origin if needed:

```matlab
server = MatlabHttpServer(8080, AllowedOrigin="http://localhost:5173");
```

---

## Deployment Models

`matlab-http-server` supports two primary deployment configurations.

### Local - Single User

Run directly in an open MATLAB session on your local machine. Pair with a React/Vite dev server on a different port for a full local stack.

### Centralized - Small Team

Run on a shared machine in a headless or service-style deployment. Put Nginx or Caddy in front for TLS and routing while MATLAB handles application logic.

```text
Caddy (TLS, :443) -> matlab-http-server (:8080, localhost only)
```

### Licensing Note

This project is intended to operate within the scope of an existing MATLAB license and does not extend MATLAB access beyond licensed users.

Single-user local use and shared team deployments may have different MathWorks licensing requirements. If you plan to host a MATLAB-backed internal tool on a shared machine, verify that your organization's MATLAB license permits that deployment model and has sufficient named users or concurrent seats, as applicable.

See the official MathWorks licensing documentation for details:

- [Individual License Administration](https://www.mathworks.com/help/install/license/individual-license-administration.html)
- [Administer Network Licenses](https://www.mathworks.com/help/install/administer-network-licenses.html)
- [Concurrent License Administration](https://www.mathworks.com/help/install/license/concurrent-licenses.html)
- [Network Named User License Administration](https://www.mathworks.com/help/install/license/key-administrative-tasks.html)

---

## Async Handlers

For compute-heavy handlers, keep the async pattern outside the core server contract. User-defined handlers may opt into `parfeval` or other asynchronous approaches when the deployment environment supports them.

```matlab
methods (Access = protected)
    function registerRoutes(obj)
        obj.post('/api/simulate',   @obj.startSimulation);
        obj.get('/api/jobs/status', @obj.getJobStatus);
    end
end

methods
    function res = startSimulation(obj, req, res)
        f = parfeval(backgroundPool, @runSimulation, 1, req.Body);
        jobId = obj.registerFuture(f);
        res.status(202).json(struct('jobId', jobId));
    end

    function res = getJobStatus(obj, req, res)
        result = obj.pollFuture(req.QueryParams("id"));
        res.json(result);
    end
end
```

This pattern is optional and is not part of the core server's dependency contract.

---

## Known Limitations

These constraints are intentional. `matlab-http-server` is a lightweight HTTP framework for local tools, internal apps, and small-team services, not a general-purpose production web server.

| Limitation | Notes |
|---|---|
| Single-threaded request handling | Requests are sequential unless a transport implementation explicitly offloads accept/work handling. |
| HTTP/1.1 happy path only | No chunked encoding, multipart, or HTTP/2. |
| No TLS | Use Nginx or Caddy as a reverse proxy. |
| No built-in authentication | Implement in controller `preDispatch` or a proxy layer. |
| No keep-alive | Connections close after each response. |
| Requires R2022b+ | New code relies on `dictionary` support. |

---

## Project Structure

Follows [MathWorks Toolbox Best Practices](https://github.com/mathworks/toolboxdesign) and [MATLAB Coding Guidelines](https://github.com/mathworks/MATLAB-Coding-Guidelines).

```text
matlab-http-server/
|   README.md
|   LICENSE
|   matlab-http-server.prj
|   buildfile.m
|   .gitignore
|   .gitattributes
+---assets/
+---toolbox/
|   |   MatlabHttpServer.m
|   +---+mhs/
|   |       ApiController.m
|   |       HttpRequest.m
|   |       HttpResponse.m
|   |       Router.m
|   |       HttpStatus.m
|   |       StaticFileHandler.m
|   +---+mhs/+internal/
|   |       BufferAccumulator.m
|   |       HttpParser.m
|   |       CorsHandler.m
|   +---doc/
|   |       contributing.md
|   |       deployment.md
|   |       getting-started.md
|   |       request-response.md
|   |       routing.md
|   |       static-file-serving.md
|   +---examples/
|   |   +---BasicExample/
|   |   +---MultiControllerExample/
|   |   +---SignalAnalyzer/
|   |   +---StaticSiteExample/
+---tests/
```

---

## Contributing

Tests are required for all new functionality. Run tests before submitting:

```matlab
buildtool test
buildtool ci
```

See [AGENTS.md](AGENTS.md) for architecture details, coding conventions, and agent-specific guidance.

For controller-level tests, prefer [`mhs.ApiTestCase`](toolbox/+mhs/ApiTestCase.m) so you can dispatch requests through a fresh router without opening live sockets.

---

## Inspiration

`matlab-http-server` fills a gap in the MATLAB ecosystem. MathWorks provides strong HTTP client tooling, but lightweight server-side HTTP remains awkward without additional products or external infrastructure. This project aims to provide a portable framework for MATLAB-based web services while keeping the core runtime dependency story simple.

The routing pattern is inspired by Flask and draws on the same metaclass inspection technique used internally by `matlab.unittest` for test discovery.

---

## License

MIT (c) 2026
