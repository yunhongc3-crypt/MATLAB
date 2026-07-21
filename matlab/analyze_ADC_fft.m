%% analyze_ADC_fft.m
% Vivado ILA 匯出 CSV 的 ADC 頻譜分析
% 分析 i_sen、Vbus、Vac 三個通道
%
% 預設資料夾結構：
% MATLAB/
%   CSV/ADC_data_380.csv
%   matlab/analyze_ADC_fft.m

clear;
clc;
close all;

%% ==================== 使用者設定 ====================
csvFileName = 'ADC_data_380.csv';

% 每一筆 ADC 有效資料的時間間隔
samplePeriodNs = 14290;                 % 單位 ns
samplePeriod = samplePeriodNs * 1e-9;  % 換算成秒
fs = 1 / samplePeriod;                 % 有效取樣頻率 Hz

lowFreqMax = 500;                      % 低頻頻譜上限 Hz
wideFreqMax = fs / 2;                  % 完整單邊頻譜，約 34.99 kHz
maxTimePlotSamples = 10000;            % 時域圖最多顯示點數
numberOfPeaks = 10;                    % 顯示主要峰值數量
peakSearchRange = [1, 500];            % 峰值搜尋範圍 Hz
targetFrequencies = [60, 120, 180, 240];
targetSearchRange = 5;                 % 指定頻率搜尋範圍 +/- Hz

%% ==================== 建立 CSV 路徑 ====================
scriptPath = fileparts(mfilename('fullpath'));
repositoryPath = fileparts(scriptPath);
filename = fullfile(repositoryPath, 'CSV', csvFileName);

if ~isfile(filename)
    error('找不到 CSV 檔案：%s', filename);
end

%% ==================== 讀取 CSV ====================
opts = detectImportOptions(filename, 'VariableNamingRule', 'preserve');
dataTable = readtable(filename, opts);

fprintf('\n===== CSV information =====\n');
fprintf('File name       : %s\n', filename);
fprintf('Table rows      : %d\n', height(dataTable));
fprintf('Table columns   : %d\n', width(dataTable));
fprintf('\nCSV columns:\n');
disp(dataTable.Properties.VariableNames.');

%% ==================== 尋找通道欄位 ====================
iSenColumn = findColumnByKeyword(dataTable, {'i_sen', 'isen', 'i sen'});
vbusColumn = findColumnByKeyword(dataTable, {'vbus', 'v_bus', 'v bus'});
vacColumn  = findColumnByKeyword(dataTable, {'vac', 'v_ac', 'v ac'});

fprintf('\n===== Selected columns =====\n');
fprintf('i_sen : %s\n', dataTable.Properties.VariableNames{iSenColumn});
fprintf('Vbus  : %s\n', dataTable.Properties.VariableNames{vbusColumn});
fprintf('Vac   : %s\n', dataTable.Properties.VariableNames{vacColumn});

%% ==================== 轉成數值 ====================
iSenCode = convertColumnToDouble(dataTable{:, iSenColumn});
vbusCode = convertColumnToDouble(dataTable{:, vbusColumn});
vacCode  = convertColumnToDouble(dataTable{:, vacColumn});

validIndex = isfinite(iSenCode) & isfinite(vbusCode) & isfinite(vacCode);
iSenCode = iSenCode(validIndex);
vbusCode = vbusCode(validIndex);
vacCode  = vacCode(validIndex);

numberOfSamples = length(iSenCode);
if numberOfSamples < 16
    error('有效資料點太少，無法執行 FFT。');
end

time = (0:numberOfSamples - 1).' * samplePeriod;
measurementTime = numberOfSamples * samplePeriod;
frequencyResolution = fs / numberOfSamples;

fprintf('\n===== Sampling information =====\n');
fprintf('Sample period      = %.3f ns\n', samplePeriodNs);
fprintf('Sampling frequency = %.6f Hz\n', fs);
fprintf('Nyquist frequency  = %.6f Hz\n', fs/2);
fprintf('Number of samples  = %d\n', numberOfSamples);
fprintf('Measurement time   = %.6f s\n', measurementTime);
fprintf('FFT bin spacing    = %.6f Hz\n', frequencyResolution);

%% ==================== 時域統計 ====================
printStatistics('i_sen', iSenCode);
printStatistics('Vbus', vbusCode);
printStatistics('Vac', vacCode);

%% ==================== 時域圖 ====================
plotSamples = min(numberOfSamples, maxTimePlotSamples);

figure('Name', 'ADC time-domain signals', 'Color', 'k');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(time(1:plotSamples), iSenCode(1:plotSamples), 'LineWidth', 1);
formatDarkAxes(gca);
xlabel('Time (s)');
ylabel('ADC code');
title('i\_sen time-domain signal');

nexttile;
plot(time(1:plotSamples), vbusCode(1:plotSamples), 'LineWidth', 1);
formatDarkAxes(gca);
xlabel('Time (s)');
ylabel('ADC code');
title('Vbus time-domain signal');

nexttile;
plot(time(1:plotSamples), vacCode(1:plotSamples), 'LineWidth', 1);
formatDarkAxes(gca);
xlabel('Time (s)');
ylabel('ADC code');
title('Vac time-domain signal');

%% ==================== FFT ====================
[iSenFreq, iSenAmplitude, iSenAmplitudeDb] = calculateSingleSidedFFT(iSenCode, fs);
[vbusFreq, vbusAmplitude, vbusAmplitudeDb] = calculateSingleSidedFFT(vbusCode, fs);
[vacFreq, vacAmplitude, vacAmplitudeDb] = calculateSingleSidedFFT(vacCode, fs);

%% ==================== 低頻線性頻譜 ====================
figure('Name', 'Low-frequency FFT', 'Color', 'k');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plotSpectrumLinear(iSenFreq, iSenAmplitude, lowFreqMax, 'i\_sen FFT spectrum');
nexttile;
plotSpectrumLinear(vbusFreq, vbusAmplitude, lowFreqMax, 'Vbus FFT spectrum');
nexttile;
plotSpectrumLinear(vacFreq, vacAmplitude, lowFreqMax, 'Vac FFT spectrum');

%% ==================== 完整單邊 dB 頻譜 ====================
figure('Name', 'Full single-sided FFT', 'Color', 'k');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plotSpectrumDb(iSenFreq, iSenAmplitudeDb, wideFreqMax, 'i\_sen FFT spectrum: 0 to Nyquist');
nexttile;
plotSpectrumDb(vbusFreq, vbusAmplitudeDb, wideFreqMax, 'Vbus FFT spectrum: 0 to Nyquist');
nexttile;
plotSpectrumDb(vacFreq, vacAmplitudeDb, wideFreqMax, 'Vac FFT spectrum: 0 to Nyquist');

%% ==================== 三通道低頻比較 ====================
figure('Name', 'ADC low-frequency spectrum comparison', 'Color', 'k');
plot(iSenFreq, iSenAmplitude, 'LineWidth', 1);
hold on;
plot(vbusFreq, vbusAmplitude, 'LineWidth', 1);
plot(vacFreq, vacAmplitude, 'LineWidth', 1);
formatDarkAxes(gca);
xlim([0 lowFreqMax]);
xlabel('Frequency (Hz)');
ylabel('Amplitude (ADC code)');
title('ADC low-frequency FFT comparison');
legend('i\_sen', 'Vbus', 'Vac', 'Location', 'best', 'TextColor', 'w', 'Color', 'k');

for targetFrequency = targetFrequencies
    xline(targetFrequency, '--', sprintf('%g Hz', targetFrequency), ...
        'Color', [0.8 0.8 0.8], 'LabelColor', 'w');
end

%% ==================== 指定頻率附近幅度 ====================
fprintf('\n===============================================\n');
fprintf('Specified-frequency analysis\n');
fprintf('Search range: target +/- %.2f Hz\n', targetSearchRange);
fprintf('===============================================\n');

printTargetFrequencyAmplitude('i_sen', iSenFreq, iSenAmplitude, ...
    targetFrequencies, targetSearchRange);
printTargetFrequencyAmplitude('Vbus', vbusFreq, vbusAmplitude, ...
    targetFrequencies, targetSearchRange);
printTargetFrequencyAmplitude('Vac', vacFreq, vacAmplitude, ...
    targetFrequencies, targetSearchRange);

%% ==================== 主要低頻峰值 ====================
fprintf('\n===============================================\n');
fprintf('Dominant low-frequency components\n');
fprintf('Search range: %.2f to %.2f Hz\n', ...
    peakSearchRange(1), peakSearchRange(2));
fprintf('===============================================\n');

printDominantFrequencies('i_sen', iSenFreq, iSenAmplitude, ...
    peakSearchRange(1), peakSearchRange(2), numberOfPeaks);
printDominantFrequencies('Vbus', vbusFreq, vbusAmplitude, ...
    peakSearchRange(1), peakSearchRange(2), numberOfPeaks);
printDominantFrequencies('Vac', vacFreq, vacAmplitude, ...
    peakSearchRange(1), peakSearchRange(2), numberOfPeaks);

fprintf('\nFFT analysis completed.\n');

%% =========================================================
% Local functions
% =========================================================
function columnIndex = findColumnByKeyword(dataTable, keywords)
    variableNames = dataTable.Properties.VariableNames;
    normalizedNames = lower(variableNames);
    normalizedNames = erase(normalizedNames, {'_', ' ', '-'});
    columnIndex = [];

    for keywordIndex = 1:length(keywords)
        keyword = lower(keywords{keywordIndex});
        keyword = erase(keyword, {'_', ' ', '-'});
        matchedIndex = find(contains(normalizedNames, keyword), 1, 'first');
        if ~isempty(matchedIndex)
            columnIndex = matchedIndex;
            break;
        end
    end

    if isempty(columnIndex)
        fprintf('\n找不到指定欄位。CSV 欄位如下：\n');
        disp(variableNames.');
        error('請修改欄位關鍵字。');
    end
end

function outputData = convertColumnToDouble(inputData)
    if isnumeric(inputData) || islogical(inputData)
        outputData = double(inputData);
    else
        outputData = str2double(string(inputData));
    end
    outputData = outputData(:);
end

function printStatistics(signalName, signalData)
    signalMinimum = min(signalData);
    signalMaximum = max(signalData);
    signalMean = mean(signalData);
    signalVpp = signalMaximum - signalMinimum;
    signalStd = std(signalData);

    fprintf('\n%s statistics:\n', signalName);
    fprintf('  min  = %.6f ADC code\n', signalMinimum);
    fprintf('  max  = %.6f ADC code\n', signalMaximum);
    fprintf('  mean = %.6f ADC code\n', signalMean);
    fprintf('  Vpp  = %.6f ADC code\n', signalVpp);
    fprintf('  std  = %.6f ADC code\n', signalStd);
end

function [frequency, amplitude, amplitudeDb] = calculateSingleSidedFFT(signalData, fs)
    signalData = double(signalData(:));
    numberOfSamples = length(signalData);
    signalAc = signalData - mean(signalData);

    sampleIndex = (0:numberOfSamples - 1).';
    if numberOfSamples > 1
        window = 0.5 - 0.5*cos(2*pi*sampleIndex/(numberOfSamples - 1));
    else
        window = 1;
    end

    windowedSignal = signalAc .* window;
    coherentGain = sum(window) / numberOfSamples;
    fftResult = fft(windowedSignal);
    twoSidedAmplitude = abs(fftResult) / (numberOfSamples * coherentGain);

    singleSideLength = floor(numberOfSamples/2) + 1;
    amplitude = twoSidedAmplitude(1:singleSideLength);

    if rem(numberOfSamples, 2) == 0
        if singleSideLength > 2
            amplitude(2:end - 1) = 2 * amplitude(2:end - 1);
        end
    elseif singleSideLength > 1
        amplitude(2:end) = 2 * amplitude(2:end);
    end

    frequency = (0:singleSideLength - 1).' * fs / numberOfSamples;
    amplitudeDb = 20*log10(amplitude + eps);
end

function plotSpectrumLinear(frequency, amplitude, maximumFrequency, plotTitle)
    validIndex = frequency <= maximumFrequency;
    plot(frequency(validIndex), amplitude(validIndex), 'LineWidth', 1);
    formatDarkAxes(gca);
    xlim([0 maximumFrequency]);
    xlabel('Frequency (Hz)');
    ylabel('Amplitude (ADC code)');
    title(plotTitle);
    xline(60, '--', '60 Hz', 'Color', [0.8 0.8 0.8], 'LabelColor', 'w');
    xline(120, '--', '120 Hz', 'Color', [0.8 0.8 0.8], 'LabelColor', 'w');
end

function plotSpectrumDb(frequency, amplitudeDb, maximumFrequency, plotTitle)
    validIndex = frequency <= maximumFrequency;
    plot(frequency(validIndex), amplitudeDb(validIndex), 'LineWidth', 1);
    formatDarkAxes(gca);
    xlim([0 maximumFrequency]);
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (dB re 1 ADC code)');
    title(plotTitle);
    xline(60, '--', '60 Hz', 'Color', [0.8 0.8 0.8], 'LabelColor', 'w');
    xline(120, '--', '120 Hz', 'Color', [0.8 0.8 0.8], 'LabelColor', 'w');
end

function printTargetFrequencyAmplitude(signalName, frequency, amplitude, ...
    targetFrequencies, searchRange)

    fprintf('\n%s:\n', signalName);
    fprintf('  Target      Actual peak      Amplitude\n');

    for targetFrequency = targetFrequencies
        searchIndex = frequency >= targetFrequency - searchRange & ...
                      frequency <= targetFrequency + searchRange;

        if any(searchIndex)
            localFrequency = frequency(searchIndex);
            localAmplitude = amplitude(searchIndex);
            [peakAmplitude, localPeakIndex] = max(localAmplitude);
            actualPeakFrequency = localFrequency(localPeakIndex);

            fprintf('  %6.1f Hz    %9.3f Hz      %10.6f code\n', ...
                targetFrequency, actualPeakFrequency, peakAmplitude);
        else
            fprintf('  %6.1f Hz    no FFT bin available\n', targetFrequency);
        end
    end
end

function printDominantFrequencies(signalName, frequency, amplitude, ...
    minimumFrequency, maximumFrequency, numberOfPeaks)

    searchIndex = frequency >= minimumFrequency & frequency <= maximumFrequency;
    searchFrequency = frequency(searchIndex);
    searchAmplitude = amplitude(searchIndex);

    if length(searchAmplitude) < 3
        fprintf('\n%s: 頻率資料點不足。\n', signalName);
        return;
    end

    localMaximumIndex = searchAmplitude(2:end - 1) > searchAmplitude(1:end - 2) & ...
                        searchAmplitude(2:end - 1) >= searchAmplitude(3:end);
    peakIndices = find(localMaximumIndex) + 1;

    if isempty(peakIndices)
        fprintf('\n%s: 找不到局部峰值。\n', signalName);
        return;
    end

    peakAmplitudes = searchAmplitude(peakIndices);
    peakFrequencies = searchFrequency(peakIndices);
    [sortedAmplitudes, sortOrder] = sort(peakAmplitudes, 'descend');
    sortedFrequencies = peakFrequencies(sortOrder);
    numberToDisplay = min(numberOfPeaks, length(sortedAmplitudes));

    fprintf('\n%s dominant components:\n', signalName);
    fprintf('  Rank      Frequency       Amplitude\n');

    for peakNumber = 1:numberToDisplay
        fprintf('  %4d      %9.3f Hz     %10.6f code\n', ...
            peakNumber, sortedFrequencies(peakNumber), sortedAmplitudes(peakNumber));
    end
end

function formatDarkAxes(ax)
    grid(ax, 'on');
    ax.Color = 'k';
    ax.XColor = 'w';
    ax.YColor = 'w';
    ax.GridColor = [0.5 0.5 0.5];
    ax.MinorGridColor = [0.3 0.3 0.3];
    ax.Title.Color = 'w';
    ax.XLabel.Color = 'w';
    ax.YLabel.Color = 'w';
end
