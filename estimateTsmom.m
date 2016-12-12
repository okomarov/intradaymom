function [ptfret, stats] = estimateTsmom(results, opt, fun, names, varargin)

if ~isempty(opt.DATE_RANGE)
    idx = in(results.dates,opt.DATE_RANGE,'[]');
else
    idx = true(numel(results.dates),1);
end

ptfret.univariate = makeTsmom(results.signal, results.hpr,fun);
stats.univariate  = stratstats(results.dates(idx,:), ptfret.univariate(idx,:),'Frequency','d','IsPercentageReturn',true)';

if isempty(opt.NUM_PTF) || opt.NUM_PTF < 2
    return
end

for ii = 1:numel(names)
    f = names{ii};
    if strcmpi(f, 'industry')
        ptfret.(f) = makeTsmomBiv(results, varargin{ii}, fun, struct('PortfolioNumber', numel(unique(varargin{ii}))));
    else
        ptfret.(f) = makeTsmomBiv(results, varargin{ii}, fun, struct('PortfolioNumber',opt.NUM_PTF));
    end
    stats.(f) = stratstats(results.dates(idx,:), ptfret.(f)(idx,:),'d',0)';
end
end

function out = makeTsmomBiv(results, signal, fun, opts)
out = table();

[bins, countd, ptf_id] = binSignal(signal,opts);
for p = 1:max(ptf_id)
    idx          = bins == p;
    signal       = results.signal;
    signal(~idx) = NaN;
    tmp          = makeTsmom(signal, results.hpr, fun);
    out          = [out renameVarNames(tmp, strcat(getVariableNames(tmp),sprintf('_%d',p)))];
end
end
