function checkCoverage(xmlFile, threshold)
    % CHECKCOVERAGE Enforce a minimum line coverage threshold per file
    %   checkCoverage(xmlFile, 0.90) reads the Cobertura XML and errors if 
    %   any file has a line-rate less than the threshold.

    if nargin < 2
        threshold = 0.90;
    end

    if ~exist(xmlFile, 'file')
        error("checkCoverage:FileNotFound", "Coverage XML file not found: %s", xmlFile);
    end

    % Read the XML file
    xml = xmlread(xmlFile);
    classes = xml.getElementsByTagName('class');
    
    anyFailed = false;
    hasInstrument = ~isempty(ver('instrument'));
    
    for i = 0:classes.getLength()-1
        classNode = classes.item(i);
        filename = char(classNode.getAttribute('filename'));
        lineRate = str2double(classNode.getAttribute('line-rate'));
        
        % Allow lower coverage for the server entry point if tcpserver dependencies 
        % cannot be exercised due to missing Instrument Control Toolbox (e.g. in CI)
        actualThreshold = threshold;
        if ~hasInstrument && contains(filename, 'MatlabHttpServer.m')
            actualThreshold = 0; 
            fprintf('[COVERAGE] Using reduced threshold (0%%) for %s (Missing Instrument Control Toolbox)\n', filename);
        end

        if lineRate < actualThreshold
            fprintf(2, '[COVERAGE FAILURE] %s: %.1f%% (Threshold: %.1f%%)\n', ...
                filename, lineRate * 100, actualThreshold * 100);
            anyFailed = true;
        else
            fprintf('[COVERAGE OK] %s: %.1f%%\n', filename, lineRate * 100);
        end
    end
    
    if anyFailed
        error("checkCoverage:ThresholdNotMet", "One or more files did not meet the %.1f%% coverage threshold.", threshold * 100);
    end
end
