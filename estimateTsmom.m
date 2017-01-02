function [ptfret, stats, signal, hpr, lvl, dt, h] = estimateTSmom(spec_sig, spec_hpr, data, dates, OPT_, doplot)
signal = getIntradayRet(spec_sig, data.mst, data.price_fl, OPT_.DATAPATH);
hpr    = getIntradayRet(spec_hpr, data.mst, data.price_fl, OPT_.DATAPATH)*100;

if OPT_.RET_USE_OVERNIGHT
    signal = (1+signal) .* (1 + data.reton) - 1;
end

[ptfret, avg_sig] = makeTsmom(signal, hpr);

stats = fstat(dates, ptfret, avg_sig)';

if doplot
    [lvl,dt,h] = plot_cumret(dates, ptfret{:,:}./100, 1, true);
    legend win lose wml long
    legend location northwest
end
end

function stats = fstat(dt,ptfret,signal)
signal = [nanmean(signal,1), NaN(1,size(ptfret,2) - size(signal,2))];
stats  = stratstats(dt, ptfret,'Frequency','d','IsPercentageReturn',true);
stats  = [stats,  table(signal', 'VariableNames',{'Avgsig'})];
end
