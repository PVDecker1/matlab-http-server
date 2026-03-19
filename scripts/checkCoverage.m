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
    for i = 0:classes.getLength()-1
        classNode = classes.item(i);
        filename = char(classNode.getAttribute('filename'));
        lineRate = str2double(classNode.getAttribute('line-rate'));
        
        if lineRate < threshold
            fprintf(2, '[COVERAGE FAILURE] %s: %.1f%% (Threshold: %.1f%%)\n', ...
                filename, lineRate * 100, threshold * 100);
            anyFailed = true;
        else
            fprintf('[COVERAGE OK] %s: %.1f%%\n', filename, lineRate * 100);
        end
    end
    
    if anyFailed
        error("checkCoverage:ThresholdNotMet", "One or more files did not meet the %.1f%% coverage threshold.", threshold * 100);
    end
end
