% runStaticSiteExample.m - Example of serving a static site
%
%   This script starts a MatlabHttpServer on port 8082 and serves
%   static files from the local 'site/' directory.

% 1. Add the toolbox to path (if not already managed by project)
% This allows running the example directly from the examples folder.
addpath(fullfile(pwd, '..', '..'));

% 2. Locate the static site directory
% The static files (index.html, about.html) are stored in the 'site/' subfolder.
siteDir = fullfile(pwd, 'site');

if ~exist(siteDir, 'dir')
    error('Example:MissingSiteDir', 'Could not find the "site/" directory. Make sure you are running this script from its containing folder.');
end

% 3. Start a MatlabHttpServer on port 8082
server = MatlabHttpServer(8082);

% 4. Call server.serveStatic("site/")
% This registers the directory to be served. Files in this folder 
% will be matched against incoming request paths.
server.serveStatic(siteDir);

% 5. Start the server
server.start();

% 6. Open the browser to the home page
web('http://localhost:8082', '-browser');

fprintf('\n[matlab-http-server] Example is running at http://localhost:8082\n');
fprintf('[matlab-http-server] Navigation between / and /about.html is active.\n');
fprintf('[matlab-http-server] Press Ctrl+C to stop (or close the MATLAB session).\n');

% 7. Include a loop for non-desktop mode to keep the process alive
if ~usejava('desktop')
    while true
        pause(1);
    end
end
