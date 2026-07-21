%% plot_ADC_data_compare.m
% 讀取兩份 Vivado ILA 匯出的 CSV，並將 ADC 訊號畫在同一張圖比較

clear;
clc;
close all;

%% 使用者設定
filename1 = 'ADC_data_380_0721.csv';
filename2 = 'ADC_data_380.csv';

% false：顯示 ADC 原始碼 0~4095
% true ：換算成 XADC 腳位電壓
plotInVoltage = false;

% 7-series XADC 在 unipolar 模式下，通常以 1.0 V 對應滿刻度
adcFullScaleVoltage = 1.0;
adcMaxCode = 4095;

%% 讀取第一份 CSV
data1 = readmatrix(filename1, 'NumHeaderLines', 2);

% 至少需要前 6 欄有效
data1 = data1(all(~isnan(data1(:, 1:6)), 2), :);

sampleWindow1 = data1(:, 2);
trigger1      = data1(:, 3);
iSenCode1     = data1(:, 4);
vbusCode1     = data1(:, 5);
vacCode1      = data1(:, 6);

%% 讀取第二份 CSV
data2 = readmatrix(filename2, 'NumHeaderLines', 2);

data2 = data2(all(~isnan(data2(:, 1:6)), 2), :);

sampleWindow2 = data2(:, 2);
trigger2      = data2(:, 3);
iSenCode2     = data2(:, 4);
vbusCode2     = data2(:, 5);
vacCode2      = data2(:, 6);

%% 選擇顯示 ADC Code 或腳位電壓
if plotInVoltage
    scale = adcFullScaleVoltage / adcMaxCode;

    iSen1 = iSenCode1 * scale;
    vbus1 = vbusCode1 * scale;
    vac1  = vacCode1  * scale;

    iSen2 = iSenCode2 * scale;
    vbus2 = vbusCode2 * scale;
    vac2  = vacCode2  * scale;

    yLabelText = 'XADC input voltage (V)';
else
    iSen1 = iSenCode1;
    vbus1 = vbusCode1;
    vac1  = vacCode1;

    iSen2 = iSenCode2;
    vbus2 = vbusCode2;
    vac2  = vacCode2;

    yLabelText = 'ADC code';
end

%% 尋找兩份資料的 Trigger 位置
triggerIndex1 = find(trigger1 ~= 0, 1, 'first');
triggerIndex2 = find(trigger2 ~= 0, 1, 'first');

if isempty(triggerIndex1)
    triggerSample1 = [];
    fprintf('%s 中沒有找到 Trigger 標記。\n', filename1);
else
    triggerSample1 = sampleWindow1(triggerIndex1);
    fprintf('%s Trigger 位於 Sample in Window = %g\n', ...
        filename1, triggerSample1);
end

if isempty(triggerIndex2)
    triggerSample2 = [];
    fprintf('%s 中沒有找到 Trigger 標記。\n', filename2);
else
    triggerSample2 = sampleWindow2(triggerIndex2);
    fprintf('%s Trigger 位於 Sample in Window = %g\n', ...
        filename2, triggerSample2);
end

%% 六條曲線疊加比較
figure( ...
    'Name', 'Two CSV ADC Comparison', ...
    'Color', 'k');

hold on;

% 第一份 CSV：實線
plot(sampleWindow1, iSen1, '-', ...
    'LineWidth', 1.2, ...
    'DisplayName', 'i\_sen -  電供');

plot(sampleWindow1, vbus1, '-', ...
    'LineWidth', 1.2, ...
    'DisplayName', 'Vbus - 10Ω+1u濾波 + 電供');

plot(sampleWindow1, vac1, '-', ...
    'LineWidth', 1.2, ...
    'DisplayName', 'Vac - 10Ω+1u濾波 + 電供');

% 第二份 CSV：虛線
plot(sampleWindow2, iSen2, '--', ...
    'LineWidth', 1.2, ...
    'DisplayName', 'i\_sen - CSV 隔離');

plot(sampleWindow2, vbus2, '--', ...
    'LineWidth', 1.2, ...
    'DisplayName', 'Vbus - CSV 隔離');

plot(sampleWindow2, vac2, '--', ...
    'LineWidth', 1.2, ...
    'DisplayName', 'Vac - CSV 隔離');

% 顯示 Trigger 線
%if ~isempty(triggerSample1)
%    xline(triggerSample1, ':', 'Trigger CSV 1', ...
%        'LineWidth', 1.2, ...
%        'HandleVisibility', 'off');
%end
%
%if ~isempty(triggerSample2)
%    xline(triggerSample2, '-.', 'Trigger CSV 2', ...
%        'LineWidth', 1.2, ...
%        'HandleVisibility', 'off');
%end

hold off;

%% 圖形設定
grid on;
box on;

xlabel('Sample in Window');
ylabel(yLabelText);
title('ADC channel comparison of two CSV files');

legend('Location', 'best');

% 黑底顯示設定
ax = gca;
ax.Color = 'k';
ax.XColor = 'w';
ax.YColor = 'w';
ax.GridColor = 'w';
ax.MinorGridColor = 'w';

title('ADC channel comparison of two CSV files', 'Color', 'w');
xlabel('Sample in Window', 'Color', 'w');
ylabel(yLabelText, 'Color', 'w');

lgd = legend;
lgd.TextColor = 'w';
lgd.Color = 'k';
lgd.EdgeColor = 'w';

%% 第一份 CSV 統計資訊
fprintf('\n========================================\n');
fprintf('CSV 1：%s\n', filename1);
fprintf('========================================\n');

printStatistics('i_sen', iSenCode1);
printStatistics('Vbus ', vbusCode1);
printStatistics('Vac  ', vacCode1);

%% 第二份 CSV 統計資訊
fprintf('\n========================================\n');
fprintf('CSV 2：%s\n', filename2);
fprintf('========================================\n');

printStatistics('i_sen', iSenCode2);
printStatistics('Vbus ', vbusCode2);
printStatistics('Vac  ', vacCode2);

%% 比較兩份 CSV 的平均值與 Vpp
fprintf('\n========================================\n');
fprintf('兩份 CSV 差異比較：CSV 2 - CSV 1\n');
fprintf('========================================\n');

fprintf('i_sen：mean difference = %.3f, Vpp difference = %g\n', ...
    mean(iSenCode2) - mean(iSenCode1), ...
    peak2peakManual(iSenCode2) - peak2peakManual(iSenCode1));

fprintf('Vbus ：mean difference = %.3f, Vpp difference = %g\n', ...
    mean(vbusCode2) - mean(vbusCode1), ...
    peak2peakManual(vbusCode2) - peak2peakManual(vbusCode1));

fprintf('Vac  ：mean difference = %.3f, Vpp difference = %g\n', ...
    mean(vacCode2) - mean(vacCode1), ...
    peak2peakManual(vacCode2) - peak2peakManual(vacCode1));

%% 區域函式
function printStatistics(signalName, signalData)

    signalVpp = max(signalData) - min(signalData);

    fprintf(['%s：min = %g, max = %g, mean = %.3f, ' ...
             'Vpp = %g ADC code\n'], ...
        signalName, ...
        min(signalData), ...
        max(signalData), ...
        mean(signalData), ...
        signalVpp);
end

function value = peak2peakManual(signalData)
    value = max(signalData) - min(signalData);
end