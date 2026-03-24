%[text] # Getting Started with matlab-http-server
%[text] This Live Script gives a quick orientation to the toolbox and points to the main usage patterns.
%[text] - define API routes by subclassing `mhs.ApiController`
%[text] - start the server in base MATLAB
%[text] - optionally serve frontend files from the same server \
%%
%[text] ## Installation
%[text] Install the toolbox from a release `.mltbx`, or clone the repository and add the `toolbox` folder to your MATLAB path.
%[text] ```matlab
%[text] git clone https://github.com/PVDecker1/matlab-http-server.git
%[text] addpath(fullfile(pwd,'matlab-http-server','toolbox'))
%[text] ```
%[text] The minimum supported MATLAB release is R2022b.
%%
%[text] ## First Server
%[text] Create a `MatlabHttpServer`, register one or more controllers, and call `start()`.
%[text] ```matlab
%[text] server = MatlabHttpServer(8080);
%[text] server.register(MyController());
%[text] server.start();
%[text] ```
%[text] Controller classes inherit from `mhs.ApiController` and implement `registerRoutes`.
%[text] ```matlab
%[text] classdef MyController < mhs.ApiController
%[text]     methods (Access = protected)
%[text]         function registerRoutes(obj)
%[text]             obj.get('/api/hello', @obj.getHello);
%[text]         end
%[text]     end
%[text]     methods
%[text]         function res = getHello(~, ~, res)
%[text]             res.json(struct('message', 'Hello from MATLAB'));
%[text]         end
%[text]     end
%[text] end
%[text] ```
%%
%[text] ## Static File Serving
%[text] Static file serving is a first-class feature of the toolbox.
%[text] ```matlab
%[text] server = MatlabHttpServer(8080);
%[text] server.register(MyController());
%[text] server.serveStatic("public/");
%[text] server.start();
%[text] ```
%[text] This same-origin pattern is a convenient way to host a browser UI and an API from one MATLAB process.
%%
%[text] ## Transport Options
%[text] The default transport uses Java sockets coordinated by a MATLAB timer loop and works in base MATLAB.
%[text] The Go sidecar is optional and can be selected explicitly:
%[text] ```matlab
%[text] server = MatlabHttpServer(8080, Transport="go");
%[text] ```
%[text] The core server does not require Instrument Control Toolbox or Parallel Computing Toolbox.
%%
%[text] ## Examples
%[text] The toolbox includes runnable examples in `toolbox/examples`.
%[text] - `BasicExample` for simple routing
%[text] - `MultiControllerExample` for larger APIs
%[text] - `StaticSiteExample` for frontend hosting
%[text] - `SignalAnalyzer` for a same-origin React-style UI \
%%
%[text] ## Testing and Release Quality
%[text] Run the automated test suite before packaging or releasing the toolbox.
%[text] ```matlab
%[text] buildtool test
%[text] buildtool ci
%[text] ```
%[text] The repository also includes markdown guides for routing, request and response handling, deployment, and static file serving in `toolbox/doc`.
%%
%[text] ## Next Steps
%[text] Continue with these references:
%[text] - `getting-started.md` for the markdown quickstart
%[text] - `routing.md` for path parameters and route ordering
%[text] - `request-response.md` for request and response behavior
%[text] - `static-file-serving.md` for frontend hosting patterns \
%[appendix]{"version":"1.0"}
%---
%[metadata:view]
%   data: {"layout":"inline"}
%---
