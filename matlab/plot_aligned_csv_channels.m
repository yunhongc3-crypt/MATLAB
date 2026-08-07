%% plot_aligned_csv_channels.m
% 多格式 CSV 時域比較工具：所有通道畫在同一張 Figure，並將 t = 0 對齊。
%
% 支援：
%   1. FPGA ILA：Vbus / Vac / i_sen
%   2. FPGA ILA：Voltage_loop / Current_loop / PWM / CCM_mode 等控制訊號
%   3. 示波器 CSV：使用檔案內建的時間欄
%
% 時間對齊：
%   - FPGA ILA：TRIGGER = 1 的樣本定義為 t = 0
%   - 示波器：最接近 0 秒的樣本平移到精確 t = 0
%
% 使用方式：
%   Run -> Ctrl 多選 CSV -> Open
%
% 預設 stacked 模式會：
%   - 每個通道各自正規化後上下排列
%   - 波形左側直接顯示「檔名 | 通道名稱」
%   - 右側固定顯示 Legend，避免通道名稱看不到

clear;
clc;
close all;

%% ========================================================================
%                              使用者設定
% ========================================================================

% FPGA ILA 固定取樣週期
cfg.ila.samplePeriodNs = 14290;

% CSV 選擇視窗起始資料夾。
% 留空時自動使用 repository\CSV；找不到時使用目前資料夾。
cfg.file.folder = "";
cfg.file.subfolder = "CSV";

% 顯示模式：
%   "stacked"    各通道正規化後上下排列（推薦）
%   "normalized" 各通道正規化到 0~1 後疊在一起
%   "raw"        直接用原始值疊圖
cfg.plot.mode = "stacked";

cfg.plot.lineWidth = 1.0;
cfg.plot.darkMode = true;

% 通道名稱
cfg.plot.showInlineLabels = true;   % 波形左側直接寫名稱
cfg.plot.showLegend = true;         % 右側固定 Legend
cfg.plot.channelLabelFontSize = 11;
cfg.plot.legendFontSize = 10;

% X 軸範圍，單位秒；[] = 自動
% 範例：[-5e-3 50e-3]
cfg.time.xLim = [];

% 每條曲線最多畫多少點；Inf = 全部
cfg.plot.maxPointsPerCurve = Inf;

%% ========================================================================
%                              固定主流程
% ========================================================================

fileList = selectCsvFiles(cfg);

if isempty(fileList)
    fprintf('已取消選擇 CSV。\n');
    return;
end

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
        fprintf('    - %s\n', newCurves(k).displayName);
        curves(end + 1) = newCurves(k); %#ok<SAGROW>
    end
end

if isempty(curves)
    error('沒有找到可以畫的有效通道。');
end

plotAllCurves(curves, cfg);

fprintf('\n============================================================\n');
fprintf('完成：共 %d 個通道。\n', numel(curves));
fprintf('所有檔案的 t = 0 已對齊。\n');
fprintf('============================================================\n');

%% ========================================================================
%                              Local functions
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

    oldFolder = pwd;
    cleanupObject = onCleanup(@() cd(oldFolder)); %#ok<NASGU>
    cd(startFolder);

    filterSpec = { ...
        '*.csv;*.CSV', 'CSV files (*.csv, *.CSV)'; ...
        '*.*', 'All files (*.*)'};

    [files, selectedPath] = uigetfile( ...
        filterSpec, ...
        '選擇要一起比較的 CSV（可按 Ctrl 多選）', ...
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

    [~, fileBase, extension] = fileparts(filename);
    fileName = [fileBase extension];

    curves = struct( ...
        'fileName', {}, ...
        'fileBase', {}, ...
        'sourceType', {}, ...
        'signalName', {}, ...
        'displayName', {}, ...
        'timeSec', {}, ...
        'data', {});

    for columnIndex = signalIndices
        signalData = convertColumnToDouble(dataTable{:, columnIndex});
        validRows = isfinite(timeSec) & isfinite(signalData);

        if sum(validRows) < 2
            continue;
        end

        signalName = prettySignalName( ...
            dataTable.Properties.VariableNames{columnIndex});

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

    info.fileName = fileName;
    info.sourceType = sourceType;
    info.zeroDescription = zeroDescription;

    if isempty(finiteTime)
        info.timeMin = NaN;
        info.timeMax = NaN;
    else
        info.timeMin = min(finiteTime);
        info.timeMax = max(finiteTime);
    end
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

    % Vivado ILA 第二列通常是 Radix 列，因此資料從第三列開始。
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

    triggerRow = [];
    triggerColumn = find(strcmpi(variableNames, 'TRIGGER'), 1);

    if ~isempty(triggerColumn)
        triggerData = convertColumnToDouble(dataTable{:, triggerColumn});
        triggerRow = find(isfinite(triggerData) & triggerData ~= 0, 1, 'first');
    end

    % 若標準 TRIGGER 不存在，再找 trigger pulse。
    if isempty(triggerRow)
        normalizedNames = normalizeNames(variableNames);
        triggerPulseColumn = find(contains(normalizedNames, 'triggerpulse'), 1);

        if ~isempty(triggerPulseColumn)
            triggerData = convertColumnToDouble( ...
                dataTable{:, triggerPulseColumn});
            triggerRow = find( ...
                isfinite(triggerData) & triggerData ~= 0, ...
                1, ...
                'first');
        end
    end

    if isempty(triggerRow)
        triggerRow = find(isfinite(sampleNumber), 1, 'first');
        zeroDescription = 'first valid ILA sample (TRIGGER not found)';
        warning('ILA 找不到 TRIGGER = 1，改用第一筆有效資料作為 t = 0。');
    else
        zeroDescription = sprintf('ILA trigger row %d', triggerRow);
    end

    if isempty(triggerRow)
        error('ILA 沒有有效 Sample 資料。');
    end

    triggerSample = sampleNumber(triggerRow);
    samplePeriodSec = cfg.ila.samplePeriodNs * 1e-9;
    timeSec = (sampleNumber - triggerSample) * samplePeriodSec;
end

function signalIndices = findIlaSignalColumns(dataTable)
    variableNames = string(dataTable.Properties.VariableNames);
    normalizedNames = normalizeNames(variableNames);

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
        currentName = normalizedNames(columnIndex);

        if any(currentName == exactExclude)
            continue;
        end

        if any(contains(currentName, containsExclude))
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
    finiteRows = find(isfinite(rawTime));

    if isempty(finiteRows)
        error('示波器 CSV 找不到有效時間欄。');
    end

    [~, localZeroIndex] = min(abs(rawTime(finiteRows)));
    zeroRow = finiteRows(localZeroIndex);
    originalZeroTime = rawTime(zeroRow);

    timeSec = rawTime - originalZeroTime;

    zeroDescription = sprintf( ...
        'scope nearest-zero sample: original t = %.12g s', ...
        originalZeroTime);
end

function outputData = convertColumnToDouble(inputData)
    if isnumeric(inputData) || islogical(inputData)
        outputData = double(inputData(:));
        return;
    end

    textData = strtrim(string(inputData));
    outputData = str2double(textData);

    failedRows = find(isnan(outputData) & strlength(textData) > 0);

    % 十進位轉換失敗時，再嘗試十六進位。
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

    % Vivado hierarchy 只保留最後一層。
    hierarchyParts = split(name, '/');
    name = hierarchyParts(end);

    % 移除 [11:0]、[35:0] 等 bit range。
    name = regexprep(name, '\[[0-9]+:[0-9]+\]$', '');

    % 簡化常見 debug 後綴。
    name = regexprep(name, '_signal_debug$', '', 'ignorecase');

    name = char(name);
end

function plotAllCurves(curves, cfg)
    numberOfCurves = numel(curves);
    mode = lower(string(cfg.plot.mode));

    fig = figure( ...
        'Name', 'Aligned CSV channels', ...
        'Color', figureBackground(cfg.plot.darkMode));

    ax = axes(fig);
    hold(ax, 'on');

    lineHandles = gobjects(numberOfCurves, 1);
    offsets = zeros(numberOfCurves, 1);

    switch mode
        case "stacked"
            for curveIndex = 1:numberOfCurves
                [timeToPlot, dataToPlot] = reducePoints( ...
                    curves(curveIndex).timeSec, ...
                    curves(curveIndex).data, ...
                    cfg.plot.maxPointsPerCurve);

                normalizedData = normalizeZeroToOne(dataToPlot);

                % 第一條放最上面。
                offset = (numberOfCurves - curveIndex) * 1.35;
                offsets(curveIndex) = offset + 0.5;

                lineHandles(curveIndex) = plot( ...
                    ax, ...
                    timeToPlot, ...
                    normalizedData + offset, ...
                    'LineWidth', cfg.plot.lineWidth, ...
                    'DisplayName', curves(curveIndex).displayName);
            end

            ylim(ax, [-0.30, (numberOfCurves - 1) * 1.35 + 1.30]);

            % Y 軸也保留完整名稱，作為第三層保險。
            ax.YTick = offsets;
            ax.YTickLabel = {curves.displayName};
            ax.TickLabelInterpreter = 'none';
            ylabel(ax, 'Channels');

        case "normalized"
            for curveIndex = 1:numberOfCurves
                [timeToPlot, dataToPlot] = reducePoints( ...
                    curves(curveIndex).timeSec, ...
                    curves(curveIndex).data, ...
                    cfg.plot.maxPointsPerCurve);

                lineHandles(curveIndex) = plot( ...
                    ax, ...
                    timeToPlot, ...
                    normalizeZeroToOne(dataToPlot), ...
                    'LineWidth', cfg.plot.lineWidth, ...
                    'DisplayName', curves(curveIndex).displayName);
            end

            ylabel(ax, 'Normalized amplitude (0 to 1)');

        case "raw"
            for curveIndex = 1:numberOfCurves
                [timeToPlot, dataToPlot] = reducePoints( ...
                    curves(curveIndex).timeSec, ...
                    curves(curveIndex).data, ...
                    cfg.plot.maxPointsPerCurve);

                lineHandles(curveIndex) = plot( ...
                    ax, ...
                    timeToPlot, ...
                    dataToPlot, ...
                    'LineWidth', cfg.plot.lineWidth, ...
                    'DisplayName', curves(curveIndex).displayName);
            end

            ylabel(ax, 'Raw value');

        otherwise
            error('cfg.plot.mode 只能是 "stacked"、"normalized" 或 "raw"。');
    end

    xlabel(ax, 'Time (s)');
    title(ax, sprintf('Time-aligned CSV channels (%d channels)', numberOfCurves));

    if ~isempty(cfg.time.xLim)
        xlim(ax, cfg.time.xLim);
    end

    % t = 0 對齊線
    xline(ax, 0, '--', 't = 0', ...
        'LineWidth', 1.3, ...
        'HandleVisibility', 'off');

    formatAxes(ax, cfg.plot.darkMode);

    % stacked 模式：名稱直接寫進圖內。
    if mode == "stacked" && cfg.plot.showInlineLabels
        addInlineChannelLabels(ax, curves, offsets, cfg);
    end

    % 所有模式右側都可以固定顯示 Legend。
    if cfg.plot.showLegend
        lgd = legend( ...
            ax, ...
            lineHandles, ...
            {curves.displayName}, ...
            'Location', 'eastoutside', ...
            'Interpreter', 'none', ...
            'FontSize', cfg.plot.legendFontSize);

        formatLegend(lgd, cfg.plot.darkMode);
    end

    hold(ax, 'off');
end

function addInlineChannelLabels(ax, curves, offsets, cfg)
    xLimits = xlim(ax);
    xSpan = xLimits(2) - xLimits(1);

    if ~isfinite(xSpan) || xSpan <= 0
        return;
    end

    % 放在目前畫面最左側往內 1.2%。
    labelX = xLimits(1) + 0.012 * xSpan;

    if cfg.plot.darkMode
        textColor = 'w';
        backgroundColor = [0.05 0.05 0.05];
        edgeColor = [0.35 0.35 0.35];
    else
        textColor = 'k';
        backgroundColor = [1 1 1];
        edgeColor = [0.75 0.75 0.75];
    end

    for curveIndex = 1:numel(curves)
        text( ...
            ax, ...
            labelX, ...
            offsets(curveIndex), ...
            curves(curveIndex).displayName, ...
            'Interpreter', 'none', ...
            'FontSize', cfg.plot.channelLabelFontSize, ...
            'FontWeight', 'bold', ...
            'Color', textColor, ...
            'BackgroundColor', backgroundColor, ...
            'EdgeColor', edgeColor, ...
            'Margin', 3, ...
            'VerticalAlignment', 'middle', ...
            'HorizontalAlignment', 'left', ...
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
        ax.Color = [0.07 0.07 0.07];
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
        legendHandle.Color = [0.07 0.07 0.07];
        legendHandle.EdgeColor = [0.45 0.45 0.45];
    else
        legendHandle.TextColor = 'k';
        legendHandle.Color = 'w';
    end
end

function colorValue = figureBackground(darkMode)
    if darkMode
        colorValue = 'k';
    else
        colorValue = 'w';
    end
end
