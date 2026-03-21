# matlab-http-server

A zero-dependency HTTP server framework for MATLAB, inspired by Flask. Build REST APIs and serve local or team-facing web applications — entirely in MATLAB, no external toolboxes required beyond `tcpserver` (R2021a+) and `dictionary` (R2022b+).

[![MATLAB](https://img.shields.io/badge/MATLAB-R2022b%2B-blue)](https://www.mathworks.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![CI](https://github.com/PVDecker1/matlab-http-server/actions/workflows/ci.yml/badge.svg)](https://github.com/PVDecker1/matlab-http-server/actions/workflows/ci.yml)
[![codecov](https://codecov.io/gh/PVDecker1/matlab-http-server/graph/badge.svg?token=)](https://codecov.io/gh/PVDecker1/matlab-http-server)

---

## What It Is

`matlab-http-server` lets you define API endpoints by subclassing `mhs.ApiController` and implementing a `registerRoutes` method. A built-in HTTP server built on `tcpserver` handles the socket layer, parses HTTP/1.1 requests, and dispatches to your registered handlers.

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
# General / Linux / macOS / PowerShell (Recommended)
curl http://localhost:8080/api/hello
curl http://localhost:8080/api/echo -d '{"msg":"hi"}' -H "Content-Type: application/json"

# Windows CMD (Not recommended, requires escaping)
curl http://localhost:8080/api/echo -d "{\"msg\":\"hi\"}" -H "Content-Type: application/json"
```

No config files, no external dependencies, no MATLAB Production Server license.

---

## Getting Started

See [`toolbox/doc/GettingStarted.mlx`](toolbox/doc/GettingStarted.mlx) for an interactive walkthrough including a working example with a React frontend.

### Installation

**Option 1 — MATLAB Toolbox (recommended):**
Download the latest `.mltbx` from [Releases](https://github.com/PVDecker1/matlab-http-server/releases) and double-click to install.

**Option 2 — Clone and add to path:**
```matlab
git clone https://github.com/PVDecker1/matlab-http-server.git
addpath(fullfile(pwd, 'matlab-http-server', 'toolbox'))
```

### Requirements

- MATLAB R2022b or later (`dictionary` introduced in R2022b)
- No additional toolboxes required for core functionality
- Parallel Computing Toolbox — optional, for async handler pattern
- MATLAB Compiler — optional, for MCR/Docker deployment

### Available Examples

- **BasicExample**: Minimal controller showing basic routing and JSON echo. Run with `runBasicExample.m`.
- **MultiControllerExample**: Demonstrates registering multiple controllers on one server. Run with `runMultiControllerExample.m`.
- **SignalAnalyzer**: A modern React-based dashboard that generates and analyzes signals using MATLAB's computational engine. Run with `runSignalAnalyzer.m`.

![Signal Analyzer](images/signal-analyzer.png)
<!-- Placeholder: Add real screenshot of Signal Analyzer UI above -->

---

## Defining Routes

Override the abstract `registerRoutes` method in your controller subclass and use the provided registration helpers to map HTTP verbs and paths to handler methods. MATLAB will throw a clear error at instantiation time if `registerRoutes` is not implemented.

```matlab
methods (Access = protected)
    function registerRoutes(obj)
        obj.get('/api/users',        @obj.getUsers);
        obj.post('/api/users',        @obj.createUser);
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
            id = req.PathParams('id');
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

## Request & Response

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

## Multiple Controllers

```matlab
server = MatlabHttpServer(8080);
server.register(UserController());    % handles /api/user/...
server.register(AdminController());   % handles /api/admin/...
server.start();
```

---

## CORS

CORS headers are handled automatically on every response. `OPTIONS` preflight requests are resolved at the server layer before reaching your controllers. Restrict the allowed origin if needed:

```matlab
server = MatlabHttpServer(8080, 'AllowedOrigin', 'http://localhost:5173');
```

---

## Static File Serving

`matlab-http-server` can serve static assets (HTML, CSS, JS, images) from a local directory. Static handlers are checked before the API router, allowing you to host a frontend and an API from the same server.

```matlab
server = MatlabHttpServer(8080);
server.serveStatic("public/");
server.start();
```

Mixed API + static example:

```matlab
server = MatlabHttpServer(8080);
server.serveStatic("public/");
server.register(MyController()); % handles /api/...
server.start();
```

See [`toolbox/examples/StaticSiteExample/`](toolbox/examples/StaticSiteExample/) for a runnable demo. For more advanced configurations, see the [Static File Serving Documentation](docs/static-file-serving.md).

---

## Deployment Models

The same codebase supports several deployment configurations.

### Local — Single User
Run directly in MATLAB on your local machine. Pair with a React/Vite dev server on a different port for a full local stack. Ideal for personal tools and dashboards.

### Centralized — Small Team
Run on a shared machine. Put Nginx or Caddy in front for TLS and routing. MATLAB handles computation, the proxy handles infrastructure.

```
Caddy (TLS, :443) → matlab-http-server (:8080, localhost only)
```

### Docker — Full MATLAB
Package MATLAB, your controllers, and a reverse proxy into a Docker Compose stack. Requires a valid MATLAB license in the container.

### Docker — MATLAB Runtime (MCR)
Compile with `mcc` and base your image on the free MATLAB Runtime. No per-host license required. Enables autoscaling in K8s environments.

> ⚠️ **MCR Compatibility:** Metaclass inspection is believed to survive `mcc` compilation but has not been fully validated across all MATLAB versions. CI validation is in progress. See [Known Limitations](#known-limitations).

### Horizontal Scaling (K8s / Autoscaler)
Deploy multiple MCR-based containers behind a load balancer. Each pod is single-threaded but you scale by multiplying pods. Best suited for stateless handlers. Sticky sessions required if handlers share MATLAB object state across requests.

---

## Async Handlers

For compute-heavy handlers that would block the server, use `parfeval` with a polling pattern:

```matlab
methods (Access = protected)
    function registerRoutes(obj)
        obj.post('/api/simulate',     @obj.startSimulation);
        obj.get('/api/jobs/status',   @obj.getJobStatus);
    end
end

methods
    function res = startSimulation(obj, req, res)
        f = parfeval(backgroundPool, @runSimulation, 1, req.Body);
        jobId = obj.registerFuture(f);
        res.status(202).json(struct('jobId', jobId));
    end

    function res = getJobStatus(obj, req, res)
        result = obj.pollFuture(req.QueryParams('id'));
        res.json(result);
    end
end
```

> Requires Parallel Computing Toolbox. Not available under MCR.

---

## Known Limitations

These constraints are intentional and documented. `matlab-http-server` is a local and small-team tooling framework, not a general-purpose production web server.

| Limitation | Notes |
|---|---|
| Single-threaded request handling | Requests are sequential. Use async handler pattern for long jobs. |
| HTTP/1.1 happy path only | No chunked encoding, multipart, or HTTP/2. |
| No TLS | Use Nginx or Caddy as a reverse proxy. |
| No built-in authentication | Implement in controller `preDispatch` or proxy layer. |
| No keep-alive | Connections close after each response. |
| Requires R2021a+ | `tcpserver` introduced in R2021a. |
| MCR metaclass compatibility unverified | CI validation in progress. See issue #1. |
| PCT unavailable under MCR | `parfeval`/`backgroundPool` require full MATLAB. |
| Windows execution policy | Compiled executables may require IT whitelisting on managed machines. Docker recommended for locked-down environments. |

---

## Project Structure

Follows [MathWorks Toolbox Best Practices](https://github.com/mathworks/toolboxdesign) and [MATLAB Coding Guidelines](https://github.com/mathworks/MATLAB-Coding-Guidelines).

```
matlab-http-server/
│   README.md
│   LICENSE
│   matlab-http-server.prj       % MATLAB Project + toolbox packaging (R2025a+)
│   buildfile.m                  % buildtool automation
│   .gitignore
│   .gitattributes
├───images/
│       matlab-http-server.png
├───toolbox/
│   │   MatlabHttpServer.m       % primary entry point — no namespace, used directly
│   ├───+mhs/                    % mhs namespace — all user-facing framework classes
│   │       ApiController.m      % mhs.ApiController — users inherit from this
│   │       HttpRequest.m        % mhs.HttpRequest
│   │       HttpResponse.m       % mhs.HttpResponse
│   │       Router.m             % mhs.Router
│   │       HttpStatus.m         % mhs.HttpStatus
│   ├───+mhs/+internal/          % mhs.internal — implementation details, not for end users
│   │       BufferAccumulator.m
│   │       RequestParser.m
│   │       CorsHandler.m
│   ├───doc/
│   │       GettingStarted.mlx
│   ├───examples/
│   │   ├───BasicExample/
│   │   ├───MultiControllerExample/
│   │   └───ReactFrontendExample/
│   └───private/
│           HttpParser.m
├───tests/
│       TestMatlabHttpServer.m
│       TestApiController.m
│       TestHttpRequest.m
│       TestHttpResponse.m
│       TestRouter.m
├───docker/
│       Dockerfile.full
│       Dockerfile.mcr
│       docker-compose.yml
└───release/
        matlab-http-server.mltbx  % not under source control
```

---

## Contributing

Tests are required for all new functionality. Run tests before submitting:
```matlab
buildtool test   % runs tests + coverage report
buildtool ci     % full pipeline: check + test + package
```

See [AGENTS.md](AGENTS.md) for architecture details, coding conventions, and guidance for AI coding agents working on this codebase.

---

## Inspiration

`matlab-http-server` fills a gap in the MATLAB ecosystem. MathWorks' official HTTP tooling is client-only (`matlab.net.http`) or requires expensive licensed server products. With Java interop being deprecated in newer MATLAB releases, a native `tcpserver`-based solution built on modern OOP patterns is the right path forward.

The routing pattern is inspired by Flask and draws on the same metaclass inspection technique used internally by `matlab.unittest` for test discovery.

---

## License

MIT © 2026
