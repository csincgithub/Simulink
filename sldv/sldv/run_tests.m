function run_tests(mdl, sldv_data_file, coverage_report, model_results, model_name, harness, system_under_test, ...
                    unit_test_dir, opts)

% -------------------------------------------------------------------------------------------------------------------
% Get the number of test cases that were produced by SLDV TestGeneration.
% -------------------------------------------------------------------------------------------------------------------
matObj = matfile(sldv_data_file);
m = matObj.sldvData;
tc = m.('TestCases');
num_testcases = numel(tc);
info = m.('AnalysisInformation');
num_signals_in = numel(info.InputPortInfo);
%num_signals_out = numel(info.OutputPortInfo);

% -------------------------------------------------------------------------------------------------------------------
% Enable data logging for each blocks (out) port handles
% -------------------------------------------------------------------------------------------------------------------
block_handles = find_system(mdl, 'Type', 'Block');
num_blocks = numel(block_handles);
for blk_idx = 1:num_blocks
    port_handle = get_param(block_handles(blk_idx), 'PortHandles');
    if isempty(port_handle.Outport) == false
        port_handle.Outport;
        set_param(port_handle.Outport, 'DataLogging', 'on');
    else
        % skip the model's Outport blocks
    end
end

% -------------------------------------------------------------------------------------------------------------------
% Enable to write input attributes to unit test template
% -------------------------------------------------------------------------------------------------------------------
block_path_arr = {};
signal_labels_arr = {};
data_type_arr = {};
complexity_arr = {};
sample_time_arr = {};

for idx = 1:num_signals_in
    block_path = info.InputPortInfo{idx}.BlockPath;
    signal_labels = info.InputPortInfo{idx}.SignalLabels;
%    signal_name = info.InputPortInfo{idx}.SignalName;
    data_type = info.InputPortInfo{idx}.DataType;
    complexity = info.InputPortInfo{idx}.Complexity;
    sample_time = info.InputPortInfo{idx}.SampleTime;
%    signal_hierarchy = info.InputPortInfo{idx}.SignalHierarchy;
    block_path_arr(end + 1) = cellstr(block_path);
    signal_labels_arr(end + 1) = cellstr(signal_labels);
    data_type_arr(end + 1) = cellstr(data_type);
    complexity_arr(end + 1) = cellstr(complexity);
%    sample_time_arr(end + 1) = num2cell(sample_time) % , num_signals_in);
end
% Write inputs to unit test spreadsheet
unit_test_xl = fullfile(unit_test_dir, 'ut_dev.xlsx');
block_path_vec = block_path_arr';
signal_labels_vec = signal_labels_arr';
data_type_vec = data_type_arr';
complexity_vec = complexity_arr';
sample_time_vec = sample_time_arr';
writecell(block_path_vec, unit_test_xl, 'Sheet', 'INPUTS', 'Range', 'A2');  % BLOCK PATH
writecell(signal_labels_vec, unit_test_xl, 'Sheet', 'INPUTS', 'Range', 'B2');  % SIGNAL LABEL
writecell(data_type_vec, unit_test_xl, 'Sheet', 'INPUTS', 'Range', 'C2');  % DATA TYPE
writecell(complexity_vec, unit_test_xl, 'Sheet', 'INPUTS', 'Range', 'D2');  % COMPLEXITY
writecell(sample_time_vec, unit_test_xl, 'Sheet', 'INPUTS', 'Range', 'E2');  % SAMPLE TIME

% -------------------------------------------------------------------------------------------------------------------
% Set options and run tests
% -------------------------------------------------------------------------------------------------------------------
runOpts = sldvruntestopts;
runOpts.coverageEnabled = true;  % Put in constants.py
[outData, covData] = sldvruntest(mdl, sldv_data_file, runOpts);
cvhtml(coverage_report, covData);
cvsave(fullfile(model_results, 'existing_coverage.cvt'), covData);

% -------------------------------------------------------------------------------------------------------------------
% Get I/O data for each test case
% -------------------------------------------------------------------------------------------------------------------
for tidx = 1:num_testcases
    test_case = tc(tidx).('testCaseId');
    var_names_in = {'Time'};
%    xout = outData(tidx).find('xout_sldvruntest') % state data
    logsout = outData(tidx).find('logsout_sldvruntest');
    num_elements = logsout.numElements();
    block_name_arr = {};

    % Values per block for the current test case
    for eidx = 1:num_elements
        % ---------------------------------------DEV--------------------------------------------------------------
        % is_system_output = contains(logsout{eidx}.Name, "dvOutputSignalLogger");
        % ---------------------------------------END--------------------------------------------------------------
        block_path = logsout{eidx}.BlockPath;
        [~, block_name] = fileparts(block_path.getBlock(1));
        block_data = logsout{eidx}.Values.Data
%        time_steps = numel(block_data)
        inter_arr(1:numel(block_data), eidx + 1) = block_data;

        % Get the index of the duplicate name and count the number of occurences
        idx = find(strcmpi(block_name_arr, block_name));
        num_occur = nnz(strcmp(block_name_arr, block_name));
        num_occur_str = num2str(num_occur);
        num_occur_cat = strcat('_', num_occur_str);

        if num_occur == 0
            block_name_unique = block_name;
        else
            block_name_unique = insertAfter(block_name, block_name, num_occur_cat);
        end
        block_name_arr(end + 1) = cellstr(block_name_unique);
    end

    % Write data to spreadsheet - this includes input, output, and intermediate values.
    final_name_arr = [{'Time'}, block_name_arr];  % Concat with time
    inter_table = array2table(inter_arr, 'VariableNames', final_name_arr);
    writetable(inter_table, fullfile(model_results, insertBefore('_ut.xls', '_', model_name)),...
    'Sheet', insertAfter('TC', 'C', num2str(test_case)));
end
