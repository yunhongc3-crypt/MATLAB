%% analyze_ADC_fft.m
% Vivado ILA 匯出 CSV 的 ADC 頻譜分析
% 分析 i_sen、Vbus、Vac 三個通道

clear;
clc;
close all;

%% 使用者設定
csvFileName = 'ADC_data_380.csv';

samplePeriodNs = 14290;                 % 每筆資料時間間隔，ns
samplePeriod = samplePeriodNs * 1e-9;  % 秒
fs = 1 / samplePeriod;                 % 取樣頻率，約 69.979 kHz

lowFreqMax = 500;                      % 低頻圖：0~500 Hz
wideFreqMax = fs / 2;                  % 完整單邊頻譜