function results = makeTsmomBiv(results, signal, label, opts)
field           = ['ptfret_' label];
results.(field) = table();

[bins, countd, ptf_id] = binSignal(signal,opts);
for p = 1:max(ptf_id)
    idx          = bins == p;
    signal       = results.signal;
    signal(~idx) = NaN;
    tmp          = makeTsmom(signal, results.hpr,[],[],[],true);

    results.(field) = [results.(field) renameVarNames(tmp, strcat(getVariableNames(tmp),sprintf('_%d',p)))];
end
end
