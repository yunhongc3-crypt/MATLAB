%% plot_ADC_data_compare.m
% 讀取兩份 Vivado ILA 匯出的 CSV，並將 ADC 訊號畫在同一張圖比較

clear;
clc;
close all;

%% 使用者設定
filename1 = 'ADC_data_380_0721.csv';
filename2 = 'ADC_data_380.csv';

% 根據目前腳本位置，自動找到上一層的 CSV 資料夾
scriptPath = fileparts(mfilename('fullpath'));
repositoryPath = fileparts(scriptPath);
filePath1 = fullfile(repositoryPath, 'CSV', filename1);
filePath2 = fullfile(repositoryPath, 'CSV', filename2);

if ~isfile(filePath1)
    error('找不到第一份 CSV：