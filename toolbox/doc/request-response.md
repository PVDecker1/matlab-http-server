# Request & Response

Every route handler in `matlab-http-server` receives two primary objects: an `mhs.HttpRequest` representing the incoming data, and an `mhs.HttpResponse` used to formulate and send the response.

---

## `mhs.HttpRequest`

The `HttpRequest` object contains all the information sent by the client. It is a value-style class (though currently implemented as a handle for internal consistency) that holds parsed HTTP information.

### Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `Method` | `string` | The HTTP verb (e.g., `"GET"`, `"POST"`, `"PUT"`). |
| `Path` | `string` | The requested URL path (e.g., `"/api/users/123"`). |
| `Headers` | `dictionary` | A mapping of header names to values. |
| `Body` | `any` | The parsed request body. Content varies by `Content-Type`. |
| `QueryParams` | `dictionary` | Key-value pairs extracted from the URL query string. |
| `PathParams` | `dictionary` | Parameters extracted from dynamic route segments (e.g., `:id`). |

### Accessing Data

#### Headers
Headers are stored in a MATLAB `dictionary`. Access them using the standard key-indexing syntax:
```matlab
authHeader = req.Headers("Authorization");
```

#### Query Parameters
Query parameters (e.g., `?filter=active&sort=desc`) are automatically parsed into the `QueryParams` dictionary.
```matlab
filterVal = req.QueryParams("filter");
```
If a key is missing, MATLAB will throw an error. Use `req.QueryParams.isKey("key")` to check for existence if a parameter is optional.

#### Path Parameters
Path parameters are populated by the router during dispatch.
```matlab
userId = req.PathParams("id");
```

#### Request Body
The `Body` property is automatically parsed based on the `Content-Type` header:
- **`application/json`**: Parsed into a MATLAB `struct` using `jsondecode`.
- **`text/plain`**: Provided as a MATLAB `string`.
- **Other/Missing**: Provided as a `uint8` array of raw bytes.

---

## `mhs.HttpResponse`

The `HttpResponse` object is a builder-style handle class. You use its methods to set the status code, add headers, and finally send the body.

### Properties

| Property | Type | Description |
| :--- | :--- | :--- |
| `AllowedOrigin` | `string` | The value used for the `Access-Control-Allow-Origin` header. Defaults to `"*"` but can be overridden. |

### Builder Methods

All response methods return the `obj` instance, allowing you to chain calls:

```matlab
res.status(201).header("X-My-Header", "Value").json(data);
```

#### `status(code)`
Sets the HTTP status code. Use the `mhs.HttpStatus` constants for readability.
```matlab
res.status(mhs.HttpStatus.Created); % sets 201
res.status(404); % sets 404
```

#### `header(name, value)`
Adds or updates a custom HTTP header.
```matlab
res.header("X-Custom-Header", "MyValue");
```

### Sending the Response

Once one of the following "send" methods is called, the response is formulated, headers are finalized, and the data is written to the client socket. Subsequent calls to send methods are ignored.

#### `json(data)`
Serializes the provided MATLAB data to a JSON string using `jsonencode` and sends it with `Content-Type: application/json`.
- `struct` -> JSON object `{}`
- `array` -> JSON array `[]`
- `string`/`char` -> JSON string `""`

```matlab
res.json(struct('id', 1, 'name', 'Austin'));
```

#### `send(text)`
Sends a plain text response with `Content-Type: text/plain`. The text is encoded as UTF-8.
```matlab
res.send("Hello from MATLAB");
```

#### `sendBytes(bytes)`
Sends raw binary data. This is **required** for images, fonts, and other non-text assets to avoid UTF-8 encoding corruption.
```matlab
imgData = fread(fopen('image.png', 'rb'), '*uint8');
res.header("Content-Type", "image/png").sendBytes(imgData);
```

### Utility Methods

#### `isSent()`
Returns `true` if a send method has already been called and the response has been written to the socket.
```matlab
if ~res.isSent()
    res.status(500).send("An error occurred");
end
```

#### `getRawResponseForTesting()`
Returns `[code, hdrs, body]`. This method is intended for use in unit tests to verify the state of a response without needing a live network connection. **Do not use this in production code.**

---

## CORS Support

CORS (Cross-Origin Resource Sharing) headers are handled automatically by `HttpResponse`. Every response includes:
- `Access-Control-Allow-Origin`: (Based on `obj.AllowedOrigin`)
- `Access-Control-Allow-Methods`: `GET, POST, PUT, DELETE, PATCH, OPTIONS`
- `Access-Control-Allow-Headers`: `Content-Type, Authorization`

You can restrict the allowed origin when constructing the `MatlabHttpServer`:
```matlab
server = MatlabHttpServer(8080, 'AllowedOrigin', 'http://localhost:3000');
```
