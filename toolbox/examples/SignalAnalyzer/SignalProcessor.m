classdef SignalProcessor < mhs.ApiController
    % SignalProcessor A non-trivial API controller for data analysis
    %   Demonstrates processing numeric vectors, generating signals,
    %   and returning complex statistics from MATLAB to a web UI.

    methods (Access = protected)
        function registerRoutes(obj)
            obj.get('/api/status',   @obj.getStatus);
            obj.post('/api/generate', @obj.generateSignal);
            obj.post('/api/analyze',  @obj.analyzeSignal);
        end
    end

    methods
        function res = getStatus(~, ~, res)
            % GET /api/status - Return MATLAB environment info
            info.version = string(version);
            info.platform = string(computer);
            info.currentTime = string(datetime('now'));
            info.status = "Ready to process signals";
            res.json(info);
        end

        function res = generateSignal(~, req, res)
            % POST /api/generate - Generate synthetic data
            %   Input: {type: 'sine'|'noise', points: 100, amplitude: 1.0}
            data = req.Body;
            type = data.type;
            n = data.points;
            amp = data.amplitude;

            x = linspace(0, 2*pi, n);
            if strcmpi(type, "sine")
                val = amp * sin(x);
            elseif strcmpi(type, "noise")
                val = amp * randn(1, n);
            else
                val = zeros(1, n);
            end

            res.json(struct('signal', val, 'timestamp', string(datetime('now'))));
        end

        function res = analyzeSignal(~, req, res)
            % POST /api/analyze - Perform statistical analysis
            %   Input: {signal: [1,2,3,...], windowSize: 5}
            data = req.Body;
            sig = data.signal;
            win = data.windowSize;

            % Perform non-trivial processing
            results.mean = mean(sig);
            results.median = median(sig);
            results.std = std(sig);
            results.movingAverage = movmean(sig, win);
            results.magnitude = abs(fft(sig));

            res.json(results);
        end
    end
end
