# Deployment Guide

`matlab-http-server` is designed for building internal tools, dashboards, and research APIs. This guide covers how to deploy the server for local use and for small teams.

---

## Local — Single User

This is the simplest deployment model, where the server runs directly on your development machine.

1. **Run in MATLAB**: Start your server script in the MATLAB Command Window.
2. **Interact**: Open your browser to `http://localhost:8080`.
3. **Stop Cleanly**: Use `Ctrl+C` in the MATLAB Command Window to stop the server and release the network port.

### Pairing with a Modern Frontend
If you are developing a React or Vue application using a tool like Vite, you typically run the Vite dev server on one port (e.g., `5173`) and the MATLAB server on another (e.g., `8080`).

```matlab
% In MATLAB
server = MatlabHttpServer(8080, 'AllowedOrigin', 'http://localhost:5173');
```

---

## Centralized — Small Team

To share your MATLAB API or tool with a small team, run it on a shared machine (a workstation or server) and use a professional web server as a reverse proxy.

### Why use a Reverse Proxy?
- **Security**: Dedicated web servers are hardened against common attacks.
- **TLS/SSL**: MATLAB's `tcpserver` does not support HTTPS. A proxy can handle encryption and certificates.
- **Static Assets**: Nginx or Caddy are significantly faster at serving static files than MATLAB.
- **Port 80/443**: MATLAB usually runs on a high port (8080). A proxy lets you use standard HTTP/S ports.

### Recommended Configuration: Caddy
[Caddy](https://caddyserver.com/) is a modern web server that automatically manages SSL certificates.

**Example `Caddyfile`:**
```caddy
yourserver.company.com {
    # Proxy API requests to MATLAB
    handle_path /api/* {
        reverse_proxy localhost:8080
    }

    # Serve static frontend files
    file_server {
        root /var/www/html
    }
}
```

### Alternative Configuration: Nginx
**Example Nginx config snippet:**
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

If you are running the server in a non-interactive MATLAB session (e.g., using `-batch` or `-nodisplay`), you must ensure the process does not exit immediately after calling `server.start()`.

Use the following pattern at the end of your startup script:

```matlab
server.start();

% If not in desktop mode, loop forever to keep the process alive
if batchStartupOptionUsed
    fprintf('[matlab-http-server] Running in batch mode. Press Ctrl+C to stop.\n');
    while true
        pause(1);
    end
end
```

### Single-Threaded Constraint
MATLAB is primarily single-threaded. While `MatlabHttpServer` uses asynchronous callbacks to handle networking, your route handler methods execute on the main MATLAB thread. **A long-running handler will block the server from responding to other requests.**

For compute-intensive tasks, consider using the [Async Handler pattern](../../README.md#async-handlers) with the Parallel Computing Toolbox.

---

## Security Considerations

- **Bind to localhost**: If you are using a reverse proxy, you should ideally bind the MATLAB server to `127.0.0.1` so it is not accessible directly from the network. (Note: Currently `tcpserver` binds to all interfaces by default).
- **No Direct Internet Exposure**: Never expose `matlab-http-server` directly to the open internet. Always place it behind a firewall and a reverse proxy.
- **Authentication**: The framework does not include built-in authentication. Implement checks within your controller methods or, preferably, at the reverse proxy layer.

---

## Note on Docker and MCR

Deployment via Docker containers or the MATLAB Runtime (MCR) is currently **out of scope** for this release. While these models may work, they have not been fully validated for compatibility with the framework's metaclass-based routing system.
