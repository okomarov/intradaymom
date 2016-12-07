function [ptfret, stats] = estimateTsmom(results, opt, names, varargin)

if ~isempty(opt.DATE_RANGE)
    idx = in(results.dates,opt.DATE_RANGE,'[]');
else
    idx = true(numel(results.dates),1);
end

ptfret.univariate = makeTsmom(results.signal, results.hpr,[],[],[],1);
stats.univariate  = stratstats(results.dates(idx,:), ptfret.univariate(idx,:),'d',0)';

if isempty(opt.NUM_PTF) || opt.NUM_PTF < 2
    return
end

for ii = 1:numel(names)
    f = names{ii};
    if strcmpi(f, 'industry')
        ptfret.(f) = makeTsmomBiv(results, varargin{ii}, struct('PortfolioNumber', numel(unique(varargin{ii}))));
    else
        ptfret.(f) = makeTsmomBiv(results, varargin{ii}, struct('PortfolioNumber',opt.NUM_PTF));
    end
    stats.(f) = stratstats(results.dates(idx,:), ptfret.(f)(idx,:),'d',0)';
end
end
