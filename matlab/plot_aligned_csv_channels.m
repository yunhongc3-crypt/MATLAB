%% plot_aligned_csv_channels.m
% 將多個 CSV 的所有有效通道畫在同一張圖，並把時間 t = 0 對齊。
%
% 支援三種常用格式：
%   1) FPGA ILA：i_sen / Vbus / Vac
%   2) FPGA ILA：Voltage_loop / Current_loop / PWM / CCM mode 等控制訊號
%   3) 示波器 CSV：第一欄為時間，其餘欄位為量測通道
%
% 時間對齊方式：
%   - ILA：TRIGGER = 1 的那一筆定義為 t = 0
%   - 示波器：時間欄最接近 0 的樣本平移到精確 t = 0
%
% 使用方式：
%   1. Run
%   2. 在檔案選擇視窗一次選取一個或多個 CSV
%   3. 程式自動辨識格式、通道、時間並畫在同一張圖
%
% 顯示模式：
%   "stacked"    最推薦。每個通道正規化後上下錯開，並顯示通道名稱
%   "normalized" 所有通道正規化到 0~1 後疊在一起
%   "raw"        原始數值直接疊圖；不同單位/尺度時可能看不清楚

clear;
clc;
close all;

%% ========================================================================
%                            使用者設定
% ========================================================================

% ILA 每一筆有效資料的取樣週期
cfg.ila.samplePeriodNs = 14290;

% 檔案選擇視窗預設位置。
% 留空時會自動使用 repository\CSV；找不到則使用目前資料夾。
cfg.file.folder = "";
cfg.file.subfolder = "CSV";

% 圖形模式："stacked" / "normalized" / "raw"
cfg.plot.mode = "stacked";
cfg.plot.lineWidth = 1.0;
cfg.plot.darkMode = true;

% 通道名稱顯示
% true  = 在每條 stacked 波形旁直接寫「檔名 | 通道名稱」
% false = 只使用左側 Y 軸通道名稱
cfg.plot.showChannelLabels = true;
cfg.plot.channelLabelFontSize = 10;

% X 軸範圍，單位秒；[] = 自動顯示全部資料
% 例如只看 t = -5 ms ~ 50 ms：[-5e-3 50e-3]
cfg.time.xLim = [];

% 每條曲線最多畫多少點。Inf = 全部資料。
% 示波器資料很多時可改成例如 100000 加快顯示。
cfg.plot.maxPointsPerCurve = Inf;

%% ========================================================================
%                           固定主流程
% ========================================================================

%% 1. 選擇一個或多個 CSV
fileList = selectCsvFiles(cfg);
if isempty(fileList)
    fprintf('已取消選擇 CSV。\n');
    return;
end

%% 2. 讀取所有檔案並建立曲線清單
curves = struct( ...
    'fileName', {}, ...
    'fileBase', {}, ...
    'sourceType', {}, ...
    'signalName', {}, ...
    'displayName', {}, ...
    'timeSec', {}, ...
    'data', {});

fprintf('\n============================================================\n');
fprintf('CSV channel loading and t = 0 alignment\n');
fprintf('============================================================\n');

for fileIndex = 1:numel(fileList)
    filename = fileList{fileIndex};

    try
        [newCurves, info] = readCsvAsCurves(filename, cfg);
    catch ME
        warning('讀取失敗：%s\n%s', filename, ME.message);
        continue;
    end

    fprintf('\n[%d/%d] %s\n', fileIndex, numel(fileList), info.fileName);
    fprintf('  Type       : %s\n', info.sourceType);
    fprintf('  Time zero  : %s\n', info.zeroDescription);
    fprintf('  Time range : %.9f to %.9f s\n', info.timeMin, info.timeMax);
    fprintf('  Channels   : %d\n', numel(newCurves));

    for k = 1:numel(newCurves)
        fprintf('    - %s\n', newCurves(k).signalName);
        curves(end + 1) = newCurves(k); %#ok<SAGROW>
    end
end

if isempty(curves)
    error('沒有找到可畫的有效通道。');
end

%% 3. 全部畫在同一張圖
plotAllCurves(curves, cfg);

fprintf('\n============================================================\n');
fprintf('完成：%d 個檔案，共 %d 個通道。\n', numel(fileList), numel(curves));
fprintf('所有檔案的 t = 0 已對齊。\n');
fprintf('============================================================\n');

%% ========================================================================
%                             Local functions
% ========================================================================

function fileList = selectCsvFiles(cfg)
    scriptPath = fileparts(mfilename('fullpath'));
    repositoryPath = fileparts(scriptPath);

    if strlength(string(cfg.file.folder)) > 0
        startFolder = char(cfg.file.folder);
    else
        startFolder = fullfile(repositoryPath, char(cfg.file.subfolder));
        if ~isfolder(startFolder)
            startFolder = pwd;
        end
    end

    filterSpec = { ...
        '*.csv;*.CSV', 'CSV files (*.csv, *.CSV)'; ...
        '*.*', 'All files (*.*)'};

    oldFolder = pwd;
    cleanupObject = onCleanup(@() cd(oldFolder)); %#ok<NASGU>
    cd(startFolder);

    [files, selectedPath] = uigetfile( ...
        filterSpec, ...
        '選擇要一起比較的 CSV（可多選）', ...
        'MultiSelect', 'on');

    if isequal(files, 0)
        fileList = {};
        return;
    end

    if ischar(files) || isstring(files)
        files = cellstr(files);
    end

    fileList = cell(size(files));
    for k = 1:numel(files)
        fileList{k} = fullfile(selectedPath, files{k});
    end
end

function [curves, info] = readCsvAsCurves(filename, cfg)
    firstLine = readFirstLine(filename);
    isIla = contains(lower(string(firstLine)), 'sample in buffer');

    if isIla
        [dataTable, timeSec, zeroDescription] = readIlaCsv(filename, cfg);
        signalIndices = findIlaSignalColumns(dataTable);
        sourceType = 'FPGA ILA';
    else
        [dataTable, timeSec, timeColumnIndex, zeroDescription] = ...
            readOscilloscopeCsv(filename);
        signalIndices = setdiff(1:width(dataTable), timeColumnIndex, 'stable');
        sourceType = 'Oscilloscope';
    end

    [~, fileBase, fileExtension] = fileparts(filename);
    fileName = [fileBase fileExtension];

    curves = struct( ...
        'fileName', {}, ...
        'fileBase', {}, ...
        'sourceType', {}, ...
        'signalName', {}, ...
        'displayName', {}, ...
        'timeSec', {}, ...
        'data', {});

    for columnIndex = signalIndices
        rawData = dataTable{:, columnIndex};
        signalData = convertColumnToDouble(rawData);

        validRows = isfinite(timeSec) & isfinite(signalData);
        if sum(validRows) < 2
            continue;
        end

        signalName = prettySignalName(dataTable.Properties.VariableNames{columnIndex});
        displayName = sprintf('%s | %s', fileBase, signalName);

        curves(end + 1).fileName = fileName; %#ok<AGROW>
        curves(end).fileBase = fileBase;
        curves(end).sourceType = sourceType;
        curves(end).signalName = signalName;
        curves(end).displayName = displayName;
        curves(end).timeSec = timeSec(validRows);
        curves(end).data = signalData(validRows);
    end

    finiteTime = timeSec(isfinite(timeSec));
    if isempty(finiteTime)
        timeMin = NaN;
        timeMax = NaN;
    else
        timeMin = min(finiteTime);
        timeMax = max(finiteTime);
    end

    info.fileName = fileName;
    info.sourceType = sourceType;
    info.zeroDescription = zeroDescription;
    info.timeMin = timeMin;
    info.timeMax = timeMax;
end

function firstLine = readFirstLine(filename)
    fileId = fopen(filename, 'r');
    if fileId < 0
        error('無法開啟檔案：%s', filename);
    end
    cleanupObject = onCleanup(@() fclose(fileId)); %#ok<NASGU>
    firstLine = fgetl(fileId);
end

function [dataTable, timeSec, zeroDescription] = readIlaCsv(filename, cfg)
    opts = detectImportOptions(filename, 'VariableNamingRule', 'preserve');

    % Vivado ILA 第二列通常是 Radix 列，不是資料。
    opts.DataLines = [3 Inf];
    dataTable = readtable(filename, opts);

    variableNames = string(dataTable.Properties.VariableNames);

    sampleColumn = find(strcmpi(variableNames, 'Sample in Window'), 1);
    if isempty(sampleColumn)
        sampleColumn = find(strcmpi(variableNames, 'Sample in Buffer'), 1);
    end

    if isempty(sampleColumn)
        sampleNumber = (0:height(dataTable) - 1).';
    else
        sampleNumber = convertColumnToDouble(dataTable{:, sampleColumn});
    end

    triggerColumn = find(strcmpi(variableNames, 'TRIGGER'), 1);
    triggerRow = [];

    if ~isempty(triggerColumn)
        triggerData = convertColumnToDouble(dataTable{:, triggerColumn});
        triggerRow = find(isfinite(triggerData) & triggerData ~= 0, 1, 'first');
    end

    % 若沒有標準 TRIGGER，嘗試找 trigger pulse。
    if isempty(triggerRow)
        normalizedNames = normalizeNames(variableNames);
        fallbackTriggerColumn = find(contains(normalizedNames, 'triggerpulse'), 1);
        if ~isempty(fallbackTriggerColumn)
            triggerData = convertColumnToDouble(dataTable{:, fallbackTriggerColumn});
            triggerRow = find(isfinite(triggerData) & triggerData ~= 0, 1, 'first');
        end
    end

    if isempty(triggerRow)
        triggerRow = find(isfinite(sampleNumber), 1, 'first');
        warning('ILA 檔案找不到 TRIGGER = 1，改用第一筆有效資料作為 t = 0。');
        zeroDescription = 'first valid ILA sample';
    else
        zeroDescription = sprintf('ILA trigger row %d', triggerRow);
    end

    if isempty(triggerRow)
        error('ILA 檔案沒有有效 Sample 資料。');
    end

    triggerSample = sampleNumber(triggerRow);
    samplePeriodSec = cfg.ila.samplePeriodNs * 1e-9;
    timeSec = (sampleNumber - triggerSample) * samplePeriodSec;
end

function signalIndices = findIlaSignalColumns(dataTable)
    variableNames = string(dataTable.Properties.VariableNames);
    normalizedNames = normalizeNames(variableNames);

    % 這些是 ILA 本身的索引、觸發、有效旗標或擷取控制，不當作波形通道。
    exactExclude = [ ...
        "sampleinbuffer", ...
        "sampleinwindow", ...
        "trigger"];

    containsExclude = [ ...
        "valid", ...
        "capture", ...
        "triggerpulse", ...
        "ilatrigger", ...
        "probe"];

    signalIndices = [];

    for columnIndex = 1:width(dataTable)
        name = normalizedNames(columnIndex);

        if any(name == exactExclude)
            continue;
        end

        shouldExclude = false;
        for k = 1:numel(containsExclude)
            if contains(name, containsExclude(k))
                shouldExclude = true;
                break;
            end
        end

        if shouldExclude
            continue;
        end

        numericData = convertColumnToDouble(dataTable{:, columnIndex});
        if sum(isfinite(numericData)) >= 2
            signalIndices(end + 1) = columnIndex; %#ok<AGROW>
        end
    end
end

function [dataTable, timeSec, timeColumnIndex, zeroDescription] = ...
    readOscilloscopeCsv(filename)

    opts = detectImportOptions(filename, 'VariableNamingRule', 'preserve');
    dataTable = readtable(filename, opts);

    variableNames = string(dataTable.Properties.VariableNames);
    normalizedNames = normalizeNames(variableNames);

    % 優先找名稱帶有 time 或 "in s" 的欄位，找不到就使用第一欄。
    timeColumnIndex = find(contains(lower(variableNames), 'time'), 1);
    if isempty(timeColumnIndex)
        timeColumnIndex = find(contains(lower(variableNames), 'in s'), 1);
    end
    if isempty(timeColumnIndex)
        timeColumnIndex = find(contains(normalizedNames, 'seconds'), 1);
    end
    if isempty(timeColumnIndex)
        timeColumnIndex = 1;
    end

    rawTime = convertColumnToDouble(dataTable{:, timeColumnIndex});
    finiteIndex = find(isfinite(rawTime));
    if isempty(finiteIndex)
        error('示波器 CSV 找不到有效時間欄。');
    end

    [~, localZeroIndex] = min(abs(rawTime(finiteIndex)));
    zeroRow = finiteIndex(localZeroIndex);
    zeroTime = rawTime(zeroRow);

    timeSec = rawTime - zeroTime;
    zeroDescription = sprintf( ...
        'scope nearest-zero sample: original t = %.12g s', zeroTime);
end

function outputData = convertColumnToDouble(inputData)
    if isnumeric(inputData) || islogical(inputData)
        outputData = double(inputData(:));
        return;
    end

    textData = strtrim(string(inputData));
    outputData = str2double(textData);
    failedIndex = isnan(outputData) & strlength(textData) > 0;

    % 若不是十進位，嘗試當作十六進位字串。
    failedRows = find(failedIndex);
    for rowIndex = failedRows(:).'
        valueText = char(textData(rowIndex));
        valueText = regexprep(valueText, '^0[xX]', '');

        if ~isempty(regexp(valueText, '^[0-9A-Fa-f]+$', 'once'))
            try
                outputData(rowIndex) = double(hex2dec(valueText));
            catch
                outputData(rowIndex) = NaN;
            end
        end
    end

    outputData = outputData(:);
end

function normalized = normalizeNames(names)
    normalized = lower(string(names));
    normalized = regexprep(normalized, '[^a-z0-9]', '');
end

function name = prettySignalName(originalName)
    name = string(originalName);

    % 移除 Vivado hierarchy，只保留最後一層訊號名稱。
    slashParts = split(name, '/');
    name = slashParts(end);

    % 移除 bit range，例如 [11:0]、[35:0]。
    name = regexprep(name, '\[[0-9]+:[0-9]+\]$', '');

    % 常見 debug 後綴簡化。
    name = regexprep(name, '_signal_debug$', '', 'ignorecase');
    name = char(name);
end

function plotAllCurves(curves, cfg)
    numberOfCurves = numel(curves);
    mode = lower(string(cfg.plot.mode));

    figureColor = figureBackground(cfg.plot.darkMode);
    figure('Name', 'Aligned CSV channels', 'Color', figureColor);
    ax = axes;
    hold(ax, 'on');

    switch mode
        case "stacked"
            offsets = zeros(1, numberOfCurves);
            tickLabels = strings(1, numberOfCurves);

            for curveIndex = 1:numberOfCurves
                [timeToPlot, dataToPlot] = reducePoints( ...
                    curves(curveIndex).timeSec, ...
                    curves(curveIndex).data, ...
                    cfg.plot.maxPointsPerCurve);

                normalizedData = normalizeZeroToOne(dataToPlot);

                % 第一個通道放最上面。
                offset = (numberOfCurves - curveIndex) * 1.25;
                offsets(curveIndex) = offset + 0.5;
                tickLabels(curveIndex) = string(curves(curveIndex).displayName);

                plot(ax, timeToPlot, normalizedData + offset, ...
                    'LineWidth', cfg.plot.lineWidth, ...
                    'DisplayName', curves(curveIndex).displayName);
            end

            ax.YTick = offsets;
            ax.YTickLabel = tickLabels;
            ax.TickLabelInterpreter = 'none';
            ylim(ax, [-0.25, (numberOfCurves - 1) * 1.25 + 1.25]);
            ylabel(ax, 'Channels (individually normalized)');

        case "normalized"
            for curveIndex = 1:numberOfCurves
                [timeToPlot, dataToPlot] = reducePoints( ...
                    curves(curveIndex).timeSec, ...
                    curves(curveIndex).data, ...
                    cfg.plot.maxPointsPerCurve);

                plot(ax, timeToPlot, normalizeZeroToOne(dataToPlot), ...
                    'LineWidth', cfg.plot.lineWidth, ...
                    'DisplayName', curves(curveIndex).displayName);
            end

            ylabel(ax, 'Normalized amplitude (0 to 1)');
            lgd = legend(ax, 'show', 'Location', 'best', 'Interpreter', 'none');
            formatLegend(lgd, cfg.plot.darkMode);

        case "raw"
            for curveIndex = 1:numberOfCurves
                [timeToPlot, dataToPlot] = reducePoints( ...
                    curves(curveIndex).timeSec, ...
                    curves(curveIndex).data, ...
                    cfg.plot.maxPointsPerCurve);

                plot(ax, timeToPlot, dataToPlot, ...
                    'LineWidth', cfg.plot.lineWidth, ...
                    'DisplayName', curves(curveIndex).displayName);
            end

            ylabel(ax, 'Raw value');
            lgd = legend(ax, 'show', 'Location', 'best', 'Interpreter', 'none');
            formatLegend(lgd, cfg.plot.darkMode);

        otherwise
            error('cfg.plot.mode 只能是 "stacked"、"normalized" 或 "raw"。');
    end

    xline(ax, 0, '--', 't = 0', ...
        'LineWidth', 1.2, ...
        'HandleVisibility', 'off');

    xlabel(ax, 'Time (s)');
    title(ax, sprintf('Time-aligned CSV channels: %d channels', numberOfCurves));

    if ~isempty(cfg.time.xLim)
        xlim(ax, cfg.time.xLim);
    end

    % stacked 模式：除了 Y 軸通道名稱，再把名稱直接寫到每條波形旁。
    if mode == "stacked" && cfg.plot.showChannelLabels
        addChannelLabels(ax, curves, offsets, cfg);
    end

    formatAxes(ax, cfg.plot.darkMode);
    hold(ax, 'off');
end

function addChannelLabels(ax, curves, offsets, cfg)
    xLimits = xlim(ax);
    xSpan = xLimits(2) - xLimits(1);

    if xSpan <= 0
        return;
    end

    % 名稱放在圖內左側 1.5% 的位置。
    labelX = xLimits(1) + 0.015 * xSpan;

    if cfg.plot.darkMode
        textColor = 'w';
        backgroundColor = 'k';
    else
        textColor = 'k';
        backgroundColor = 'w';
    end

    for curveIndex = 1:numel(curves)
        text(ax, ...
            labelX, ...
            offsets(curveIndex), ...
            curves(curveIndex).displayName, ...
            'Interpreter', 'none', ...
            'VerticalAlignment', 'middle', ...
            'HorizontalAlignment', 'left', ...
            'FontWeight', 'bold', ...
            'FontSize', cfg.plot.channelLabelFontSize, ...
            'Color', textColor, ...
            'BackgroundColor', backgroundColor, ...
            'Margin', 2, ...
            'Clipping', 'on');
    end
end

function normalizedData = normalizeZeroToOne(data)
    data = double(data(:));
    finiteData = data(isfinite(data));

    if isempty(finiteData)
        normalizedData = NaN(size(data));
        return;
    end

    minimumValue = min(finiteData);
    maximumValue = max(finiteData);
    valueRange = maximumValue - minimumValue;

    if valueRange <= eps(max(abs([minimumValue maximumValue 1])))
        normalizedData = 0.5 * ones(size(data));
    else
        normalizedData = (data - minimumValue) / valueRange;
    end
end

function [timeOut, dataOut] = reducePoints(timeIn, dataIn, maximumPoints)
    timeIn = timeIn(:);
    dataIn = dataIn(:);

    if isinf(maximumPoints) || numel(timeIn) <= maximumPoints
        timeOut = timeIn;
        dataOut = dataIn;
        return;
    end

    indices = unique(round(linspace(1, numel(timeIn), maximumPoints)));
    timeOut = timeIn(indices);
    dataOut = dataIn(indices);
end

function formatAxes(ax, darkMode)
    grid(ax, 'on');
    box(ax, 'on');

    if darkMode
        ax.Color = 'k';
        ax.XColor = 'w';
        ax.YColor = 'w';
        ax.GridColor = [0.45 0.45 0.45];
        ax.MinorGridColor = [0.25 0.25 0.25];
        ax.Title.Color = 'w';
        ax.XLabel.Color = 'w';
        ax.YLabel.Color = 'w';
    else
        ax.Color = 'w';
        ax.XColor = 'k';
        ax.YColor = 'k';
    end
end

function formatLegend(legendHandle, darkMode)
    if darkMode
        legendHandle.TextColor = 'w';
        legendHandle.Color = 'k';
        legendHandle.EdgeColor = [0.5 0.5 0.5];
    end
end

function colorValue = figureBackground(darkMode)
    if darkMode
        colorValue = 'k';
    else
        colorValue = 'w';
    end
end
