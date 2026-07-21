%% plot_ADC_data_compare.m
% Compare two Vivado ILA CSV files on one figure.

clear;
clc;
close all;

%% User settings
filename1 = 'ADC_data_380_0721.csv';
filename2 = 'ADC_data_380.csv';
plotInVoltage = false;
adcFullScaleVoltage = 1.0;
adcMaxCode = 4095;

%% Build paths relative to this script
scriptPath = fileparts(mfilename('fullpath'));
repositoryPath = fileparts(scriptPath);
filePath1 = fullfile(repositoryPath, 'CSV', filename1);
filePath2 = fullfile(repositoryPath, 'CSV', filename2);

if ~isfile(filePath1)
    error('CSV file not found: %s', filePath1);
end
if ~isfile(filePath2)
    error('CSV file not found: %s', filePath2);
end

%% Read CSV files
% Vivado ILA CSV: row 1 names, row 2 radix, data starts at row 3.
data1 = readmatrix(filePath1, 'NumHeaderLines', 2);
data2 = readmatrix(filePath2, 'NumHeaderLines', 2);

if size(data1, 2) < 6 || size(data2, 2) < 6
    error('Each CSV must contain at least 6 columns.');
end

data1 = data1(all(~isnan(data1(:, 1:6)), 2), :);
data2 = data2(all(~isnan(data2(:, 1:6)), 