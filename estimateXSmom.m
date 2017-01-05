function [ptfret, stats, signal, hpr, lvl, dt, h] = estimateXSmom(spec_sig, spec_hpr, data, dates, OPT_, doplot)
signal = getIntradayRet(spec_sig, data.mst, data.price_fl, OPT_.DATAPATH);
hpr    = getIntradayRet(spec_hpr, data.mst, data.price_fl, OPT_.DATAPATH)*100;

if OPT_.RET_USE_OVERNIGHT
    signal = (1+signal) .* (1 + data.reton) - 1;
end

[ptfret, ~, ~, avg_sig] = portfolio_sort(hpr, signal,'PortfolioNumber',OPT_.NUM_PTF_UNI);

ptfret = array2table([ptfret nanmean(hpr,2)]);
stats  = fstat(dates, ptfret, [avg_sig, nanmean(signal,2)])';

if doplot
    [lvl,dt,h] = plot_cumret(dates, ptfret{:,:}./100, 1, true);
    legend(ptfret.Properties.VariableNames)
    legend location northwest
end
end

function stats = fstat(dt,ptfret,signal)
signal = nanmean(signal,1);
stats  = stratstats(dt, ptfret,'Frequency','d','IsPercentageReturn',true);
stats  = [stats,  table(signal', 'VariableNames',{'Avgsig'})];
end
