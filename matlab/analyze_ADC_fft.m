%% analyze_ADC_fft.m
% 通用版 Vivado ILA CSV / ADC 時域與 FFT 分析
%
% 使用方式：平常只修改最上方「使用者設定」。
% 建議流程：Run -> 選 CSV -> 自動畫時域圖與 FFT。

clear;
clc;
close all;

%% ========================================================================
%                          使用者設定：平常只改這裡
% ========================================================================

% ---------- CSV 選擇 ----------
% "dialog" : 每次執行跳出視窗選 CSV（推薦）
% "latest" : 自動使用 CSV 資料夾中最後修改的 CSV
% "fixed"  : 使用 fixedName 指定的 CSV
cfg.file.mode = "dialog";
cfg.file.fixedName = "ADC_data_380.csv";

% 留空時，自動使用「程式上一層資料夾\CSV」
% 也可以填完整路徑，例如："D:\OneDrive\MATLAB\CSV"
cfg.file.folder = "";
cfg.file.subfolder = "CSV";

% ---------- 取樣與時間軸 ----------
cfg.time.samplePeriodNs = 14290;   % 每筆有效 ADC 資料間隔，單位 ns
cfg.time.shiftSec = 0;             % 水平平移，單位 s；向左為負
cfg.time.xLim = [];                % 例如 [0 0.1]；[] = 自動
cfg.time.maxPlotSamples = 10000;   % Inf = 全部資料

% ---------- 通道設定 ----------
% scale / offset 可用來把 ADC code 換算成實際物理量
% yLim = [] 代表自動
cfg.channels = struct( ...
    'id',       {'iSen', 'Vbus', 'Vac'}, ...
    'label',    {'i_sen', 'Vbus', 'Vac'}, ...
    'keywords', {{'i_sen_signal_debug','i_sen','isen','i sen','current'}, ...
                 {'Vbus_signal_debug','vbus','v_bus','v bus'}, ...
                 {'Vac_signal_debug','vac','v_ac','v ac'}}, ...
    'scale',    {1, 1, 1}, ...
    'offset',   {0, 0, 0}, ...
    'unit',     {'ADC code', 'ADC code', 'ADC code'}, ...
    'yLim',     {[], [], []}, ...
    'enabled',  {true, true, true});

% ---------- FFT 設定 ----------
cfg.fft.lowFreqMax = 500;
cfg.fft.wideFreqMax = [];          % [] = Nyquist frequency = fs/2
cfg.fft.numberOfPeaks = 10;
cfg.fft.peakSearchRange = [1 500];
cfg.fft.targetFrequencies = [60 120 180 240];
cfg.fft.targetSearchRange = 5;

% ---------- 圖形開關 ----------
cfg.plot.showTimeDomain = true;
cfg.plot.showLowFreqFFT = true;
cfg.plot.showFullFFT = true;
cfg.plot.showComparisonFFT = true;
cfg.plot.lineWidth = 1.2;
cfg.plot.darkMode = true;

% ---------- 自動輸出 PNG ----------
cfg.export.enabled = false;
cfg.export.folder = "";            % 留空 -> CSV資料夾\analysis_output
cfg.export.resolution = 200;

%% ========================================================================
%                              固定主流程
%                   正常使用時，下面通常不用修改
% ========================================================================

%% 1. 找 CSV
filename = resolveCsvFile(cfg);
if strlength(filename) == 0
    fprintf('已取消選擇 CSV。\n');
    return;
end

fprintf('\n===============================================\n');
fprintf('Selected CSV\n');
fprintf('===============================================\n');
fprintf('%s\n', filename);

%% 2. 讀取 CSV
opts = detectImportOptions(filename, 'VariableNamingRule', 'preserve');
dataTable = readtable(filename, opts);

fprintf('\n===== CSV information =====\n');
fprintf('Table rows    : %d\n', height(dataTable));
fprintf('Table columns : %d\n', width(dataTable));
fprintf('\nCSV columns:\n');
disp(dataTable.Properties.VariableNames.');

%% 3. 自動尋找通道
signals = extractSignals(dataTable, cfg.channels);
if isempty(signals)
    error('找不到任何可用 ADC 通道。請檢查 cfg.channels 的 keywords。');
end

fprintf('\n===== Selected columns =====\n');
for i = 1:numel(signals)
    fprintf('%-8s : %s\n', signals(i).label, signals(i).columnName);
end

%% 4. 只保留所有已啟用通道都有有效值的資料列
validRows = true(height(dataTable), 1);
for i = 1:numel(signals)
    validRows = validRows & isfinite(signals(i).data);
end

for i = 1:numel(signals)
    signals(i).data = signals(i).data(validRows);
end

numberOfSamples = sum(validRows);
if numberOfSamples < 16
    error('有效資料點太少，無法執行 FFT。');
end

%% 5. 建立時間軸
samplePeriod = cfg.time.samplePeriodNs * 1e-9;
fs = 1 / samplePeriod;
time = (0:numberOfSamples - 1).' * samplePeriod + cfg.time.shiftSec;
measurementTime = numberOfSamples * samplePeriod;
frequencyResolution = fs / numberOfSamples;

if isempty(cfg.fft.wideFreqMax)
    wideFreqMax = fs / 2;
else
    wideFreqMax = min(cfg.fft.wideFreqMax, fs / 2);
end

fprintf('\n===== Sampling information =====\n');
fprintf('Sample period      = %.3f ns\n', cfg.time.samplePeriodNs);
fprintf('Sampling frequency = %.6f Hz\n', fs);
fprintf('Nyquist frequency  = %.6f Hz\n', fs / 2);
fprintf('Number of samples  = %d\n', numberOfSamples);
fprintf('Measurement time   = %.6f s\n', measurementTime);
fprintf('FFT bin spacing    = %.6f Hz\n', frequencyResolution);
fprintf('Discarded rows     = %d\n', height(dataTable) - numberOfSamples);
fprintf('Time shift         = %.9f s\n', cfg.time.shiftSec);

%% 6. 時域統計
fprintf('\n===============================================\n');
fprintf('Time-domain statistics\n');
fprintf('===============================================\n');
for i = 1:numel(signals)
    printStatistics(signals(i).label, signals(i).data, signals(i).unit);
end

%% 7. 時域圖
if cfg.plot.showTimeDomain
    plotSamples = min(numberOfSamples, cfg.time.maxPlotSamples);
    figTime = figure('Name', 'ADC time-domain signals', ...
        'Color', figureBackground(cfg.plot.darkMode));
    tiledlayout(numel(signals), 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    for i = 1:numel(signals)
        nexttile;
        plot(time(1:plotSamples), signals(i).data(1:plotSamples), ...
            'LineWidth', cfg.plot.lineWidth);
        xlabel('Time (s)');
        ylabel(signals(i).unit);
        title(sprintf('%s time-domain signal', signals(i).label), 'Interpreter', 'none');

        if ~isempty(cfg.time.xLim)
            xlim(cfg.time.xLim);
        end

        channelIndex = find(strcmp({cfg.channels.id}, signals(i).id), 1);
        if ~isempty(channelIndex) && ~isempty(cfg.channels(channelIndex).yLim)
            ylim(cfg.channels(channelIndex).yLim);
        end

        formatAxes(gca, cfg.plot.darkMode);
    end

    exportFigureIfEnabled(figTime, filename, 'time_domain', cfg);
end

%% 8. FFT
for i = 1:numel(signals)
    [signals(i).frequency, signals(i).amplitude, signals(i).amplitudeDb] = ...
        calculateSingleSidedFFT(signals(i).data, fs);
end

%% 9. 低頻線性 FFT
if cfg.plot.showLowFreqFFT
    figLow = figure('Name', 'Low-frequency FFT', ...
        'Color', figureBackground(cfg.plot.darkMode));
    tiledlayout(numel(signals), 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    for i = 1:numel(signals)
        nexttile;
        plotSpectrumLinear(signals(i).frequency, signals(i).amplitude, ...
            cfg.fft.lowFreqMax, ...
            sprintf('%s low-frequency FFT spectrum', signals(i).label), ...
            signals(i).unit, cfg.fft.targetFrequencies, cfg.plot);
    end

    exportFigureIfEnabled(figLow, filename, 'fft_low_frequency', cfg);
end

%% 10. 完整單邊 FFT（dB）
if cfg.plot.showFullFFT
    figFull = figure('Name', 'Full single-sided FFT', ...
        'Color', figureBackground(cfg.plot.darkMode));
    tiledlayout(numel(signals), 1, 'TileSpacing', 'compact', 'Padding', 'compact');

    for i = 1:numel(signals)
        nexttile;
        plotSpectrumDb(signals(i).frequency, signals(i).amplitudeDb, ...
            wideFreqMax, ...
            sprintf('%s FFT spectrum: 0 to Nyquist', signals(i).label), ...
            signals(i).unit, cfg.fft.targetFrequencies, cfg.plot);
    end

    exportFigureIfEnabled(figFull, filename, 'fft_full', cfg);
end

%% 11. 多通道低頻比較
if cfg.plot.showComparisonFFT
    figCompare = figure('Name', 'ADC low-frequency spectrum comparison', ...
        'Color', figureBackground(cfg.plot.darkMode));
    hold on;

    for i = 1:numel(signals)
        idx = signals(i).frequency <= cfg.fft.lowFreqMax;
        s = stem(signals(i).frequency(idx), signals(i).amplitude(idx), ...
            'Marker', 'none', 'LineWidth', cfg.plot.lineWidth, ...
            'DisplayName', signals(i).label);
        s.BaseLine.Visible = 'off';
    end

    hold off;
    xlim([0 cfg.fft.lowFreqMax]);
    xlabel('Frequency (Hz)');
    ylabel('Amplitude');
    title('ADC low-frequency FFT comparison');
    addTargetFrequencyLines(cfg.fft.targetFrequencies, cfg.plot.darkMode);
    lgd = legend('show', 'Interpreter', 'none', 'Location', 'best');
    formatLegend(lgd, cfg.plot.darkMode);
    formatAxes(gca, cfg.plot.darkMode);
    exportFigureIfEnabled(figCompare, filename, 'fft_comparison', cfg);
end

%% 12. 指定頻率附近幅度
fprintf('\n===============================================\n');
fprintf('Specified-frequency analysis\n');
fprintf('Search range: target +/- %.2f Hz\n', cfg.fft.targetSearchRange);
fprintf('===============================================\n');
for i = 1:numel(signals)
    printTargetFrequencyAmplitude(signals(i).label, ...
        signals(i).frequency, signals(i).amplitude, ...
        cfg.fft.targetFrequencies, cfg.fft.targetSearchRange, signals(i).unit);
end

%% 13. 主要低頻峰值
fprintf('\n===============================================\n');
fprintf('Dominant low-frequency components\n');
fprintf('Search range: %.2f to %.2f Hz\n', ...
    cfg.fft.peakSearchRange(1), cfg.fft.peakSearchRange(2));
fprintf('===============================================\n');
for i = 1:numel(signals)
    printDominantFrequencies(signals(i).label, ...
        signals(i).frequency, signals(i).amplitude, ...
        cfg.fft.peakSearchRange(1), cfg.fft.peakSearchRange(2), ...
        cfg.fft.numberOfPeaks, signals(i).unit);
end

fprintf('\n===============================================\n');
fprintf('Analysis completed.\n');
fprintf('===============================================\n');

%% ========================================================================
%                              Local functions
% ========================================================================

function filename = resolveCsvFile(cfg)
    scriptPath = fileparts(mfilename('fullpath'));
    repositoryPath = fileparts(scriptPath);

    if strlength(string(cfg.file.folder)) > 0
        csvFolder = char(cfg.file.folder);
    else
        csvFolder = fullfile(repositoryPath, char(cfg.file.subfolder));
        if ~isfolder(csvFolder)
            csvFolder = pwd;
        end
    end

    switch lower(string(cfg.file.mode))
        case "dialog"
            [file, path] = uigetfile(fullfile(csvFolder, '*.csv'), '選擇要分析的 CSV');
            if isequal(file, 0)
                filename = "";
                return;
            end
            filename = string(fullfile(path, file));

        case "latest"
            files = dir(fullfile(csvFolder, '*.csv'));
            if isempty(files)
                error('資料夾內找不到 CSV：%s', csvFolder);
            end
            [~, newest] = max([files.datenum]);
            filename = string(fullfile(files(newest).folder, files(newest).name));

        case "fixed"
            filename = string(fullfile(csvFolder, char(cfg.file.fixedName)));
            if ~isfile(filename)
                error('找不到 CSV 檔案：%s', filename);
            end

        otherwise
            error('cfg.file.mode 只能是 "dialog"、"latest" 或 "fixed"。');
    end
end

function signals = extractSignals(dataTable, channelConfigs)
    signals = struct('id', {}, 'label', {}, 'columnName', {}, ...
        'unit', {}, 'data', {}, 'frequency', {}, 'amplitude', {}, 'amplitudeDb', {});

    for i = 1:numel(channelConfigs)
        channel = channelConfigs(i);
        if ~channel.enabled
            continue;
        end

        columnIndex = findColumnByKeyword(dataTable, channel.keywords);
        if isempty(columnIndex)
            warning('找不到 %s 通道，這次將略過。', channel.label);
            continue;
        end

        rawData = dataTable{:, columnIndex};
        numericData = convertColumnToDouble(rawData);
        numericData = numericData * channel.scale + channel.offset;

        signals(end + 1).id = channel.id; %#ok<AGROW>
        signals(end).label = channel.label;
        signals(end).columnName = dataTable.Properties.VariableNames{columnIndex};
        signals(end).unit = channel.unit;
        signals(end).data = numericData;
        signals(end).frequency = [];
        signals(end).amplitude = [];
        signals(end).amplitudeDb = [];
    end
end

function columnIndex = findColumnByKeyword(dataTable, keywords)
    variableNames = string(dataTable.Properties.VariableNames);
    normalizedNames = regexprep(lower(variableNames), '[^a-z0-9]', '');
    excludedWords = ["valid", "trigger", "capture", "enable", "window"];
    columnIndex = [];

    for k = 1:numel(keywords)
        keyword = regexprep(lower(string(keywords{k})), '[^a-z0-9]', '');

        exactIndex = find(normalizedNames == keyword, 1, 'first');
        if ~isempty(exactIndex)
            columnIndex = exactIndex;
            return;
        end

        candidates = find(contains(normalizedNames, keyword));
        if isempty(candidates)
            continue;
        end

        for idx = candidates(:).'
            if ~any(contains(lower(variableNames(idx)), excludedWords))
                columnIndex = idx;
                return;
            end
        end

        columnIndex = candidates(1);
        return;
    end
end

function outputData = convertColumnToDouble(inputData)
    if isnumeric(inputData) || islogical(inputData)
        outputData = double(inputData(:));
        return;
    end

    textData = strtrim(string(inputData));
    outputData = str2double(textData);
    failed = isnan(outputData) & strlength(textData) > 0;

    for idx = find(failed(:)).'
        valueText = regexprep(char(textData(idx)), '^0[xX]', '');
        if ~isempty(regexp(valueText, '^[0-9A-Fa-f]+$', 'once'))
            try
                outputData(idx) = double(hex2dec(valueText));
            catch
                outputData(idx) = NaN;
            end
        end
    end

    outputData = outputData(:);
end

function printStatistics(signalName, signalData, unitText)
    signalMinimum = min(signalData);
    signalMaximum = max(signalData);
    signalMean = mean(signalData);
    signalVpp = signalMaximum - signalMinimum;
    signalStd = std(signalData);

    fprintf('\n%s statistics:\n', signalName);
    fprintf('  min  = %.6f %s\n', signalMinimum, unitText);
    fprintf('  max  = %.6f %s\n', signalMaximum, unitText);
    fprintf('  mean = %.6f %s\n', signalMean, unitText);
    fprintf('  Vpp  = %.6f %s\n', signalVpp, unitText);
    fprintf('  std  = %.6f %s\n', signalStd, unitText);
end

function [frequency, amplitude, amplitudeDb] = calculateSingleSidedFFT(signalData, fs)
    signalData = double(signalData(:));
    n = length(signalData);
    signalAc = signalData - mean(signalData);

    sampleIndex = (0:n - 1).';
    if n > 1
        window = 0.5 - 0.5 * cos(2 * pi * sampleIndex / (n - 1));
    else
        window = 1;
    end

    windowedSignal = signalAc .* window;
    coherentGain = sum(window) / n;
    fftResult = fft(windowedSignal);
    twoSidedAmplitude = abs(fftResult) / (n * coherentGain);

    singleSideLength = floor(n / 2) + 1;
    amplitude = twoSidedAmplitude(1:singleSideLength);

    if rem(n, 2) == 0
        if singleSideLength > 2
            amplitude(2:end - 1) = 2 * amplitude(2:end - 1);
        end
    elseif singleSideLength > 1
        amplitude(2:end) = 2 * amplitude(2:end);
    end

    frequency = (0:singleSideLength - 1).' * fs / n;
    amplitudeDb = 20 * log10(amplitude + eps);
end

function plotSpectrumLinear(frequency, amplitude, maximumFrequency, ...
    plotTitle, unitText, targetFrequencies, plotCfg)

    idx = frequency <= maximumFrequency;
    s = stem(frequency(idx), amplitude(idx), 'Marker', 'none', ...
        'LineWidth', plotCfg.lineWidth);
    s.BaseLine.Visible = 'off';
    xlim([0 maximumFrequency]);
    xlabel('Frequency (Hz)');
    ylabel(sprintf('Amplitude (%s)', unitText));
    title(plotTitle, 'Interpreter', 'none');
    addTargetFrequencyLines(targetFrequencies, plotCfg.darkMode);
    formatAxes(gca, plotCfg.darkMode);
end

function plotSpectrumDb(frequency, amplitudeDb, maximumFrequency, ...
    plotTitle, unitText, targetFrequencies, plotCfg)

    idx = frequency <= maximumFrequency;
    plot(frequency(idx), amplitudeDb(idx), 'LineWidth', plotCfg.lineWidth);
    xlim([0 maximumFrequency]);
    xlabel('Frequency (Hz)');
    ylabel(sprintf('Magnitude (dB re 1 %s)', unitText));
    title(plotTitle, 'Interpreter', 'none');
    addTargetFrequencyLines(targetFrequencies, plotCfg.darkMode);
    formatAxes(gca, plotCfg.darkMode);
end

function addTargetFrequencyLines(targetFrequencies, darkMode)
    if darkMode
        lineColor = [0.8 0.8 0.8];
        labelColor = 'w';
    else
        lineColor = [0.4 0.4 0.4];
        labelColor = 'k';
    end

    for f = targetFrequencies
        xline(f, '--', sprintf('%g Hz', f), 'Color', lineColor, ...
            'LabelColor', labelColor, 'HandleVisibility', 'off');
    end
end

function printTargetFrequencyAmplitude(signalName, frequency, amplitude, ...
    targetFrequencies, searchRange, unitText)

    fprintf('\n%s:\n', signalName);
    fprintf('  Target      Actual peak      Amplitude\n');

    for target = targetFrequencies
        idx = frequency >= target - searchRange & frequency <= target + searchRange;
        if any(idx)
            localFrequency = frequency(idx);
            localAmplitude = amplitude(idx);
            [peakAmplitude, peakIndex] = max(localAmplitude);
            actualPeakFrequency = localFrequency(peakIndex);
            fprintf('  %6.1f Hz    %9.3f Hz      %10.6f %s\n', ...
                target, actualPeakFrequency, peakAmplitude, unitText);
        else
            fprintf('  %6.1f Hz    no FFT bin available\n', target);
        end
    end
end

function printDominantFrequencies(signalName, frequency, amplitude, ...
    minimumFrequency, maximumFrequency, numberOfPeaks, unitText)

    idx = frequency >= minimumFrequency & frequency <= maximumFrequency;
    searchFrequency = frequency(idx);
    searchAmplitude = amplitude(idx);

    if length(searchAmplitude) < 3
        fprintf('\n%s: 頻率資料點不足。\n', signalName);
        return;
    end

    localMaximum = searchAmplitude(2:end - 1) > searchAmplitude(1:end - 2) & ...
                   searchAmplitude(2:end - 1) >= searchAmplitude(3:end);
    peakIndices = find(localMaximum) + 1;

    if isempty(peakIndices)
        fprintf('\n%s: 找不到局部峰值。\n', signalName);
        return;
    end

    peakAmplitudes = searchAmplitude(peakIndices);
    peakFrequencies = searchFrequency(peakIndices);
    [sortedAmplitudes, order] = sort(peakAmplitudes, 'descend');
    sortedFrequencies = peakFrequencies(order);
    count = min(numberOfPeaks, length(sortedAmplitudes));

    fprintf('\n%s dominant components:\n', signalName);
    fprintf('  Rank      Frequency       Amplitude\n');
    for p = 1:count
        fprintf('  %4d      %9.3f Hz     %10.6f %s\n', ...
            p, sortedFrequencies(p), sortedAmplitudes(p), unitText);
    end
end

function formatAxes(ax, darkMode)
    grid(ax, 'on');
    box(ax, 'on');

    if darkMode
        ax.Color = 'k';
        ax.XColor = 'w';
        ax.YColor = 'w';
        ax.GridColor = [0.5 0.5 0.5];
        ax.MinorGridColor = [0.3 0.3 0.3];
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

function exportFigureIfEnabled(figureHandle, csvFilename, suffix, cfg)
    if ~cfg.export.enabled
        return;
    end

    [csvFolder, csvBaseName, ~] = fileparts(csvFilename);

    if strlength(string(cfg.export.folder)) > 0
        outputFolder = char(cfg.export.folder);
    else
        outputFolder = fullfile(csvFolder, 'analysis_output');
    end

    if ~isfolder(outputFolder)
        mkdir(outputFolder);
    end

    outputFile = fullfile(outputFolder, sprintf('%s_%s.png', csvBaseName, suffix));
    exportgraphics(figureHandle, outputFile, 'Resolution', cfg.export.resolution);
    fprintf('Saved figure: %s\n', outputFile);
end
