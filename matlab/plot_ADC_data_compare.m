%% plot_ADC_data_compare.m
clear; clc; close all;

filename1 = 'ADC_data_380_0721.csv';
filename2 = 'ADC_data_380.csv';
plotInVoltage = false;
adcFullScaleVoltage = 1.0;
adcMaxCode = 4095;

scriptPath = fileparts(mfilename('fullpath'));
repoPath = fileparts(scriptPath);
filePath1 = fullfile(repoPath,'CSV',filename1);
filePath2 = fullfile(repoPath,'CSV',filename2);

if ~isfile(filePath1), error('CSV file not found: %s',filePath1); end
if ~isfile(filePath2), error('CSV file not found: %s',filePath2); end

data1 = readmatrix(filePath1,'NumHeaderLines',2);
data2 = readmatrix(filePath2,'NumHeaderLines',2);
if size(data1,2)<6 || size(data2,2)<6
    error('Each CSV must contain at least 6 columns.');
end

data1 = data1(all(~isnan(data1(:,1:6)),2),:);
data2 = data2(all(~isnan(data2(:,1:6)),2),:);

x1 = data1(:,2); i1 = data1(:,4); vbus1 = data1(:,5); vac1 = data1(:,6);
x2 = data2(:,2); i2 = data2(:,4); vbus2 = data2(:,5); vac2 = data2(:,6);

if plotInVoltage
    scale = adcFullScaleVoltage/adcMaxCode;
    i1=i1*scale; vbus1=vbus1*scale; vac1=vac1*scale;
    i2=i2*scale; vbus2=vbus2*scale; vac2=vac2*scale;
    yText='XADC input voltage (V)';
else
    yText='ADC code';
end

figure('Name','Two CSV ADC Comparison','Color','k'); hold on;
plot(x1,i1,'-','LineWidth',1.2,'DisplayName','i\_sen - CSV 1');
plot(x1,vbus1,'-','LineWidth',1.2,'DisplayName','Vbus - CSV 1');
plot(x1,vac1,'-','LineWidth',1.2,'DisplayName','Vac - CSV 1');
plot(x2,i2,'--','LineWidth',1.2,'DisplayName','i\_sen - CSV 2');
plot(x2,vbus2,'--','LineWidth',1.2,'DisplayName','Vbus - CSV 2');
plot(x2,vac2,'--','LineWidth',1.2,'DisplayName','Vac - CSV 2');
hold off; grid on; box on;

ax=gca; ax.Color='k'; ax.XColor='w'; ax.YColor='w'; ax.GridColor=[0.5 0.5 0.5];
xlabel('Sample in Window','Color','w'); ylabel(yText,'Color','w');
title('ADC channel comparison of two CSV files','Color','w');
lgd=legend('Location','best'); lgd.TextColor='w'; lgd.Color='k'; lgd.EdgeColor='w';

fprintf('\nCSV 1: %s\n',filename1);
printStats('i_sen',data1(:,4)); printStats('Vbus',data1(:,5)); printStats('Vac',data1(:,6));
fprintf('\nCSV 2: %s\n',filename2);
printStats('i_sen',data2(:,4)); printStats('Vbus',data2(:,5)); printStats('Vac',data2(:,6));

function printStats(name,x)
fprintf('%s: min=%g, max=%g, mean=%.3f, Vpp=%g ADC code\n',name,min(x),max(x),mean(x),max(x)-min(x));
end
