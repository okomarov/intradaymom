function [signal, hpr] = estimateSignalHpr(sstart,send,hstart,hend, mst, price_fl, datapath)

% Permnos
permnos = unique(mst.Permno);

% VWAP prices
SIGNAL_ST_VWAP = loadVWAP(mst, sstart);
SIGNAL_EN_VWAP = loadVWAP(mst, send);
HPR_ST_VWAP    = loadVWAP(mst, hstart);
HPR_EN_VWAP    = loadVWAP(mst, hend);

% Cache by dates
[dates,~,g] = unique(mst.Date);
mst         = cache2cell(mst,g);
price_fl    = cache2cell(price_fl,g);

SIGNAL_ST_VWAP = cache2cell(SIGNAL_ST_VWAP, g);
SIGNAL_EN_VWAP = cache2cell(SIGNAL_EN_VWAP, g);
HPR_ST_VWAP    = cache2cell(HPR_ST_VWAP, g);
HPR_EN_VWAP    = cache2cell(HPR_EN_VWAP,g);

% Signal and HPR
N      = numel(dates);
signal = cell(N, 1);
hpr    = cell(N, 1);

for ii = 1:N
    disp(ii)

    signal_st = getPrices(sstart, permnos, mst{ii}, datapath, price_fl{ii}, SIGNAL_ST_VWAP{ii});
    signal_en = getPrices(send  , permnos, mst{ii}, datapath, price_fl{ii}, SIGNAL_EN_VWAP{ii});
    hpr_st    = getPrices(hstart, permnos, mst{ii}, datapath, price_fl{ii}, HPR_ST_VWAP{ii});
    hpr_en    = getPrices(hend  , permnos, mst{ii}, datapath, price_fl{ii}, HPR_EN_VWAP{ii});

    % Signal: Filled back half-day ret
    signal{ii} = signal_en./signal_st-1;
    % hpr with 5 min skip
    hpr{ii}    = hpr_en./hpr_st-1;
end

signal = cat(1,signal{:});
hpr    = cat(1,hpr{:});
end

function  vwap = loadVWAP(mst, s)
if strcmpi(s.type,'VWAP')
    vwap    = loadresults(sprintf('VWAP_%d_%d', s.duration, s.hhmm*100),'..\results\vwap');
    [~,pos] = ismembIdDate(mst.Permno, mst.Date, vwap.Permno, vwap.Date);
    vwap    = vwap(pos,:);
else
    vwap    = zeros(size(mst,1),0);
end
end
