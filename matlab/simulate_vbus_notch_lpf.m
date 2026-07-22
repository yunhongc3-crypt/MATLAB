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
scriptFolder = fileparts(mfilename('fullpath'));
filename = fullfile(scriptFolder, '..', 'CSV', 'ADC_data_380.csv');
signalName = 'Vbus';

% Actual ADC sampling period and sampling frequency
Ts = 14290e-9;          % 14290 ns
Fs = 1 / Ts;            % approximately 69979.0063 Hz

% Notch filter quality factors
Q60 = 20;
Q120 = 20;

% Second-order Butterworth low-pass cutoff frequency
Fc = 500;               % Hz

% Ignore this initial interval when calculating steady-state statistics
settlingTime = 0.08;    % s

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

% Find a column whose name contains signalName, for example:
% dut/design_1_i/Vbus_signal_debug[11:0]
matchingIndices = find(contains(variableNames, signalName, ...
    'IgnoreCase', true));

if isempty(matchingIndices)
    error('Cannot find a column containing "%s". Please modify signalName.', ...
        signalName);
elseif numel(matchingIndices) > 1
    fprintf('\nMultiple columns contain "%s":\n', signalName);
    disp(variableNames(matchingIndices).');
    error('More than one matching column was found. Use a more specific signalName.');
end

signalIndex = matchingIndices(1);
matchedSignalName = variableNames(signalIndex);
fprintf('Selected CSV column: %s\n', matchedSignalName);

x = double(dataTable{:, signalIndex});
x = x(:);
x = x(isfinite(x));

N = length(x);
t = (0:N-1).' / Fs;
recordDuration = N / Fs;

fprintf('\nSignal information:\n');
fprintf('Signal name       = %s\n', signalName);
fprintf('CSV column        = %s\n', matchedSignalName);
fprintf('Sampling frequency= %.9f Hz\n', Fs);
fprintf('Number of samples = %d\n', N);
fprintf('Record duration   = %.9f s\n', recordDuration);
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
% Remove the DC component before filtering to avoid a large startup step.
% Add the DC component back after each filter stage.
dcValue = mean(x);
xAC = x - dcValue;

xAfter60AC = filter(b60, a60, xAC);
xAfter120AC = filter(b120, a120, xAfter60AC);
xFilteredAC = filter(bLP, aLP, xAfter120AC);

xAfter60 = xAfter60AC + dcValue;
xAfter120 = xAfter120AC + dcValue;
xFiltered = xFilteredAC + dcValue;

%% Steady-state statistics
if settlingTime >= recordDuration
    warning(['settlingTime is greater than or equal to the record duration. ' ...
        'Using the final 20%% of the data for steady-state statistics.']);
    steadyIndex = t >= 0.8 * recordDuration;
    effectiveSettlingTime = 0.8 * recordDuration;
else
    steadyIndex = t >= settlingTime;
    effectiveSettlingTime = settlingTime;
end

% Calculate steady-state Vpp for the original signal and every filter stage.
originalVpp = max(x(steadyIndex)) - min(x(steadyIndex));
after60Vpp = max(xAfter60(steadyIndex)) - min(xAfter60(steadyIndex));
after120Vpp = max(xAfter120(steadyIndex)) - min(xAfter120(steadyIndex));
afterLPFVpp = max(xFiltered(steadyIndex)) - min(xFiltered(steadyIndex));

fprintf('\nFiltered signal information:\n');
fprintf('DC value removed  = %.6f ADC code\n', dcValue);
fprintf('Statistics start  = %.6f s\n', effectiveSettlingTime);
fprintf('Steady samples    = %d\n', nnz(steadyIndex));
fprintf('Filtered mean     = %.6f ADC code\n', ...
    mean(xFiltered(steadyIndex)));

fprintf('\n===== Steady-state Vpp comparison =====\n');
fprintf('Original signal                    = %.6f ADC code\n', originalVpp);
fprintf('After 60 Hz notch                  = %.6f ADC code\n', after60Vpp);
fprintf('After 60 Hz + 120 Hz notch         = %.6f ADC code\n', after120Vpp);
fprintf('After notch filters + 500 Hz LPF   = %.6f ADC code\n', afterLPFVpp);

%% Figure 1: Complete time-domain comparison
figure('Name', 'Complete time-domain comparison');
plot(t, x, 'DisplayName', 'Original');
hold on;
plot(t, xFiltered, 'LineWidth', 1.2, ...
    'DisplayName', '60 Hz notch + 120 Hz notch + 500 Hz LPF');
xline(effectiveSettlingTime, '--', 'Statistics start', ...
    'HandleVisibility', 'off');
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
xline(effectiveSettlingTime, '--', 'Statistics start', ...
    'HandleVisibility', 'off');
grid on;
xlabel('Time (s)');
ylabel('Amplitude (ADC code)');
title(sprintf('%s time-domain comparison: %.3f to %.3f s', ...
    signalName, zoomStartTime, zoomEndTime));
legend('Location', 'best');

%% Figure 3: Output after each filter stage
figure('Name', 'Output after each filter stage');
plot(t(zoomIndex), x(zoomIndex), ...
    'DisplayName', sprintf('Original, Vpp = %.3f', originalVpp));
hold on;
plot(t(zoomIndex), xAfter60(zoomIndex), ...
    'DisplayName', sprintf('After 60 Hz notch, Vpp = %.3f', after60Vpp));
plot(t(zoomIndex), xAfter120(zoomIndex), ...
    'DisplayName', sprintf('After 60 Hz + 120 Hz notch, Vpp = %.3f', after120Vpp));
plot(t(zoomIndex), xFiltered(zoomIndex), 'LineWidth', 1.3, ...
    'DisplayName', sprintf('After notch filters + 500 Hz LPF, Vpp = %.3f', ...
    afterLPFVpp));
xline(effectiveSettlingTime, '--', 'Statistics start', ...
    'HandleVisibility', 'off');
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
hOriginal = stem( ...
    fOriginal(originalDisplayIndex), ...
    ampOriginal(originalDisplayIndex), ...
    'Marker', 'none', ...
    'LineWidth', 1.0, ...
    'DisplayName', 'Original');
hold on;
hFiltered = stem( ...
    fFiltered(filteredDisplayIndex), ...
    ampFiltered(filteredDisplayIndex), ...
    'Marker', 'none', ...
    'LineWidth', 1.0, ...
    'DisplayName', 'Filtered');
hOriginal.BaseLine.Visible = 'off';
hFiltered.BaseLine.Visible = 'off';
xline(60, '--', '60 Hz', 'HandleVisibility', 'off');
xline(120, '--', '120 Hz', 'HandleVisibility', 'off');
grid on;
xlabel('Frequency (Hz)');
ylabel('Amplitude (ADC code)');
title([signalName, ' FFT comparison']);
fftLegend = legend('show');
fftLegend.Location = 'best';
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

outputFilename = fullfile(scriptFolder, ...
    [signalName, '_filtered_result.csv']);
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
