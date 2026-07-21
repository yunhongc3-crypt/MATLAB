%% plot_ADC_data_380.m
% 讀取 Vivado ILA 匯出的 CSV，並繪製三個 12-bit ADC 訊號
clear;
clc;
close all;

%% 使用者設定
filename = 'ADC_data_380_0721.csv';
filename2 = 'ADC_data_380.csv';  % 保留給後續比較使用

% 自動定位 repository 根目錄下的 CSV 資料夾
scriptPath = fileparts(mfilename('fullpath'));
repositoryPath = fileparts(scriptPath);
filePath = fullfile(repositoryPath, 'CSV', filename);
filePath2 = fullfile(repositoryPath,