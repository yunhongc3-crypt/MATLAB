%% plot_ADC_data_380.m
% 讀取 Vivado ILA 匯出的 CSV，並繪製三個 12-bit ADC 訊號
clear;
clc;
close all;

%% 使用者設定
filename = 'ADC_data_380_0721';
filename2 = 'ADC_data_380';  %兩個CSV畫在同一張圖上比較
% false：顯示 ADC 原始碼 0~4095
% true ：換算成 XADC 腳位電壓
plotInVoltage = false;

% 7-series XADC 在 unipolar 模式下通常以 1.0 V 對應滿刻度。
% 若實際量測電路有分壓器或放大器，還要再乘上硬體換算倍率。
adcFullScaleVoltage = 1.0;
adcMaxCode = 4095;

%% 讀取資料
% Vivado CSV：
% 第 1 行為欄位名稱
% 第 2 行為 Radix 資訊
% 第 3 行開始才是數值資料
data = readmatrix(filename, 'NumHeaderLines', 2);

% 移除可能的空白列或無效列
data = data(all(~isnan(data(:, 1:6)), 2), :);

% CSV 欄位順序
sampleBuffer = data(:, 1);
sampleWindow = data(:, 2);
trigger      = data(:, 3);
iSenCode     = data(:, 4);
vbusCode     = data(:, 5);
vacCode      = data(:, 6);

if size(data, 2) >= 7
    vacValid = data(:, 7);
else
    vacValid = ones(size(sampleWindow));
end

%% 選擇顯示 ADC Code 或腳位電壓
if plotInVoltage
    scale = adcFullScaleVoltage / adcMaxCode;

    iSen = iSenCode * scale;
    vbus = vbusCode * scale;
    vac  = vacCode  * scale;

    yLabelText = 'XADC input voltage (V)';
else
    iSen = iSenCode;
    vbus = vbusCode;
    vac  = vacCode;

    yLabelText = 'ADC code';
end

%% 尋找觸發點
triggerIndex = find(trigger ~= 0, 1, 'first');

if isempty(triggerIndex)
    triggerSample = [];
    fprintf('CSV 中沒有找到 Trigger 標記。\n');
else
    triggerSample = sampleWindow(triggerIndex);
    fprintf('Trigger 位於 Sample in Window = %d\n', triggerSample);
end



%% 疊加比較圖
figure('Name', 'ADC Channel Comparison', 'Color', 'k');
plot(sampleWindow, iSen, 'LineWidth', 1);
hold on;
plot(sampleWindow, vbus, 'LineWidth', 1);
plot(sampleWindow, vac,  'LineWidth', 1);
hold off;

grid on;
xlabel('Sample in Window');
ylabel(yLabelText);
title('ADC channel comparison');
legend('i\_sen', 'Vbus', 'Vac', 'Trigger', ...
       'Location', 'best');



%% 顯示統計資訊
fprintf('\n===== ADC code statistics =====\n');

fprintf(['i_sen: min = %g, max = %g, mean = %.3f, ' ...
         'Vpp = %g ADC code\n'], ...
        min(iSenCode), ...
        max(iSenCode), ...
        mean(iSenCode), ...
        max(iSenCode) - min(iSenCode));

fprintf(['Vbus : min = %g, max = %g, mean = %.3f, ' ...
         'Vpp = %g ADC code\n'], ...
        min(vbusCode), ...
        max(vbusCode), ...
        mean(vbusCode), ...
        max(vbusCode) - min(vbusCode));

fprintf(['Vac  : min = %g, max = %g, mean = %.3f, ' ...
         'Vpp = %g ADC code\n'], ...
        min(vacCode), ...
        max(vacCode), ...
        mean(vacCode), ...
        max(vacCode) - min(vacCode));

%% 區域函式
function addTriggerLine(triggerSample)
    if ~isempty(triggerSample)
        xline(triggerSample, 'r--', 'Trigger', ...
              'LineWidth', 1.2, ...
              'LabelVerticalAlignment', 'bottom');
    end
end
