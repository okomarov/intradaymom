function ret = getIntradayRet(tstart, tend, mst, price_fl, datapath)
hash  = DataHash([tstart; tend]);
fname = fullfile('results',sprintf('intraRet_%s.mat',hash(1:10)));
try
    load(fname);
catch
    ret = estimateIntradayRet(tstart, tend, mst, price_fl, datapath);
    save(fname,'ret')
end
end
