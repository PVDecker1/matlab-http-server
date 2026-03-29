# `mhs.ApiTestCase`

`mhs.ApiTestCase` is a controller-testing mixin for `matlab.unittest`. It helps you exercise `mhs.ApiController` subclasses through a real `mhs.Router` without opening sockets or constructing raw HTTP byte streams by hand.

This is the intended tool for controller-level tests:

- routing to the right handler
- path parameter extraction
- query parameter handling
- request body dispatch
- response status, headers, and body assertions

It is not a replacement for parser tests or live transport tests.

---

## Inheritance Pattern

`mhs.ApiTestCase` is a mixin, so inherit from both `matlab.unittest.TestCase` and `mhs.ApiTestCase`:

```matlab
classdef TestMyController < matlab.unittest.TestCase & mhs.ApiTestCase
    methods (Test)
        function testGetUsers(tc)
            ctrl = MyController();
            res = tc.GET(ctrl, "/api/users");

            tc.verifyOk(res);
            body = tc.decodeJson(res);
            tc.verifyEqual(numel(body.users), 3);
        end
    end
end
```

---

## What It Does

Each dispatch helper:

1. builds a real `mhs.HttpRequest`
2. creates a socketless `mhs.HttpResponse`
3. registers the controller in a fresh `mhs.Router`
4. dispatches the request through the router
5. returns the populated response

Using a fresh router per call keeps tests isolated and avoids route-registration leakage between test methods.

---

## Dispatch Helpers

Available request helpers:

```matlab
res = tc.GET(controller, path)
res = tc.POST(controller, path, body)
res = tc.PUT(controller, path, body)
res = tc.DELETE(controller, path)
res = tc.PATCH(controller, path, body)
```

Each helper also accepts `Headers=...`.

Examples:

```matlab
res = tc.GET(ctrl, "/api/users/42");
res = tc.GET(ctrl, "/api/search?q=test");
res = tc.POST(ctrl, "/api/items", struct("name", "demo"));
res = tc.GET(ctrl, "/api/ping", Headers=dictionary("X-Test-Header", "abc"));
```

Supported body shapes for body-bearing helpers include:

- `struct`
- `string`
- `char`
- numeric JSON-encodable values
- `[]`

For JSON-like bodies, the helper sets `Content-Type: application/json`.
For text bodies, it sets `Content-Type: text/plain`.

---

## Assertion Helpers

`mhs.ApiTestCase` provides convenience helpers for common response checks:

```matlab
tc.verifyStatus(res, 200)
tc.verifyOk(res)
tc.verifyCreated(res)
tc.verifyNotFound(res)
tc.verifyBadRequest(res)

data = tc.decodeJson(res)

tc.verifyHeader(res, "Content-Type", "application/json")
tc.verifyContentType(res, "application/json")
tc.verifyBodyContains(res, "hello")
```

`decodeJson` throws `ApiTestCase:InvalidJsonResponse` if the response body is not valid JSON, which makes failures easier to diagnose in controller tests.

---

## Example Controller Test

```matlab
classdef TestHelloController < matlab.unittest.TestCase & mhs.ApiTestCase
    methods (Test)
        function testHello(tc)
            ctrl = HelloController();
            res = tc.GET(ctrl, "/hello");

            tc.verifyOk(res);
            tc.verifyContentType(res, "application/json");

            body = tc.decodeJson(res);
            tc.verifyEqual(string(body.message), "Hello, MATLAB!");
        end

        function testEcho(tc)
            ctrl = HelloController();
            res = tc.POST(ctrl, "/echo", struct("name", "Austin"));

            tc.verifyOk(res);
            body = tc.decodeJson(res);
            tc.verifyEqual(string(body.name), "Austin");
        end
    end
end
```

---

## What To Test Here

`mhs.ApiTestCase` is a good fit for:

- controller routing behavior
- handler success and error responses
- path parameters
- query parameters
- expected response headers
- JSON response shape

---

## What Not To Test Here

Use other tests for:

- raw HTTP parsing from bytes
- malformed request framing
- partial-read behavior
- live socket transport behavior
- Java and Go transport lifecycle

Those concerns belong in parser, transport, and live-server tests rather than controller mixin tests.

---

## Related Docs

- [Getting Started](getting-started.md)
- [Routing](routing.md)
- [Request & Response](request-response.md)
- [Contributing](contributing.md)
