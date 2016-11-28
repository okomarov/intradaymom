%% Options
OPT_LAGDAY  = 1;
OPT_NOMICRO = true;

% OPT_HASWEIGHTS = true;
% OPT_INDEP_SORT = false;

OPT_PTFNUM = 5;
% OPT_PTFNUM_DOUBLE = [5,5];

% Choose one from the dictionary
OPT_PRICE_TYPE = 2;
OPT_TYPE_DICT  = {1, 'taq_exact'
                  2, 'taq_vwap'
                  3, 'taq_exact/vwap'};
OPT_PRICE_TYPE = OPT_TYPE_DICT{ismember([OPT_TYPE_DICT{:,1}], OPT_PRICE_TYPE),2};

OPT_SIGNAL_START = 930;
OPT_SIGNAL_END   = 1200;
OPT_HPR_START    = 1230;
OPT_HPR_END      = 1530;

OPT_VOL_AVG    = 's';
OPT_VOL_LAG    = 40;
OPT_VOL_SHIFT  = OPT_VOL_LAG - 1 + OPT_LAGDAY;
OPT_VOL_TARGET = 0.4;

OPT_REGRESSION_LONG_MINOBS = 10;
OPT_REGRESSION_LONG_ALPHA  = 0.05;

%% Data
datapath = '..\data\TAQ\sampled\5min\nobad';

% Index data
mst = loadresults('master');

% Taq open price
price_fl = loadresults('price_fl');
if OPT_NOMICRO
    idx      = isMicrocap(price_fl, 'LastPrice',OPT_LAGDAY);
    price_fl = price_fl(~idx,:);
end

[~,ia,ib] = intersectIdDate(mst.Permno, mst.Date,price_fl.Permno,price_fl.Date);
mst       = mst(ia,:);
price_fl  = price_fl(ib,:);
% isequal(mst.Date, price_fl.Date)

% Market cap
cap       = getMktCap(mst,OPT_LAGDAY);
myunstack = @(tb,vname) sortrows(unstack(tb(:,{'Permno','Date',vname}),vname,'Permno'),'Date');
cap       = myunstack(cap,'Cap');

% 40-day moving average lagged 1 standard deviation
vol            = loadresults('volInRange123000-160000');
[idx,pos]      = ismembIdDate(vol.Permno, vol.Date, mst.Permno, mst.Date);
vol            = vol(idx,:);
vol.Sigma      = sqrt(tsmovavg(vol.RV5,OPT_VOL_AVG, OPT_VOL_LAG,1));
vol(:,[1,2,4]) = lagpanel(vol(:,[1,2,4]),'Permno',OPT_VOL_SHIFT);
vol            = myunstack(vol,'Sigma');

% Permnos
results.permnos = unique(mst.Permno);
results.nseries = numel(results.permnos);

% Illiquidity
amihud         = loadresults('illiq');
idx            = ismember(amihud.permnos, results.permnos);
amihud.illiq   = amihud.illiq(:,idx);
amihud.permnos = amihud.permnos(idx);
amihud.illiq   = [NaN(OPT_LAGDAY, size(amihud.illiq,2)); 
                  amihud.illiq(1:end-OPT_LAGDAY,:)];

% Tick ratios
tick = loadresults('tick');
idx  = ismembIdDate(tick.Permno, tick.Date, mst.Permno, mst.Date);
tick = tick(idx,:);
tick = lagpanel(tick,'Permno',OPT_LAGDAY);
tick = myunstack(tick,'Ratio');

switch OPT_PRICE_TYPE
    case 'taq_vwap'
        p{1} = loadresults(sprintf('VWAP_30_%d', OPT_SIGNAL_START*100),'..\results\vwap');
        p{2} = loadresults(sprintf('VWAP_30_%d', OPT_SIGNAL_END*100),'..\results\vwap');
        p{3} = loadresults(sprintf('VWAP_30_%d', OPT_HPR_START*100),'..\results\vwap');
        p{4} = loadresults(sprintf('VWAP_30_%d', OPT_HPR_END*100),'..\results\vwap');
        for ii = 1:4
            [~,pos] = ismembIdDate(mst.Permno, mst.Date, p{ii}.Permno, p{ii}.Date);
            p{ii}   = p{ii}(pos,:);
        end
end
clear ia ib pos

%% Cache by dates
[results.dates,~,g] = unique(mst.Date);
mst                 = cache2cell(mst,g);
price_fl            = cache2cell(price_fl,g);

SIGNAL_ST = cache2cell(p{1},g);
SIGNAL_EN = cache2cell(p{2},g);
HPR_ST    = cache2cell(p{3},g);
HPR_EN    = cache2cell(p{4},g);
clear p g

%% Signal and HPR
results.N      = numel(results.dates);
results.signal = NaN(results.N, results.nseries);
results.hpr    = NaN(results.N, results.nseries);

for ii = 2:results.N
    switch OPT_PRICE_TYPE
        case 'taq_exact'
            s = struct('datapath',datapath, 'mst', mst{ii},'price_fl',price_fl{ii},...
                       'START_SIGNAL', OPT_SIGNAL_START,'END_SIGNAL', OPT_SIGNAL_END,...
                       'START_HPR', OPT_HPR_START,'END_HPR',OPT_HPR_END);

        case 'taq_vwap'
            s = struct('START_SIGNAL', SIGNAL_ST{ii},'END_SIGNAL', SIGNAL_EN{ii},...
                       'START_HPR', HPR_ST{ii},'END_HPR',HPR_EN{ii});
        case 'taq_exact/vwap'
    end

    [signal_st, signal_en, hpr_st, hpr_en] = getPrices(OPT_PRICE_TYPE, results.permnos, s);

    % Signal: Filled back half-day ret
    results.signal(ii,:) = signal_en./signal_st-1;
    % hpr with 5 min skip
    results.hpr(ii,:)    = hpr_en./hpr_st-1;
end
clear signal_en signal_st hpr_en hpr_st s

%% TSMOM univariate

% ptfs and stats
results.cap = double(cap{:,2:end});
results.vol = vol{:,2:end}*sqrt(252);
[results.ptfret, results.tsmom] = makeTsmom(results.signal, results.hpr, results.cap, results.vol, OPT_VOL_TARGET);

results.ptfret_stats = stratstats(results.dates, results.ptfret,'d',0)';
results.Names        = results.ptfret.Properties.VariableNames;

%% TSMOM bivariate
OPT.PortfolioNumber = OPT_PTFNUM;

% Sorted on illiquidity
[~,pos]      = ismember(results.dates/100, amihud.dates);
amihud.illiq = amihud.illiq(pos,:);
results      = makeTsmomBiv(results,amihud.illiq, 'illiq', OPT);

% Sorted on mkt cap
results = makeTsmomBiv(results, double(cap{:,2:end}), 'cap', OPT);

% Sorted on tick ratio
results = makeTsmomBiv(results, tick{:,2:end}, 'tick', OPT);
%% Plot

% Cumulated returns univariate
results.lvl = plot_cumret(results.dates, results.ptfret, OPT_VOL_LAG, true);

% Bivariate and tsmom ew
plot_cumret(results.dates, results.ptfret_illiq, 20, true);
plot_cumret(results.dates, results.ptfret_cap  , 20, true);
plot_cumret(results.dates, results.ptfret_tick ,  1, true);

% Correctly predicted and long positions
total   = sum(~isnan(results.signal),2);
correct = sum(sign(results.signal) == sign(results.hpr),2);
long    = sum(results.signal > 0,2);

% subplot(211)
plot(yyyymmdd2datetime(results.dates), movmean([correct,long]./total,[252,0])*100)
title '252-day moving averages'
legend 'correctly predicted' 'long positions'
ytickformat('percentage')

%% Regress on long-only
results = regressOnLongOnly(results, OPT_REGRESSION_LONG_MINOBS, OPT_REGRESSION_LONG_ALPHA);

%% RA factors
factors = loadresults('RAfactors');

[~,ia,ib] = intersect(results.dates, factors.Date);
ptfret_e  = ptfret_e(ia);
ptfret_w  = ptfret_w(ia);
factors   = factors(ib,:);
n         = size(ptfret_e,1);
opts      = {'intercept',false,'display','off','type','HAC','bandwidth',floor(4*(n/100)^(2/9))+1,'weights','BT'};
f         = @(x,y)  hac(x, y, opts{:});

[~,se,coeff] = f([ones(n,1), factors{:,[2:6,8:9]}*100], ptfret_e*100);
tratio       = coeff./se;
pval         = 2 * normcdf(-abs(tratio));

[~,se,coeff] = f([ones(n,1), factors{:,[2:6,8:9]}*100], ptfret_w*100);
tratio       = coeff./se;
pval         = 2 * normcdf(-abs(tratio));
