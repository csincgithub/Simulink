function run_tests(mdl, sldv_data_file, coverage_report, model_results, model_name, harness, system_under_test, ...
                    unit_test_dir, opts)

% -------------------------------------------------------------------------------------------------------------------
% Get the number of test cases that were produced by SLDV TestGeneration.
% -------------------------------------------------------------------------------------------------------------------
matObj = matfile(sldv_data_file);
m = matObj.sldvData;
tc = m.('TestCases');
num_testcases = numel(tc);
%info = m.('AnalysisInformation');

% -------------------------------------------------------------------------------------------------------------------
% Enable data logging for each blocks (out) port handles
% -------------------------------------------------------------------------------------------------------------------

block_handles = find_system(mdl, 'Type', 'Block');
num_blocks = numel(block_handles);
for blk_idx = 1:num_blocks
    ph = get_param(block_handles(blk_idx), 'PortHandles');
    if isempty(ph.Outport) == false
        ph.Outport;
        set_param(ph.Outport, 'DataLogging', 'on');
    else
        % skip the model's Outport blocks
    end
end

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

    % Write all values to unit test template. Include In, Out, and intermediate.
    final_name_arr = [{'Time'}, block_name_arr];  % Concat with time
    inter_table = array2table(inter_arr, 'VariableNames', final_name_arr);
    writetable(inter_table, fullfile(model_results, insertBefore('_UT.xls', '_', model_name)),...
    'Sheet', insertAfter('TC', 'C', num2str(test_case)));
end
