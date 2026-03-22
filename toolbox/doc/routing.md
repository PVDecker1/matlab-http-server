# Routing

`matlab-http-server` uses a declarative routing system defined within `ApiController` subclasses. This guide explains how to map URL paths to handler methods, use path parameters, and manage route priority.

## `registerRoutes`

Every controller must inherit from `mhs.ApiController` and implement the abstract `registerRoutes` method. This method is called automatically when the controller is instantiated.

```matlab
classdef MyController < mhs.ApiController
    methods (Access = protected)
        function registerRoutes(obj)
            % Register routes here
            obj.get('/api/resource', @obj.getResource);
        end
    end
    
    methods
        function res = getResource(obj, req, res)
            res.json(struct('data', 'some data'));
        end
    end
end
```

## HTTP Verb Helpers

The `ApiController` base class provides five helper methods for registering routes:

| Method | HTTP Verb | Example |
| :--- | :--- | :--- |
| `obj.get(path, handler)` | GET | `obj.get('/users', @obj.getUsers)` |
| `obj.post(path, handler)` | POST | `obj.post('/users', @obj.createUser)` |
| `obj.put(path, handler)` | PUT | `obj.put('/users/:id', @obj.updateUser)` |
| `obj.delete(path, handler)` | DELETE | `obj.delete('/users/:id', @obj.deleteUser)` |
| `obj.patch(path, handler)` | PATCH | `obj.patch('/users/:id', @obj.patchUser)` |

## Path Parameters

Use the `:param` syntax to capture dynamic segments of the URL path. Captured values are available in the handler via `req.PathParams`.

```matlab
methods (Access = protected)
    function registerRoutes(obj)
        obj.get('/api/users/:id', @obj.getUserById);
    end
end

methods
    function res = getUserById(obj, req, res)
        % Extract the 'id' parameter from the request
        userId = req.PathParams('id');
        res.json(struct('id', userId, 'name', 'Example User'));
    end
end
```

### Multiple Parameters

You can define multiple parameters in a single path:

```matlab
obj.get('/api/posts/:postId/comments/:commentId', @obj.getComment);
```

Access them in the handler:
```matlab
postId = req.PathParams('postId');
commentId = req.PathParams('commentId');
```

## Route Ordering and Priority

The router uses a **first-match-wins** strategy based on the order in which routes were registered.

### The Specific-to-General Hazard
If you have a specific route and a parameterized route that could overlap, you **must** register the specific route first.

**Correct Ordering:**
```matlab
methods (Access = protected)
    function registerRoutes(obj)
        % Specific route first
        obj.get('/api/users/me', @obj.getMe);
        
        % General parameterized route second
        obj.get('/api/users/:id', @obj.getUserById);
    end
end
```

If you reverse these, a request to `/api/users/me` will be captured by the `:id` route, and `id` will be set to `"me"`.

## Multiple Controllers

When you register multiple controllers with a single `MatlabHttpServer` instance, their routes are aggregated in the order the controllers were registered.

```matlab
server = MatlabHttpServer(8080);
server.register(UserController());    % Routes from UserController are checked first
server.register(AdminController());   % Routes from AdminController are checked second
server.start();
```

## Handler Method Signature

All handler methods **must** accept three arguments and **should** return the response object:

```matlab
function res = myHandler(obj, req, res)
```

- `obj`: The controller instance. Use `~` if not needed.
- `req`: The `mhs.HttpRequest` object. Use `~` if not needed.
- `res`: The `mhs.HttpResponse` object. **Must be returned.**

If a handler forgets to call `res.write()` or `res.send()`, the framework will attempt to call `res.write()` automatically after the handler returns.

## Error Handling

### 404 Not Found
If no registered route matches the incoming request's method and path, the server automatically returns a `404 Not Found` response.

### 500 Internal Server Error
If a handler method throws an error during execution, the router catches it, logs the error to the command window, and returns a `500 Internal Server Error` response to the client.

## Duplicate Route Registration
If you register the exact same method and path multiple times, the **first** one registered will always win. The second registration will be stored but will never be reached during dispatch.
