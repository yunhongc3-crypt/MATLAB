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
filePath2 =