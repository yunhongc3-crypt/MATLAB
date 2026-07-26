function [dataTable, ilaInfo] = readVivadoIlaCsv(filename)
%READVIVADOILACSV Read a Vivado ILA CSV according to its Radix row.
%
%   [dataTable, ilaInfo] = readVivadoIlaCsv(filename)
%
% Vivado ILA CSV format:
%   row 1: signal names
%   row 2: radix definitions, for example UNSIGNED or HEX
%   row 3 onward: captured samples
%
% HEX columns are converted with hex2dec. UNSIGNED/DECIMAL columns are
% converted with str2double. Therefore values such as "400" in a HEX
% column become decimal 1024, rather than decimal 400.

    if ~isfile(filename)
        error('CSV file not found: %s', filename);
    end

    rawCell = readcell(filename, 'Delimiter', ',');

    if size(rawCell, 1) < 3
        error('The CSV must contain a header row, a Radix row, and data.');
    end

    originalNames = string(rawCell(1, :));
    radixText = upper(strtrim(string(rawCell(2, :))));
    rawData = rawCell(3:end, :);

    numberOfColumns = numel(originalNames);
    numberOfRows = size(rawData, 1);

    dataTable = table();
    validNames = strings(1, numberOfColumns);

    for columnIndex = 1:numberOfColumns
        baseName = matlab.lang.makeValidName(char(originalNames(columnIndex)), ...
            'ReplacementStyle', 'underscore');
        validName = matlab.lang.makeUniqueStrings(baseName, ...
            dataTable.Properties.VariableNames);
        validNames(columnIndex) = string(validName);

        columnText = string(rawData(:, columnIndex));

        if contains(radixText(columnIndex), 'HEX')
            values = parseHexColumn(columnText);
        else
            values = str2double(strtrim(columnText));
        end

        dataTable.(validName) = reshape(values, numberOfRows, 1);
    end

    ilaInfo.FileName = filename;
    ilaInfo.OriginalVariableNames = originalNames;
    ilaInfo.VariableNames = validNames;
    ilaInfo.Radix = radixText;
    ilaInfo.NumberOfRows = numberOfRows;
    ilaInfo.NumberOfColumns = numberOfColumns;

    dataTable.Properties.UserData = ilaInfo;
end

function values = parseHexColumn(columnText)
    values = nan(numel(columnText), 1);

    for rowIndex = 1:numel(columnText)
        token = strtrim(columnText(rowIndex));

        if ismissing(token) || strlength(token) == 0
            continue;
        end

        % Supported examples: ABC, 0xABC, 12'hABC, and ABC_h.
        token = erase(token, '_');
        token = regexprep(token, '^\d+''[hH]', '');
        token = regexprep(token, '^0[xX]', '');
        token = regexprep(token, '[hH]$', '');

        if ~isempty(regexp(token, '^[0-9A-Fa-f]+$', 'once'))
            values(rowIndex) = hex2dec(char(token));
        end
    end
end
