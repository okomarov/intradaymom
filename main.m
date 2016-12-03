%% Options
OPT_.NO_MICRO = true;
OPT_.DAY_LAG  = 1;
% OPT_.RET_USE_OVERNIGHT = false;
OPT_.DATAPATH = '..\data\TAQ\sampled\5min\nobad_vw';

OPT_.NUM_PTF = 5;

OPT_.VOL_AVG    = 'e';
OPT_.VOL_LAG    = 60;
OPT_.VOL_SHIFT  = OPT_.VOL_LAG - 1 + OPT_.DAY_LAG;
OPT_.VOL_TARGET = 0.4;

OPT_.REGRESSION_LONG_MINOBS = 10;
OPT_.REGRESSION_LONG_ALPHA  = 0.05;
%% Data

% Index data
mst = loadresults('master');

% Taq open price
price_fl = loadresults('price_fl');
if OPT_.NO_MICRO
    idx      = isMicrocap(price_fl, 'LastPrice',OPT_.DAY_LAG);
    price_fl = price_fl(~idx,:);
end
[~,ia,ib] = intersectIdDate(mst.Permno, mst.Date,price_fl.Permno,price_fl.Date);
mst       = mst(ia,:);
price_fl  = price_fl(ib,:);
% isequal(mst.Date, price_fl.Date)

% Market cap
cap       = getMktCap(mst,OPT_.DAY_LAG);
myunstack = @(tb,vname) sortrows(unstack(tb(:,{'Permno','Date',vname}),vname,'Permno'),'Date');
cap       = myunstack(cap,'Cap');

% Moving average of RV
vol            = loadresults('volInRange123000-160000');
[idx,pos]      = ismembIdDate(vol.Permno, vol.Date, mst.Permno, mst.Date);
vol            = vol(idx,:);
vol.Sigma      = sqrt(tsmovavg(vol.RV5,OPT_.VOL_AVG, OPT_.VOL_LAG,1));
vol(:,[1,2,4]) = lagpanel(vol(:,[1,2,4]),'Permno',OPT_.VOL_SHIFT);
vol            = myunstack(vol,'Sigma');

% Permnos
results.permnos = unique(mst.Permno);
results.nseries = numel(results.permnos);
results.dates   = unique(mst.Date);

% Illiquidity
amihud         = loadresults('illiq');
idx            = ismember(amihud.permnos, results.permnos);
amihud.illiq   = amihud.illiq(:,idx);
amihud.permnos = amihud.permnos(idx);
amihud.illiq   = [NaN(OPT_.DAY_LAG, size(amihud.illiq,2)); 
                  amihud.illiq(1:end-OPT_.DAY_LAG,:)];
% Tick ratios
tick = loadresults('tick');
idx  = ismembIdDate(tick.Permno, tick.Date, mst.Permno, mst.Date);
tick = tick(idx,:);
tick = lagpanel(tick,'Permno',OPT_.DAY_LAG);
tick = myunstack(tick,'Ratio');

clear ia ib pos
%% Signal and HPR
sstart = struct('hhmm', 930,'type','vwap','duration',30);
send   = struct('hhmm',1200,'type','vwap','duration',30);
hstart = struct('hhmm',1230,'type','vwap','duration',30);
hend   = struct('hhmm',1530,'type','vwap','duration',30);
[results.signal, results.hpr] = estimateSignalHpr(sstart, send, hstart, hend, mst, price_fl, OPT_.DATAPATH);

%% TSMOM univariate

% ptfs and stats
results.cap = double(cap{:,2:end});
results.vol = vol{:,2:end}*sqrt(252);
[results.ptfret, results.tsmom] = makeTsmom(results.signal, results.hpr, results.cap, results.vol, OPT_.VOL_TARGET);

results.ptfret_stats = stratstats(results.dates, results.ptfret,'d',0)';
results.Names        = results.ptfret.Properties.VariableNames;

%% TSMOM bivariate
OPT.PortfolioNumber = OPT_.NUM_PTF;

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
results.lvl = plot_cumret(results.dates, results.ptfret, OPT_.VOL_LAG, true);

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
results = regressOnLongOnly(results, OPT_.REGRESSION_LONG_MINOBS, OPT_.REGRESSION_LONG_ALPHA);

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
