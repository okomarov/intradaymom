function [ptfret, stats, signal, hpr, lvl, dt, h] = estimateXSmom(spec_sig, spec_hpr, mst, price_fl, reton, OPT_, doplot, dates)
signal = getIntradayRet(spec_sig, mst, price_fl, OPT_.DATAPATH);
hpr    = getIntradayRet(spec_hpr, mst, price_fl, OPT_.DATAPATH)*100;

if OPT_.RET_USE_OVERNIGHT
    signal = (1+signal) .* (1 + reton) - 1;
end

[ptfret, ~, ~, avg_sig] = portfolio_sort(hpr, signal,'PortfolioNumber',OPT_.NUM_PTF);

ptfret = array2table(ptfret);
stats  = fstat(dates, ptfret, avg_sig)';

if doplot
    [lvl,dt,h] = plot_cumret(dates, ptfret{:,:}./100, 1, true);
    legend(ptfret.Properties.VariableNames)
    legend location northwest
end
end

function stats = fstat(dt,ptfret,signal)
signal = [nanmean(signal,1), NaN(1,size(ptfret,2) - size(signal,2))];
stats  = stratstats(dt, ptfret,'Frequency','d','IsPercentageReturn',true);
stats  = [stats,  table(signal', 'VariableNames',{'Avgsig'})];
end
