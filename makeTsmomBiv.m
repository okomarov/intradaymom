function out = makeTsmomBiv(results, signal, opts)
out = table();

[bins, countd, ptf_id] = binSignal(signal,opts);
for p = 1:max(ptf_id)
    idx          = bins == p;
    signal       = results.signal;
    signal(~idx) = NaN;
    tmp          = makeTsmom(signal, results.hpr,[],[],[],true);
    out          = [out renameVarNames(tmp, strcat(getVariableNames(tmp),sprintf('_%d',p)))];
end
end
