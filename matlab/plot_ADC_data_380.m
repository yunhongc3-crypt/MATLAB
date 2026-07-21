%% plot_ADC_data_380.m
% Read one Vivado ILA CSV file and plot three 12-bit ADC signals.

clear;
clc;
close all;

%% User settings
filename = 'ADC_data_380_0721.csv';
plotInVoltage = false;
adcFullScaleVoltage = 1.0;
adcMaxCode = 4095;

%% Build path relative to this script
scriptPath = fileparts(mfilename('fullpath'));
repositoryPath = fileparts(scriptPath);
filePath = fullfile(repositoryPath, 'CSV', filename);

if ~isfile(filePath)
    error('CSV file not found: %s', filePath);
end

%% Read data
% Vivado ILA CSV: row 1 names, row 2 radix, data starts at row 3.
data = readmatrix(filePath, 'NumHeaderLines', 2);

if size(data, 2) < 6
    error('CSV must contain at least 6 columns.');
end

data = data(all(~isnan(data(:, 1:6)), 2), :);

sampleBuffer = data(:, 1);
sampleWindow = data(:, 2);
trigger = data(:, 3);
iSenCode = data(:, 4);
vbusCode = data(:, 5);
vacCode = data(:, 6);

if size(data, 2) >= 7
    vacValid = data(:, 7); %#ok<NASGU>
else
    vacValid = ones(size(sampleWindow)); %#ok<NASGU>
end

%% Select ADC code or voltage
if plotInVoltage
    scale = adcFullScaleVoltage / adcMaxCode;
    iSen = iSenCode * scale;
    vbus = vbusCode * scale;
    vac = vacCode * scale;
    yLabelText = 'XADC input voltage (V)';
else
    iSen = iSenCode;
    vbus = vbusCode;
    vac = vacCode;
    yLabelText = 'ADC code';
end

%% Trigger position
triggerIndex = find(trigger ~= 0, 1, 'first');
if isempty(triggerIndex)
    fprintf('No trigger marker was found in the CSV.\n');
else
    triggerSample = sampleWindow(triggerIndex);
    fprintf('Trigger sample = %g\n', triggerSample);
end

%% Plot
figure('Name', 'ADC Channel Comparison', 'Color', 'k');
plot(sampleWindow, iSen, 'LineWidth', 1.0, 'DisplayName', 'i\_sen');
hold on;
plot(sampleWindow, vbus, 'LineWidth', 1.0, 'DisplayName', 'Vbus');
plot(sampleWindow, vac, 'LineWidth', 1.0, 'DisplayName', 'Vac');
hold off;

grid on;
box on;
xlabel('Sample in Window');
ylabel(yLabelText);
title('ADC channel comparison');
legend('Location', 'best');

ax = gca;
ax.Color = 'k';
ax.XColor = 'w';
ax.YColor = 'w';
ax.GridColor = [0.5 0.5 0.5];
ax.MinorGridColor = [0.3 0.3 0.3];
ax.Title.Color = 'w';
ax.XLabel.Color = 'w';
ax.YLabel.Color = 'w';

lgd = legend;
lgd.TextColor = 'w';
lgd.Color = 'k';
lgd.EdgeColor = 'w';

%% Statistics
fprintf('\n===== ADC code statistics =====\n');
printStatistics('i_sen', iSenCode);
printStatistics('Vbus', vbusCode);
printStatistics('Vac', vacCode);

%% Local function
function printStatistics(signalName, signalData)
    signalVpp = max(signalData) - min(signalData);
    fprintf('%s: min = %g, max = %g, mean = %.3f, Vpp = %g ADC code\n', ...
        signalName, min(signalData), max(signalData), mean(signalData), signalVpp);
end
