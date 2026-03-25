# Deployment Guide

`matlab-http-server` is designed for internal tools, dashboards, research APIs, and small-team services. This guide covers how to run it locally and how to place it behind a reverse proxy for shared deployments.

---

## Local - Single User

This is the simplest deployment model. Start the server in a normal MATLAB session and interact with it from your browser or API client.

1. Run your server script in MATLAB.
2. Open your browser to `http://localhost:8080` or whatever port your script selected.
3. Stop the server cleanly with `server.stop()` or by ending the MATLAB session.

### Pairing with a Frontend Dev Server

If you are developing a React or Vue app with a separate dev server such as Vite, run that frontend on one port and MATLAB on another.

```matlab
server = MatlabHttpServer(8080, AllowedOrigin="http://localhost:5173");
```

### Serving Frontend and API from One MATLAB Server

For many local tools, the simplest setup is to serve your frontend and API from the same MATLAB process:

```matlab
server = MatlabHttpServer(8080);
server.register(MyController());
server.serveStatic("public/");
server.start();
```

This keeps the frontend and API on the same origin and avoids extra CORS complexity.

---

## Choosing a Transport

`matlab-http-server` supports two transport layers.

### 1. Java Socket (Default)

Uses `java.net.ServerSocket` coordinated by a MATLAB timer loop. Works in **Base MATLAB**.

- **Pros**: Zero toolbox dependencies, straightforward local use, good default for desktop tools and demos.
- **Cons**: Less scalable than the Go sidecar for heavier request loads.

### 2. Go Sidecar

Spawns an external Go binary to handle the HTTP socket layer and communicates with MATLAB over standard I/O.

- **Pros**: Better fit for headless or more server-oriented use cases, still works with Base MATLAB.
- **Cons**: Requires the bundled `matlab-http-bridge` binary.

```matlab
server = MatlabHttpServer(8080, Transport="go");
```

---

## Centralized - Small Team

To share a MATLAB API or internal tool with a small team, run it on a shared machine and put a reverse proxy such as Caddy or Nginx in front of it.

### Licensing Considerations

Shared deployments can have different MathWorks licensing requirements than a single-user local workflow. If multiple users will access the same MATLAB-backed web application or API, confirm that your organization's MATLAB license allows that deployment pattern and has enough named users or concurrent seats for the expected usage.

This project does not change or extend MathWorks licensing terms. Treat the official MathWorks documentation as the source of truth for what your organization is permitted to run.

- [Individual License Administration](https://www.mathworks.com/help/install/license/individual-license-administration.html)
- [Administer Network Licenses](https://www.mathworks.com/help/install/administer-network-licenses.html)
- [Concurrent License Administration](https://www.mathworks.com/help/install/license/concurrent-licenses.html)
- [Network Named User License Administration](https://www.mathworks.com/help/install/license/key-administrative-tasks.html)

### Why Use a Reverse Proxy?

- **Security**: Dedicated web servers are better suited for external network exposure.
- **TLS/SSL**: `matlab-http-server` does not provide HTTPS directly.
- **Routing**: A proxy can route `/api/` to MATLAB and handle other paths differently if needed.
- **Static Assets**: `matlab-http-server` can serve static assets directly, but a dedicated web server is often better for heavier traffic.
- **Port 80/443**: MATLAB typically runs on a higher port such as `8080`.

### Recommended Configuration: Caddy

[Caddy](https://caddyserver.com/) is a convenient option because it handles certificates automatically.

```caddy
yourserver.company.com {
    handle_path /api/* {
        reverse_proxy localhost:8080
    }

    file_server {
        root /var/www/html
    }
}
```

### Alternative: Nginx

```nginx
server {
    listen 80;
    server_name yourserver.company.com;

    location /api/ {
        proxy_pass http://localhost:8080/;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }

    location / {
        root /var/www/html;
        index index.html;
    }
}
```

---

## Keeping the Server Running

If you are running in a non-interactive session such as `-batch`, make sure MATLAB stays alive after `server.start()`.

```matlab
server.start();

if batchStartupOptionUsed
    fprintf('[matlab-http-server] Running in batch mode. Press Ctrl+C to stop.\n');
    while true
        pause(1);
    end
end
```

### Single-Threaded Constraint

MATLAB remains effectively single-threaded for handler execution. A long-running route handler will block other requests while it runs.

For compute-heavy work, consider using the optional [Async Handler pattern](../../README.md#async-handlers) in your own controller code with Parallel Computing Toolbox.

---

## Security Considerations

- **Bind to localhost when using a reverse proxy** whenever practical.
- **Do not expose MATLAB directly to the open internet** without a reverse proxy and firewalling.
- **Authentication is not built in**. Implement it in your controllers or, preferably, at the proxy layer.

---

## Note on Docker and MCR

Deployment through Docker containers or the MATLAB Runtime (MCR) remains out of scope for this release. These models may be possible, but they are not yet treated as validated project targets.
