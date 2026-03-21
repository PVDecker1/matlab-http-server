# AGENTS.md — matlab-http-server

This file provides guidance for AI coding agents (Jules, Claude, Copilot, etc.) working on this codebase. Read this entire file before making any changes.

---

## What This Project Is

`matlab-http-server` is a zero-dependency HTTP server framework for MATLAB. Developers define REST API endpoints by subclassing `mhs.ApiController`, implementing the abstract `registerRoutes` method to map paths to handlers, and defining handler methods. A `tcpserver`-based HTTP layer parses incoming requests and dispatches to registered handlers.

**The core pattern:** Subclass `mhs.ApiController`, override `registerRoutes`, register handlers using `obj.get()`, `obj.post()` etc., implement handlers with signature `res = myHandler(obj, req, res)`.

---

## Architecture Overview

```
MatlabHttpServer
    └── tcpserver (R2021a+)
        ├── ConnectionChangedFcn → onConnect()
        └── Data callback → onData()
            └── mhs.internal.HttpParser.parse()
                ├── parseRequestLine()
                ├── parseHeaders()
                └── parseBody()
                    └── Router.dispatch(HttpRequest, HttpResponse)
                        └── ApiController subclass
                            └── res = handlerMethod(obj, req, res)
                                └── HttpResponse.write()
```

### Key Classes

| Class | File | Responsibility |
|---|---|---|
| `MatlabHttpServer` | `toolbox/MatlabHttpServer.m` | Primary entry point. No namespace — used directly. Owns `tcpserver`, manages connection lifecycle, feeds raw bytes to `HttpParser` |
| `mhs.ApiController` | `toolbox/+mhs/ApiController.m` | Abstract base class users inherit from. Provides `obj.get()`, `obj.post()` etc. Declares abstract `registerRoutes`. Calls `registerRoutes` in constructor. |
| `mhs.HttpRequest` | `toolbox/+mhs/HttpRequest.m` | Value class. Holds parsed method, path, headers, body, query params, path params. Uses `dictionary`. |
| `mhs.HttpResponse` | `toolbox/+mhs/HttpResponse.m` | Builder-style handle class. Writes HTTP response back to socket. Uses `dictionary`. |
| `mhs.Router` | `toolbox/+mhs/Router.m` | Aggregates multiple `mhs.ApiController` instances, dispatches by path |
| `mhs.HttpStatus` | `toolbox/+mhs/HttpStatus.m` | Named HTTP status code constants |
| `mhs.internal.HttpParser`| `toolbox/+mhs/+internal/HttpParser.m` | Internal. Parses raw `uint8` buffer into `mhs.HttpRequest`. Not part of public API. |

---

## Repo Structure

This project follows [MathWorks Toolbox Best Practices](https://github.com/mathworks/toolboxdesign) and [MATLAB Coding Guidelines](https://github.com/mathworks/MATLAB-Coding-Guidelines).

```
matlab-http-server/
│   README.md
│   LICENSE
│   matlab-http-server.prj   % MATLAB Project + packaging file (R2025a+)
│   buildfile.m              % buildtool tasks
│   .gitignore
│   .gitattributes
├───images/
├───toolbox/                 % All distributable code lives here — nothing else
│   │   MatlabHttpServer.m   % primary entry point — no namespace
│   ├───+mhs/                % mhs namespace — all user-facing framework classes
│   │       ApiController.m  % mhs.ApiController — users inherit from this
│   │       HttpRequest.m    % mhs.HttpRequest
│   │       HttpResponse.m   % mhs.HttpResponse
│   │       Router.m         % mhs.Router
│   │       HttpStatus.m     % mhs.HttpStatus
│   ├───+mhs/+internal/      % mhs.internal — not for end users
│   │       BufferAccumulator.m
│   │       HttpParser.m
│   │       CorsHandler.m
│   ├───doc/
│   │       GettingStarted.mlx
│   │       contributing.md
│   │       deployment.md
│   │       getting-started.md
│   │       request-response.md
│   │       routing.md
│   │       static-file-serving.md
│   ├───examples/
│   │   ├───BasicExample/
│   │   │       BasicController.m
│   │   │       runBasicExample.m
│   │   ├───MultiControllerExample/
│   │   │       AdminController.m
│   │   │       UserController.m
│   │   │       runMultiControllerExample.m
│   │   └───SignalAnalyzer/
│   │           SignalProcessor.m
│   │           index.html
│   │           runSignalAnalyzer.m
│   └───private/
├───tests/                   % Tests live here, NOT in toolbox/
└───build/                   % Build artifacts (gitignored)
```

**Critical:** Only code in `toolbox/` is distributed to users. Tests, docker files, and build utilities are never in `toolbox/`.

---

## Coding Conventions

Follow the [MATLAB Coding Guidelines](https://github.com/mathworks/MATLAB-Coding-Guidelines) for all new code. Key rules:

### General
- All classes use `classdef ... < handle` unless it is a pure value type
- Value classes (`HttpRequest`) use plain `classdef` (no superclass)
- Use `arguments` blocks for all public method input validation — do not use manual `narginchk`/`validateattributes`
- All `error()` calls must use a two-part identifier string in the format "ClassName:ErrorType" (e.g. "HttpParser:InvalidJson"). Plain string error messages without identifiers are not acceptable in framework code.
- Prefer `string` type over `char` for new code — be explicit at type boundaries using `string()` or `char()`
- **Use `dictionary` instead of `containers.Map`** for all new mapping needs (requires R2022b+)
- Every public function and class must have a help comment block immediately after the definition line
- No magic numbers — use named constants or descriptive variables
- Minimal MATLAB version: R2022b (for `dictionary` support)

### Naming
- Classes: `PascalCase` (e.g. `MatlabHttpServer`)
- Properties: `PascalCase` (e.g. `obj.Port`, `obj.Routes`)
- Public methods: `camelCase` (e.g. `obj.dispatch()`, `obj.register()`)
- Private helpers: `camelCase` in `methods (Access = private)` blocks
- Test classes: `Test<ClassName>.m` (e.g. `TestApiController.m`)
- Test methods: must use `Test` attribute — e.g. `methods (Test)`

### Namespaces (`+` Folders)

Use MATLAB namespaces (package folders prefixed with `+`) to organize code and avoid name collisions. This project uses the following namespace structure:

- **`MatlabHttpServer`** stays at the root of `toolbox/` with no namespace — it is the primary entry point and called directly, consistent with how MATLAB built-ins like `tcpserver` work.
- **`+mhs/` namespace** — all user-facing framework classes that users interact with by name. Users inherit from `mhs.ApiController`, receive `mhs.HttpRequest` and `mhs.HttpResponse` objects, etc. This mirrors the pattern of `matlab.unittest.TestCase`, `matlab.apps.AppBase`, and other MathWorks frameworks.
- **`+mhs/+internal/` namespace** — implementation details not intended for end users. The full qualified name `mhs.internal.X` signals clearly this is internal code.

```matlab
% Users write this — feels native, consistent with MathWorks conventions
classdef MyController < mhs.ApiController
    ...
end
```

When adding new functionality: primary framework classes users subclass or interact with go in `+mhs/`. Implementation details go in `+mhs/+internal/`. Do not add new classes to the root `toolbox/` level — `MatlabHttpServer` is the only intentional exception.

Do not create new top-level namespaces. All new namespace code belongs under `+mhs/`.

### Route Registration

Routes are registered by overriding the abstract `registerRoutes` method. This method is called automatically by the `ApiController` constructor. MATLAB will throw an error at instantiation if it is not implemented — this is intentional and desirable.

**Warning: Route Ordering Hazard.** Routes are matched in registration order. Specific routes (e.g. `/api/users/me`) must be registered BEFORE parameterized routes (e.g. `/api/users/:id`) that would otherwise shadow them.

```matlab
methods (Access = protected)
    function registerRoutes(obj)
        % Correct ordering: specific before general
        obj.get('/api/users/me',     @obj.getMe);
        obj.get('/api/users/:id',    @obj.getUserById);
        
        obj.get('/api/users',        @obj.getUsers);
        obj.post('/api/users',       @obj.createUser);
        obj.put('/api/users/:id',    @obj.updateUser);
        obj.delete('/api/users/:id', @obj.deleteUser);
    end
end
```

Available registration helpers on `ApiController`: `obj.get()`, `obj.post()`, `obj.put()`, `obj.delete()`, `obj.patch()`. Do not add other HTTP verbs without discussion.

### Path Parameters

Use `:param` syntax in route paths. Parameters are extracted by the router and available via `req.PathParams`:

```matlab
function res = getUserById(obj, req, res)
    id = req.PathParams("id");
    res.json(struct('id', id));
end
```

### Handler Signature

All handler methods **must** declare `res` as both an input and output argument. Do not rely on handle mutation alone — returning `res` explicitly makes data flow clear and avoids aliasing issues near concurrent execution.

It is idiomatic to use the `~` receiver pattern for `obj` and/or `req` if they are not used in the handler:

```matlab
% obj and req not needed
function res = getStatus(~, ~, res)
    res.json(struct('status', 'ok'));
end
```

```matlab
% Correct
function res = getUsers(obj, req, res)
    res.json(struct('users', []));
end

% Wrong — missing output argument
function getUsers(obj, req, res)
    res.json(struct('users', []));
end
```

### HTTP Layer Rules
- All HTTP responses **must** use `\r\n` line endings — never `\n` alone
- Always include `Content-Length` header — do not use chunked transfer encoding
- Always include CORS headers on **every** response — this is handled in `HttpResponse`, not in controllers
- Never use `send()` for binary content — use `sendBytes()`. `send()` applies UTF-8 encoding which corrupts images, fonts, and other binary assets.
- Never use `fileread()` to read files for serving — use `fread` with `'rb'` mode. `fileread` assumes text encoding.
- `OPTIONS` preflight requests must be handled at the server layer before reaching any controller
- Connections close after every response — no keep-alive
- Wrap all `tcpserver` callbacks in `try/catch` — uncaught errors in callbacks are difficult to recover from
- Return proper HTTP error responses (400, 404, 500) — never throw to the caller
- Log errors to Command Window with prefix: `[matlab-http-server ERROR]`

---

## What To Preserve

These design decisions are **intentional**. Do not change them without explicit discussion:

1. **Zero external dependencies.** No Python, no Node, no Java. Only MATLAB built-ins, `tcpserver`, and `dictionary`. This is a core feature and selling point.
2. **Metaclass-based routing.** Routes are discovered automatically via `metaclass()` and `meta.method`. Do not replace this with a manual registration API.
3. **One class per file.** Each class lives in its own `.m` file. Do not consolidate.
4. **No keep-alive.** Connections close after each response. This dramatically simplifies buffer and state management.
5. **HTTP/1.1 happy path only.** Chunked encoding, multipart, and HTTP/2 are explicitly out of scope. Document them as limitations, do not implement them.
6. **`HttpParser` stays private.** It is an implementation detail. Do not expose it in the public API or move it to `+mhs/`.
7. **Static handlers before API.** Static handlers are checked before the API router in `processRequest`. This order is intentional — do not reverse it.

---

## What Is In Scope

- Core server: `MatlabHttpServer`, `HttpParser`, `HttpRequest`, `HttpResponse`, `Router`
- `ApiController` base class with metaclass routing
- Automatic CORS header injection (in `HttpResponse`)
- Automatic `OPTIONS` preflight handling (in `MatlabHttpServer`)
- JSON body parsing via `jsondecode` and serialization via `jsonencode`
- Query string parsing
- Static file serving via `mhs.StaticFileHandler` and `MatlabHttpServer.serveStatic`
- Binary file serving via `HttpResponse.sendBytes`
- `matlab.unittest` test suite for all public classes
- `GettingStarted.mlx` and markdown documentation in `toolbox/doc/`
- Examples in `toolbox/examples/`
- `buildfile.m` for `buildtool` automation (test, package, release tasks)

## What Is Out Of Scope

Do not implement these without opening an issue and getting approval first:

- TLS/HTTPS (use a reverse proxy — Nginx, Caddy)
- Authentication (implement in controller `preDispatch` hook or proxy layer)
- Chunked transfer encoding
- Multipart form data
- HTTP/2
- WebSockets
- Static file serving
- Parallel Computing Toolbox integration in the core server layer (optional pattern only, in user-defined handlers)
- Docker and MCR deployment configuration
- Kubernetes / horizontal scaling configuration
- MATLAB Compiler (`mcc`) integration in the core framework

---

## Open Questions / Known Risks

Do not assume these are resolved. Do not write code that depends on them until validated:

1. **`tcpserver` partial reads** — TCP does not guarantee a full HTTP request arrives in one callback invocation. Buffer accumulation in `MatlabHttpServer` must handle partial reads correctly. This is the most likely source of intermittent bugs — test it thoroughly.

2. **`tcpserver` thread safety** — Callbacks run on MATLAB's main thread. Do not introduce `parfeval` or `backgroundPool` into the core server layer. Async patterns belong in user-defined controller methods only.

---

## Testing

All public classes require `matlab.unittest` tests in `tests/`. Tests must not require a live `tcpserver` — mock or stub the socket layer where possible. HTTP parsing tests use raw byte string inputs, not live connections.

Run the full suite:
```matlab
results = runtests('tests/');
table(results)
```

CI runs automatically on every push via GitHub Actions using a MATLAB licensed runner. Do not merge code that breaks CI.

---

## Build & CI

- The project uses `buildtool` with `buildfile.m` at the project root.
- Default task is `test`. Full pipeline is `buildtool ci`.
- Coverage threshold is 90% per file (line coverage).
- Coverage is enforced by `scripts/checkCoverage.m` called from `buildfile.m` after the test task.
- CI runs on GitHub Actions via `.github/workflows/ci.yml`.
- Toolbox is packaged automatically on push to main and on `v*` tags.
- Releases are created automatically on `v*` tags.

---

## Git Conventions

- Tag format for releases: `vMAJOR.MINOR.PATCH` (e.g. `v1.0.0`)
- CI badge is in README and must stay green before merge.
- Branch naming: `feature/short-description`, `fix/short-description`
- Commit messages: imperative present tense (`Add query string parsing`, not `Added...`)
- Do not commit `.asv` autosave files, `*.mexw64`, or compiled artifacts
- Every PR must pass CI before merge

---

## MATLAB Quick Reference

```matlab
% ApiController registration helpers
obj.get('/path',    @obj.handler);
obj.post('/path',   @obj.handler);
obj.put('/path',    @obj.handler);
obj.delete('/path', @obj.handler);
obj.patch('/path',  @obj.handler);

% Path parameters
id = req.PathParams("id");

% Query parameters
val = req.QueryParams("filter");

% tcpserver setup
server = tcpserver("0.0.0.0", 8080);
server.ConnectionChangedFcn = @onConnect;
configureCallback(server, "byte", 1, @onData);

% Reading and writing
bytes = read(src, src.NumBytesAvailable, "uint8");
write(src, uint8(responseStr));

% JSON
body = jsondecode(rawJsonString);   % → struct
out  = jsonencode(myStruct);        % → char

% String type boundaries
s = string(charArray);   % char → string
c = char(stringVal);     % string → char
```

---

## HTTP Format Reference

**Windows CMD Note:** When using `curl` from a Windows CMD shell, double quotes in a JSON body must be escaped (e.g., `\"{\"\"key\"\":\"\"val\"\"}\"`). PowerShell and Unix shells handle single-quoted JSON bodies correctly.

**Minimal valid response:**
```
HTTP/1.1 200 OK\r\n
Content-Type: application/json\r\n
Content-Length: 16\r\n
Access-Control-Allow-Origin: *\r\n
\r\n
{"status":"ok"}
```

**CORS preflight (`OPTIONS`) response:**
```
HTTP/1.1 200 OK\r\n
Access-Control-Allow-Origin: *\r\n
Access-Control-Allow-Methods: GET, POST, PUT, DELETE, PATCH, OPTIONS\r\n
Access-Control-Allow-Headers: Content-Type, Authorization\r\n
Content-Length: 0\r\n
\r\n
```

**Minimal valid request (for parser testing):**
```
POST /api/users HTTP/1.1\r\n
Host: localhost:8080\r\n
Content-Type: application/json\r\n
Content-Length: 27\r\n
\r\n
{"name":"Austin","age":30}
```
