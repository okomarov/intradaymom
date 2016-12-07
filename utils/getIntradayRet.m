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

function ret = estimateIntradayRet(tstart, tend, mst, price_fl, datapath)
permnos = unique(mst.Permno);

% VWAP prices
ST_VWAP = loadVWAP(mst, tstart);
EN_VWAP = loadVWAP(mst, tend);

% Cache by dates
[dates,~,g] = unique(mst.Date);
mst         = cache2cell(mst,g);
price_fl    = cache2cell(price_fl,g);
ST_VWAP     = cache2cell(ST_VWAP, g);
EN_VWAP     = cache2cell(EN_VWAP, g);

% Signal and HPR
N   = numel(dates);
ret = cell(N, 1);

parfor ii = 1:N
    disp(ii)

    signal_st = getPrices(tstart, permnos, mst{ii}, datapath, price_fl{ii}, ST_VWAP{ii});
    signal_en = getPrices(tend  , permnos, mst{ii}, datapath, price_fl{ii}, EN_VWAP{ii});

    % Signal: Filled back half-day ret
    ret{ii} = signal_en./signal_st-1;
end

ret = cat(1,ret{:});
end

function  vwap = loadVWAP(mst, s)
if strcmpi(s.type,'VWAP')
    vwap    = loadresults(sprintf('VWAP_%d_%d', s.duration, s.hhmm*100),'..\results\vwap');
    [~,pos] = ismembIdDate(mst.Permno, mst.Date, vwap.Permno, vwap.Date);
    vwap    = vwap(pos,:);
else
    vwap = zeros(size(mst,1),0);
end
end
