%% convert_iir_coefficients_q14_22.m
% Convert a second-order IIR filter exported from MATLAB Filter Designer
% into signed 36-bit Q14.22 coefficients.
%
% Required workspace variables:
%   lowpassiir1_Num = [B0 B1 B2]
%   lowpassiir1_Den = [A0 A1 A2]
%
% Q14.22 conversion:
%   integer = round(real_value * 2^22)
%   real_value = integer / 2^22

clc;

%% Check that Filter Designer coefficients exist
if ~exist('lowpassiir1_Num', 'var')
    error(['Workspace variable lowpassiir1_Num was not found. ', ...
        'Export the numerator coefficients from Filter Designer first.']);
end

if ~exist('lowpassiir1_Den', 'var')
    error(['Workspace variable lowpassiir1_Den was not found. ', ...
        'Export the denominator coefficients from Filter Designer first.']);
end

num = double(lowpassiir1_Num(:).');
den = double(lowpassiir1_Den(:).');

if numel(num) ~= 3 || numel(den) ~= 3
    error(['This script expects one second-order IIR section: ', ...
        'three numerator and three denominator coefficients.']);
end

if any(~isfinite(num)) || any(~isfinite(den))
    error('All coefficients must be finite numeric values.');
end

%% Q14.22 settings
wordLength = 36;
fractionBits = 22;
scale = 2^fractionBits;

signedMinimum = -2^(wordLength - 1);
signedMaximum =  2^(wordLength - 1) - 1;

%% Quantize coefficients
qNum = int64(round(num * scale));
qDen = int64(round(den * scale));
qAll = [qNum, qDen];

if any(double(qAll) < signedMinimum) || any(double(qAll) > signedMaximum)
    error('At least one coefficient exceeds the signed 36-bit range.');
end

%% Recover quantized floating-point coefficients
numQuantized = double(qNum) / scale;
denQuantized = double(qDen) / scale;

%% Convert signed integers to 36-bit two''s-complement hexadecimal
hexDigits = ceil(wordLength / 4);   % 36 bits = 9 hexadecimal digits
modulus = 2^wordLength;
hexAll = upper(dec2hex(mod(double(qAll), modulus), hexDigits));

%% Build result table
coefficientName = ["B0"; "B1"; "B2"; "A0"; "A1"; "A2"];
originalValue = [num(:); den(:)];
q14_22Integer = qAll(:);
quantizedValue = [numQuantized(:); denQuantized(:)];
quantizationError = quantizedValue - originalValue;
hex36 = string(hexAll);

q14_22_result = table( ...
    coefficientName, ...
    originalValue, ...
    q14_22Integer, ...
    quantizedValue, ...
    quantizationError, ...
    hex36, ...
    'VariableNames', { ...
        'Coefficient', ...
        'Original', ...
        'Q14_22_Integer', ...
        'Quantized', ...
        'Error', ...
        'Hex36'});

disp('Q14.22 conversion result:');
disp(q14_22_result);

%% Print Verilog parameter declarations
fprintf('\n// Signed 36-bit Q14.22 coefficients\n');
for index = 1:numel(coefficientName)
    fprintf("parameter signed [35:0] %s = 36'sh%s;\n", ...
        coefficientName(index), hexAll(index, :));
end

%% Export convenient variables to the workspace
q14_22_num = qNum;
q14_22_den = qDen;
q14_22_num_quantized = numQuantized;
q14_22_den_quantized = denQuantized;

%% Optional verification of the quantized filter
% Uncomment the following lines to compare the original and quantized
% frequency responses.
%
% Fs = 70000;
% [hOriginal, f] = freqz(num, den, 131072, Fs);
% [hQuantized, ~] = freqz(numQuantized, denQuantized, 131072, Fs);
%
% figure;
% plot(f, 20*log10(abs(hOriginal)), 'DisplayName', 'Original');
% hold on;
% plot(f, 20*log10(abs(hQuantized)), '--', ...
%     'DisplayName', 'Q14.22 quantized');
% grid on;
% xlim([0 100]);
% ylim([-80 5]);
% xlabel('Frequency (Hz)');
% ylabel('Magnitude (dB)');
% title('Original and Q14.22 Quantized IIR Response');
% legend('Location', 'best');
