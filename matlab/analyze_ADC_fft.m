%% analyze_ADC_fft.m
% Vivado ILA 匯出 CSV 的 ADC 頻譜分析
% 分析 i_sen、Vbus、Vac 三個通道。
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
samplePeriod = samplePeriodNs * 1e-9;   % 換算成秒
fs = 1 / samplePeriod;                 