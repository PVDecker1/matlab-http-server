# AGENTS.md - matlab-http-server

This file provides guidance for AI coding agents working on this codebase. Read this entire file before making changes.

---

## What This Project Is

`matlab-http-server` is a zero-dependency HTTP server framework for MATLAB. It is intended to support both REST APIs and static file serving in base MATLAB, with an optional Go sidecar transport for server-oriented deployments.

Developers define endpoints by subclassing `mhs.ApiController`, implementing the abstract `registerRoutes` method, and writing handler methods with the signature `res = myHandler(obj, req, res)`.

The project goal is to provide HTTP serving in MATLAB without depending on Instrument Control Toolbox or Parallel Computing Toolbox for core server functionality.

---

## Architecture Overview

```text
MatlabHttpServer
    -> mhs.internal.TcpTransport (abstract)
        -> JavaSocketTransport
           Default/base-MATLAB transport path for interactive use
           Implemented with java.net sockets and a MATLAB timer loop
        -> GoSidecarTransport
           Optional opt-in transport for headless/server use
            -> mhs.internal.HttpParser.parse()
                -> parseRequestLine()
                -> parseHeaders()
                -> parseBody()
                    -> Router.dispatch(HttpRequest, HttpResponse)
                        -> ApiController subclass
                            -> res = handlerMethod(obj, req, res)
                                -> TcpTransport.writeResponse()
```

### Transport Layer

| Transport | Implementation | Use Case |
|---|---|---|
| `JavaSocketTransport` | `java.net.ServerSocket` plus a MATLAB timer loop | Default. Base MATLAB. Interactive use, demos, desktop tooling. |
| `GoSidecarTransport` | Go binary over stdin/stdout | Optional opt-in. Headless use, server deployments, higher-load scenarios. |

### Transport Constraints

- Do not introduce `tcpserver` as a core transport dependency path unless the toolbox dependency tradeoff is explicitly revisited.
- Do not require Parallel Computing Toolbox in the core server layer.
- If async/offloading behavior is needed inside a transport, document clearly whether it relies only on base MATLAB features.
- User-defined handlers may opt into extra toolboxes, but the framework core must not require them.

### Key Classes

| Class | File | Responsibility |
|---|---|---|
| `MatlabHttpServer` | `toolbox/MatlabHttpServer.m` | Primary entry point. Owns a `TcpTransport`, manages connection events. |
| `mhs.internal.TcpTransport` | `toolbox/+mhs/+internal/TcpTransport.m` | Abstract base class for network implementations. |
| `mhs.ApiController` | `toolbox/+mhs/ApiController.m` | Abstract base class users inherit from. Provides route registration helpers. |
| `mhs.HttpRequest` | `toolbox/+mhs/HttpRequest.m` | Value class holding parsed request data. |
| `mhs.HttpResponse` | `toolbox/+mhs/HttpResponse.m` | Builder-style handle class for formulating responses. |
| `mhs.Router` | `toolbox/+mhs/Router.m` | Matches requests to controller handlers. |
| `mhs.internal.HttpParser` | `toolbox/+mhs/+internal/HttpParser.m` | Parses raw bytes into `mhs.HttpRequest`. |

---

## Repo Structure

This project follows [MathWorks Toolbox Best Practices](https://github.com/mathworks/toolboxdesign) and [MATLAB Coding Guidelines](https://github.com/mathworks/MATLAB-Coding-Guidelines).

```text
matlab-http-server/
|   README.md
|   LICENSE
|   matlab-http-server.prj
|   buildfile.m
|   .gitignore
|   .gitattributes
+---assets/
+---resources/
+---scripts/
+---sidecar/
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
|   |       TcpTransport.m
|   |       JavaSocketTransport.m
|   |       GoSidecarTransport.m
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

Only code in `toolbox/` is distributed to end users. Tests, sidecar sources, build utilities, and project metadata are not distributed as toolbox runtime code.

---

## Coding Conventions

Follow the [MATLAB Coding Guidelines](https://github.com/mathworks/MATLAB-Coding-Guidelines) for all new code.

### General

- All classes use `classdef ... < handle` unless they are pure value types.
- Value classes like `HttpRequest` use plain `classdef`.
- Use `arguments` blocks for public method input validation instead of manual `narginchk` or `validateattributes`.
- All `error()` calls must use a two-part identifier string such as `"HttpParser:InvalidJson"`.
- Prefer `string` over `char` for new code, and be explicit at type boundaries.
- Use `dictionary` instead of `containers.Map` for new mapping needs.
- Every public function and class must have a help comment block immediately after the definition line.
- No magic numbers; use named constants or descriptive variables.
- Minimal MATLAB version is R2022b.

### Naming

- Classes: `PascalCase`
- Properties: `PascalCase`
- Public methods: `camelCase`
- Private helpers: `camelCase`
- Test classes: `Test<ClassName>.m`

### Namespaces

- `MatlabHttpServer` stays at the root of `toolbox/` with no namespace.
- User-facing framework classes belong under `toolbox/+mhs/`.
- Internal implementation details belong under `toolbox/+mhs/+internal/`.
- Do not create new top-level namespaces.

---

## Route Registration

Routes are registered by overriding the abstract `registerRoutes` method. It is called automatically by the `ApiController` constructor. MATLAB should fail clearly at instantiation if `registerRoutes` is not implemented.

Routes are matched in registration order. Specific routes must be registered before parameterized routes that could shadow them.

```matlab
methods (Access = protected)
    function registerRoutes(obj)
        obj.get('/api/users/me',     @obj.getMe);
        obj.get('/api/users/:id',    @obj.getUserById);
        obj.get('/api/users',        @obj.getUsers);
        obj.post('/api/users',       @obj.createUser);
        obj.put('/api/users/:id',    @obj.updateUser);
        obj.delete('/api/users/:id', @obj.deleteUser);
    end
end
```

Available helpers are `obj.get()`, `obj.post()`, `obj.put()`, `obj.delete()`, and `obj.patch()`.

### Path Parameters

Use `:param` syntax in route paths. Parameters are available via `req.PathParams`.

```matlab
function res = getUserById(obj, req, res)
    id = req.PathParams("id");
    res.json(struct('id', id));
end
```

### Handler Signature

All handler methods must declare `res` as both input and output.

```matlab
function res = getUsers(obj, req, res)
    res.json(struct('users', []));
end
```

If `obj` or `req` are unused, `~` is idiomatic.

---

## HTTP Layer Rules

- All HTTP responses must use `\r\n` line endings.
- Always include `Content-Length`; do not use chunked transfer encoding.
- Always include CORS headers on every response. This belongs in `HttpResponse`, not controllers.
- Never use `send()` for binary content; use `sendBytes()`.
- Never use `fileread()` for static assets; use binary-safe file reads.
- `OPTIONS` preflight requests must be handled at the server layer before reaching controllers.
- Connections close after every response; no keep-alive.
- Wrap transport callbacks in `try/catch`.
- Return proper HTTP error responses instead of throwing to the caller.
- Log errors to the Command Window with the prefix `[matlab-http-server ERROR]`.

---

## What To Preserve

These design decisions are intentional.

1. Zero external dependencies for core functionality.
2. Transport abstraction through `mhs.internal.TcpTransport`.
3. Default transport path should work in base MATLAB.
4. Go transport is explicit opt-in.
5. Static file serving is in scope and should remain a first-class feature.
6. `processRequestForTesting` should continue to bypass transport for unit testing.
7. Do not reintroduce Instrument Control Toolbox or Parallel Computing Toolbox as core runtime dependencies.

---

## What Is In Scope

- Core server: `MatlabHttpServer`, `HttpParser`, `HttpRequest`, `HttpResponse`, `Router`
- `ApiController` base class with metaclass routing
- Automatic CORS header injection
- Automatic `OPTIONS` preflight handling
- JSON parsing and serialization
- Query string parsing
- Static file serving via `mhs.StaticFileHandler` and `MatlabHttpServer.serveStatic`
- Binary file serving via `HttpResponse.sendBytes`
- Java and Go transport implementations under the transport abstraction
- `matlab.unittest` test coverage for public classes
- Documentation in `toolbox/doc/`
- Examples in `toolbox/examples/`
- `buildfile.m` automation

## What Is Out Of Scope

Do not implement these without explicit discussion:

- TLS/HTTPS
- Built-in authentication
- Chunked transfer encoding
- Multipart form data
- HTTP/2
- WebSockets
- Docker and MCR deployment configuration
- Kubernetes and horizontal scaling configuration
- MATLAB Compiler (`mcc`) integration in the core framework

---

## Known Risks

1. Partial reads: TCP does not guarantee a full HTTP request arrives in one callback. Buffer accumulation must handle partial reads correctly.
2. Threading model: Do not assume callbacks are safe to parallelize in the core server layer.
3. Dependency drift: Be careful not to accidentally reintroduce Instrument Control Toolbox or Parallel Computing Toolbox through transport changes.

---

## Testing

All public classes require `matlab.unittest` tests in `tests/`. Tests should not require a live socket unless a specific transport integration scenario is being exercised deliberately.

Run the full suite with:

```matlab
results = runtests('tests/');
table(results)
```

CI runs automatically on every push via GitHub Actions using a MATLAB licensed runner.

---

## Build And CI

- The project uses `buildtool` with `buildfile.m`.
- Default task is `test`.
- Full pipeline is `buildtool ci`.
- Coverage threshold is 90% per file.
- Coverage is enforced by `scripts/checkCoverage.m`.
- Toolbox packaging and releases are handled in CI.

---

## Git Conventions

- Tag format for releases: `vMAJOR.MINOR.PATCH`
- Branch naming: `feature/short-description`, `fix/short-description`
- Commit messages: imperative present tense
- Do not commit autosave files or compiled artifacts
- Every PR must pass CI before merge

---

## MATLAB Quick Reference

```matlab
obj.get('/path',    @obj.handler);
obj.post('/path',   @obj.handler);
obj.put('/path',    @obj.handler);
obj.delete('/path', @obj.handler);
obj.patch('/path',  @obj.handler);

id = req.PathParams("id");
val = req.QueryParams("filter");

server = MatlabHttpServer(8080);
server.start();

server = MatlabHttpServer(8080, Transport="go");

body = jsondecode(rawJsonString);
out = jsonencode(myStruct);
```

---

## HTTP Format Reference

**Minimal valid response:**

```text
HTTP/1.1 200 OK\r\n
Content-Type: application/json\r\n
Content-Length: 16\r\n
Access-Control-Allow-Origin: *\r\n
\r\n
{"status":"ok"}
```

**CORS preflight (`OPTIONS`) response:**

```text
HTTP/1.1 200 OK\r\n
Access-Control-Allow-Origin: *\r\n
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, PATCH, OPTIONS\r\n
Access-Control-Allow-Headers: Content-Type, Authorization\r\n
Content-Length: 0\r\n
\r\n
```

**Minimal valid request (for parser testing):**

```text
POST /api/users HTTP/1.1\r\n
Host: localhost:8080\r\n
Content-Type: application/json\r\n
Content-Length: 27\r\n
\r\n
{"name":"Austin","age":30}
```
