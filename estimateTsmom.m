function [ptfret, stats] = estimateTsmom(results, numptf, names, varargin)

% ptfret.univariate       = makeTsmom(results.signal, results.hpr,double(cap{:,2:end}),vol{:,2:end},OPT_.VOL_TARGET);
ptfret.univariate = makeTsmom(results.signal, results.hpr,[],[],[],1);
stats.univariate  = stratstats(results.dates, ptfret.univariate,'d',0)';

if isempty(numptf) || numptf < 2
    return
end

for ii = 1:numel(names)
    f = names{ii};
    if strcmpi(f, 'industry')
        ptfret.(f) = makeTsmomBiv(results, varargin{ii}, struct('PortfolioNumber', numel(unique(varargin{ii}))));
    else
        ptfret.(f) = makeTsmomBiv(results, varargin{ii}, struct('PortfolioNumber',numptf));
    end
    stats.(f) = stratstats(results.dates, ptfret.(f),'d',0)';
end
end
