function set_range_limits(mdl, range_limits)
    %%% Set range limits for all inport blocks %%%
    inports = find_system(mdl,'regexp','on','blocktype','Inport');
    inport_lim_arr = struct2cell(range_limits);
    num_inports = numel(fieldnames(range_limits)); % get number of elements in struct

    for idx = 1:num_inports
        inports(idx);
        getfullname(inports(idx));
        minmax = inport_lim_arr{idx};
        min = minmax.('OutMin');
        max = minmax.('OutMax');
        set_param(inports(idx), 'OutMin', sprintf('%d', min));
        set_param(inports(idx), 'OutMax', sprintf('%d', max));
%        get_param(inports(idx), 'OutMin');
%        get_param(inports(idx), 'OutMax');
    end

end
