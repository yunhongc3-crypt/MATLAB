%% simulate_vbus_notch_lpf.m
% Vbus ADC data filter simulation
% Filter chain:
%   60 Hz notch -> 120 Hz notch -> 500 Hz second-order Butterworth LPF
%
% Sampling period:
%   Ts = 14290 ns
% Sampling frequency:
%   Fs = 1 / Ts = approximately 69979.0063 Hz

clear;
clc;
close all;

%% User settings
filename = 'ADC_data_380.csv';
signalName = 'Vbus';

% Actual ADC sampling period and sampling frequency
Ts = 14290e-9;          % 14290 ns
Fs = 1 / Ts;            % approximately 69979.0063 Hz

% Notch filter quality factors
Q60 = 20;
Q120 = 20;

% Second-order Butterworth low-pass cutoff frequency
Fc = 500;               % Hz

% Plot settings
fftMaxFrequency = 550;  % Hz
zoomStartTime = 0;      % s
zoomEndTime = 0.2;      % s

fprintf('Ts = %.12g s\n', Ts);
fprintf('Fs = %.9f Hz\n', Fs);

%% Read CSV
opts = detectImportOptions(filename);
opts.VariableNamingRule = 'preserve';
dataTable = readtable(filename, opts);

fprintf('\nCSV columns:\n');
disp(dataTable.Properties.VariableNames.');

variableNames = string(dataTable.Properties.VariableNames);
signalIndex = find(strcmpi(variableNames, signalName), 1);

if isempty(signalIndex)
    error('Cannot find column "%s". Please modify signalName.', signalName);
end

x = double(dataTable{:, signalIndex});
x = x(:);
x = x(isfinite(x));

N = length(x);
t = (0:N-1).' / Fs;

fprintf('\nSignal information:\n');
fprintf('Signal name       = %s\n', signalName);
fprintf('Sampling frequency= %.9f Hz\n', Fs);
fprintf('Number of samples = %d\n', N);
fprintf('Record duration   = %.9f s\n', N/Fs);
fprintf('Original mean     = %.6f ADC code\n', mean(x));
fprintf('Original Vpp      = %.6f ADC code\n', max(x)-min(x));

%% Design 60 Hz notch filter
fNotch60 = 60;
w060 = fNotch60 / (Fs/2);
bw60 = w060 / Q60;
[b60, a60] = iirnotch(w060, bw60);

%% Design 120 Hz notch filter
fNotch120 = 120;
w0120 = fNotch120 / (Fs/2);
bw120 = w0120 / Q120;
[b120, a120] = iirnotch(w0120, bw120);

%% Design 500 Hz second-order Butterworth low-pass filter
[bLP, aLP] = butter(2, Fc/(Fs/2), 'low');

%% Apply filters in cascade
xAfter60 = filter(b60, a60, x);
xAfter120 = filter(b120, a120, xAfter60);
xFiltered = filter(bLP, aLP, xAfter120);

fprintf('\nFiltered signal information:\n');
fprintf('Filtered mean     = %.6f ADC code\n', mean(xFiltered));
fprintf('Filtered Vpp      = %.6f ADC code\n', max(xFiltered)-min(xFiltered));

%% Figure 1: Complete time-domain comparison
figure('Name', 'Complete time-domain comparison');
plot(t, x, 'DisplayName', 'Original');
hold on;
plot(t, xFiltered, 'LineWidth', 1.2, ...
    'DisplayName', '60 Hz notch + 120 Hz notch + 500 Hz LPF');
grid on;
xlabel('Time (s)');
ylabel('Amplitude (ADC code)');
title([signalName, ' time-domain comparison']);
legend('Location', 'best');

%% Figure 2: Zoomed time-domain comparison
zoomIndex = (t >= zoomStartTime) & (t <= zoomEndTime);

figure('Name', 'Zoomed time-domain comparison');
plot(t(zoomIndex), x(zoomIndex), 'DisplayName', 'Original');
hold on;
plot(t(zoomIndex), xFiltered(zoomIndex), 'LineWidth', 1.3, ...
    'DisplayName', 'Filtered');
grid on;
xlabel('Time (s)');
ylabel('Amplitude (ADC code)');
title(sprintf('%s time-domain comparison: %.3f to %.3f s', ...
    signalName, zoomStartTime, zoomEndTime));
legend('Location', 'best');

%% Figure 3: Output after each filter stage
figure('Name', 'Output after each filter stage');
plot(t(zoomIndex), x(zoomIndex), 'DisplayName', 'Original');
hold on;
plot(t(zoomIndex), xAfter60(zoomIndex), ...
    'DisplayName', 'After 60 Hz notch');
plot(t(zoomIndex), xAfter120(zoomIndex), ...
    'DisplayName', 'After 60 Hz + 120 Hz notch');
plot(t(zoomIndex), xFiltered(zoomIndex), 'LineWidth', 1.3, ...
    'DisplayName', 'After 500 Hz LPF');
grid on;
xlabel('Time (s)');
ylabel('Amplitude (ADC code)');
title([signalName, ' output after each filter stage']);
legend('Location', 'best');

%% FFT comparison
[fOriginal, ampOriginal] = calculateSingleSidedFFT(x, Fs);
[fFiltered, ampFiltered] = calculateSingleSidedFFT(xFiltered, Fs);

originalDisplayIndex = fOriginal <= fftMaxFrequency;
filteredDisplayIndex = fFiltered <= fftMaxFrequency;

figure('Name', 'FFT comparison');
plot(fOriginal(originalDisplayIndex), ampOriginal(originalDisplayIndex), ...
    'DisplayName', 'Original');
hold on;
plot(fFiltered(filteredDisplayIndex), ampFiltered(filteredDisplayIndex), ...
    'LineWidth', 1.3, 'DisplayName', 'Filtered');
xline(60, '--', '60 Hz');
xline(120, '--', '120 Hz');
grid on;
xlabel('Frequency (Hz)');
ylabel('Amplitude (ADC code)');
title([signalName, ' FFT comparison']);
legend('Location', 'best');
xlim([0 fftMaxFrequency]);

%% Overall filter frequency response
bCascade = conv(conv(b60, b120), bLP);
aCascade = conv(conv(a60, a120), aLP);

nFrequencyPoints = 262144;
[H, fResponse] = freqz(bCascade, aCascade, nFrequencyPoints, Fs);
magnitudeDB = 20*log10(abs(H) + eps);

figure('Name', 'Overall filter frequency response');
plot(fResponse, magnitudeDB, 'LineWidth', 1.2);
hold on;
xline(60, '--', '60 Hz');
xline(120, '--', '120 Hz');
xline(Fc, '--', '500 Hz');
grid on;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('60 Hz notch + 120 Hz notch + 500 Hz second-order LPF');
xlim([0 1000]);
ylim([-100 5]);

%% Print theoretical response at selected frequencies
checkFrequency = [10 20 60 120 180 240 500 1000];
Hcheck = freqz(bCascade, aCascade, checkFrequency, Fs);
responseDB = 20*log10(abs(Hcheck) + eps);

fprintf('\n===== Overall filter theoretical response =====\n');
for k = 1:length(checkFrequency)
    fprintf('%7.1f Hz: %9.3f dB\n', checkFrequency(k), responseDB(k));
end

%% Print floating-point coefficients
fprintf('\n===== 60 Hz notch coefficients =====\n');
fprintf('b60 = [%.15g, %.15g, %.15g]\n', b60);
fprintf('a60 = [%.15g, %.15g, %.15g]\n', a60);

fprintf('\n===== 120 Hz notch coefficients =====\n');
fprintf('b120 = [%.15g, %.15g, %.15g]\n', b120);
fprintf('a120 = [%.15g, %.15g, %.15g]\n', a120);

fprintf('\n===== 500 Hz LPF coefficients =====\n');
fprintf('bLP = [%.15g, %.15g, %.15g]\n', bLP);
fprintf('aLP = [%.15g, %.15g, %.15g]\n', aLP);

%% Save filtered data
outputTable = table( ...
    t, x, xAfter60, xAfter120, xFiltered, ...
    'VariableNames', { ...
    'Time_s', ...
    'Original', ...
    'After_60Hz_Notch', ...
    'After_120Hz_Notch', ...
    'After_500Hz_LPF'});

outputFilename = [signalName, '_filtered_result.csv'];
writetable(outputTable, outputFilename);
fprintf('\nFiltered data saved to: %s\n', outputFilename);

%% Local function: single-sided amplitude spectrum
function [f, amplitude] = calculateSingleSidedFFT(x, Fs)
    x = double(x(:));
    x = x - mean(x);

    N = length(x);
    window = hann(N, 'periodic');
    xWindowed = x .* window;

    coherentGain = sum(window) / N;
    X = fft(xWindowed);
    twoSidedAmplitude = abs(X) / (N * coherentGain);

    numberOfPoints = floor(N/2) + 1;
    amplitude = twoSidedAmplitude(1:numberOfPoints);

    if N > 2
        amplitude(2:end-1) = 2 * amplitude(2:end-1);
    end

    f = (0:numberOfPoints-1).' * Fs / N;
end
