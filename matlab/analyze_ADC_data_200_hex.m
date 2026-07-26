%% analyze_ADC_data_200_hex.m
% Analyze ADC_data_200_bk_2.2u_Vac_s_0723.csv exported by Vivado ILA.
% The CSV Radix row is used automatically:
%   UNSIGNED columns -> decimal parsing
%   HEX columns      -> hexadecimal parsing

clear;
clc;
close all;

%% User settings
csvFileName = 'ADC_data_200_bk_2.2u_Vac_s_0723.csv';
samplePeriodNs = 14290;
lowFrequencyMax = 500;
numberOfPeaks = 10;

samplePeriod = samplePeriodNs * 1e-9;
fs = 1 / samplePeriod;

%% File path
scriptPath = fileparts(mfilename('fullpath'));
repositoryPath = fileparts(scriptPath);
filename = fullfile(repositoryPath, 'CSV', csvFileName);

%% Read CSV according to its Radix row
[dataTable, ilaInfo] = readVivadoIlaCsv(filename);

fprintf('\n===== CSV information =====\n');
fprintf('File              : %s\n', filename);
fprintf('Rows              : %d\n', height(dataTable));
fprintf('Columns           : %d\n', width(dataTable));
fprintf('Sample period     : %.3f ns\n', samplePeriodNs);
fprintf('Sampling frequency: %.9f Hz\n', fs);

fprintf('\n===== CSV radix =====\n');
for k = 1:ilaInfo.NumberOfColumns
    fprintf('%-65s : %s\n', ilaInfo.OriginalVariableNames(k), ilaInfo.Radix(k));
end

%% Find signal columns
iSenColumn = findColumnByKeyword(ilaInfo.OriginalVariableNames, ...
    {'i_sen', 'isen', 'i sen'});
vbusColumn = findColumnByKeyword(ilaInfo.OriginalVariableNames, ...
    {'vbus', 'v_bus', 'v bus'});
vacColumn = findColumnByKeyword(ilaInfo.OriginalVariableNames, ...
    {'vac', 'v_ac', 'v ac'});

fprintf('\n===== Selected channels =====\n');
fprintf('i_sen : %s, radix = %s\n', ...
    ilaInfo.OriginalVariableNames(iSenColumn), ilaInfo.Radix(iSenColumn));
fprintf('Vbus  : %s, radix = %s\n', ...
    ilaInfo.OriginalVariableNames(vbusColumn), ilaInfo.Radix(vbusColumn));
fprintf('Vac   : %s, radix = %s\n', ...
    ilaInfo.OriginalVariableNames(vacColumn), ilaInfo.Radix(vacColumn));

iSenCode = dataTable{:, iSenColumn};
vbusCode = dataTable{:, vbusColumn};
vacCode = dataTable{:, vacColumn};

validIndex = isfinite(iSenCode) & isfinite(vbusCode) & isfinite(vacCode);
iSenCode = iSenCode(validIndex);
vbusCode = vbusCode(validIndex);
vacCode = vacCode(validIndex);

numberOfSamples = numel(iSenCode);
if numberOfSamples < 16
    error('Too few valid samples for FFT analysis.');
end

time = (0:numberOfSamples - 1).' * samplePeriod;
recordDuration = numberOfSamples * samplePeriod;
frequencyResolution = fs / numberOfSamples;

fprintf('\n===== Sampling information =====\n');
fprintf('Valid samples       = %d\n', numberOfSamples);
fprintf('Record duration     = %.9f s\n', recordDuration);
fprintf('Nyquist frequency   = %.9f Hz\n', fs / 2);
fprintf('FFT bin spacing     = %.9f Hz\n', frequencyResolution);

%% Statistics
printStatistics('i_sen', iSenCode);
printStatistics('Vbus', vbusCode);
printStatistics('Vac', vacCode);

%% Time-domain plots
figure('Name', 'ADC time-domain signals', 'Color', 'k');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plot(time, iSenCode, 'LineWidth', 1);
formatDarkAxes(gca);
ylabel('ADC code');
title('i\_sen');

nexttile;
plot(time, vbusCode, 'LineWidth', 1);
formatDarkAxes(gca);
ylabel('ADC code');
title('Vbus');

nexttile;
plot(time, vacCode, 'LineWidth', 1);
formatDarkAxes(gca);
xlabel('Time (s)');
ylabel('ADC code');
title('Vac');

%% FFT
[iSenFrequency, iSenAmplitude] = calculateSingleSidedFFT(iSenCode, fs);
[vbusFrequency, vbusAmplitude] = calculateSingleSidedFFT(vbusCode, fs);
[vacFrequency, vacAmplitude] = calculateSingleSidedFFT(vacCode, fs);

figure('Name', 'ADC low-frequency FFT', 'Color', 'k');
tiledlayout(3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

nexttile;
plotSpectrum(iSenFrequency, iSenAmplitude, lowFrequencyMax, 'i\_sen FFT');
nexttile;
plotSpectrum(vbusFrequency, vbusAmplitude, lowFrequencyMax, 'Vbus FFT');
nexttile;
plotSpectrum(vacFrequency, vacAmplitude, lowFrequencyMax, 'Vac FFT');

%% Dominant components
fprintf('\n===== Dominant components: 1 to %.1f Hz =====\n', lowFrequencyMax);
printDominantFrequencies('i_sen', iSenFrequency, iSenAmplitude, ...
    1, lowFrequencyMax, numberOfPeaks);
printDominantFrequencies('Vbus', vbusFrequency, vbusAmplitude, ...
    1, lowFrequencyMax, numberOfPeaks);
printDominantFrequencies('Vac', vacFrequency, vacAmplitude, ...
    1, lowFrequencyMax, numberOfPeaks);

%% Local functions
function columnIndex = findColumnByKeyword(variableNames, keywords)
    normalizedNames = lower(string(variableNames));
    normalizedNames = erase(normalizedNames, {'_', ' ', '-'});
    columnIndex = [];

    for k = 1:numel(keywords)
        keyword = lower(string(keywords{k}));
        keyword = erase(keyword, {'_', ' ', '-'});
        columnIndex = find(contains(normalizedNames, keyword), 1, 'first');
        if ~isempty(columnIndex)
            return;
        end
    end

    error('Cannot find the requested signal column.');
end

function printStatistics(signalName, signalData)
    fprintf('\n%s statistics:\n', signalName);
    fprintf('  min  = %.6f ADC code\n', min(signalData));
    fprintf('  max  = %.6f ADC code\n', max(signalData));
    fprintf('  mean = %.6f ADC code\n', mean(signalData));
    fprintf('  RMS  = %.6f ADC code\n', sqrt(mean(signalData.^2)));
    fprintf('  Vpp  = %.6f ADC code\n', max(signalData) - min(signalData));
    fprintf('  std  = %.6f ADC code\n', std(signalData));
end

function [frequency, amplitude] = calculateSingleSidedFFT(signalData, fs)
    signalData = double(signalData(:));
    signalData = signalData - mean(signalData);
    numberOfSamples = numel(signalData);

    sampleIndex = (0:numberOfSamples - 1).';
    window = 0.5 - 0.5*cos(2*pi*sampleIndex/(numberOfSamples - 1));
    coherentGain = sum(window) / numberOfSamples;

    fftResult = fft(signalData .* window);
    twoSidedAmplitude = abs(fftResult) / (numberOfSamples * coherentGain);
    singleSideLength = floor(numberOfSamples / 2) + 1;
    amplitude = twoSidedAmplitude(1:singleSideLength);

    if rem(numberOfSamples, 2) == 0
        amplitude(2:end-1) = 2 * amplitude(2:end-1);
    else
        amplitude(2:end) = 2 * amplitude(2:end);
    end

    frequency = (0:singleSideLength - 1).' * fs / numberOfSamples;
end

function plotSpectrum(frequency, amplitude, maximumFrequency, plotTitle)
    displayIndex = frequency <= maximumFrequency;
    spectrumStem = stem(frequency(displayIndex), amplitude(displayIndex), ...
        'Marker', 'none', 'LineWidth', 1);
    spectrumStem.BaseLine.Visible = 'off';
    formatDarkAxes(gca);
    xlim([0 maximumFrequency]);
    xlabel('Frequency (Hz)');
    ylabel('Amplitude (ADC code)');
    title(plotTitle);
end

function printDominantFrequencies(signalName, frequency, amplitude, ...
    minimumFrequency, maximumFrequency, numberOfPeaks)

    searchIndex = frequency >= minimumFrequency & frequency <= maximumFrequency;
    searchFrequency = frequency(searchIndex);
    searchAmplitude = amplitude(searchIndex);

    localMaximumIndex = searchAmplitude(2:end-1) > searchAmplitude(1:end-2) & ...
        searchAmplitude(2:end-1) >= searchAmplitude(3:end);
    peakIndices = find(localMaximumIndex) + 1;

    if isempty(peakIndices)
        fprintf('\n%s: no local peaks found.\n', signalName);
        return;
    end

    peakAmplitudes = searchAmplitude(peakIndices);
    peakFrequencies = searchFrequency(peakIndices);
    [sortedAmplitudes, order] = sort(peakAmplitudes, 'descend');
    sortedFrequencies = peakFrequencies(order);
    numberToDisplay = min(numberOfPeaks, numel(sortedAmplitudes));

    fprintf('\n%s:\n', signalName);
    fprintf('  Rank      Frequency       Amplitude\n');
    for k = 1:numberToDisplay
        fprintf('  %4d      %9.3f Hz     %10.6f code\n', ...
            k, sortedFrequencies(k), sortedAmplitudes(k));
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
