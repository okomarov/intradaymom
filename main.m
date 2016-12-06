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

% Permnos
results.permnos = unique(mst.Permno);
results.nseries = numel(results.permnos);
results.dates   = unique(mst.Date);

% Market cap
cap       = getMktCap(mst,OPT_.DAY_LAG);
myunstack = @(tb,vname) sortrows(unstack(tb(:,{'Permno','Date',vname}),vname,'Permno'),'Date');
cap       = myunstack(cap,'Cap');

% Moving average of RV
vol            = loadresults('rv5');
idx            = ismembIdDate(vol.Permno, vol.Date, mst.Permno, mst.Date);
vol            = vol(idx,:);
vol.Sigma      = sqrt(tsmovavg(vol.RV,OPT_.VOL_AVG, OPT_.VOL_LAG,1));
vol(:,[1,2,4]) = lagpanel(vol(:,[1,2,4]),'Permno',OPT_.VOL_SHIFT);
vol            = myunstack(vol,'Sigma');

% Illiquidity
amihud         = loadresults('illiq');
idx            = ismember(amihud.permnos, results.permnos);
amihud.illiq   = amihud.illiq(:,idx);
amihud.permnos = amihud.permnos(idx);
amihud.illiq   = [NaN(OPT_.DAY_LAG, size(amihud.illiq,2));
                  amihud.illiq(1:end-OPT_.DAY_LAG,:)];
[~,pos]        = ismember(results.dates/100, amihud.dates);
amihud.illiq   = amihud.illiq(pos,:);

% Tick ratios
tick = loadresults('tick');
idx  = ismembIdDate(tick.Permno, tick.Date, mst.Permno, mst.Date);
tick = tick(idx,:);
tick = lagpanel(tick,'Permno',OPT_.DAY_LAG);
tick = myunstack(tick,'Ratio');

% Volume
volume = loadresults('volume');
idx    = ismembIdDate(volume.Permno, volume.Date, mst.Permno, mst.Date);
volume = volume(idx,:);
volume = lagpanel(volume,'Permno', OPT_.DAY_LAG);
volume = myunstack(volume,'Vol');

% % Industry - 49 categories seem too many
% industry = loadresults('ff49');
% idx      = ismembIdDate(industry.Permno, industry.Date, mst.Permno, mst.Date);
% industry = industry(idx,:);
% industry = lagpanel(industry,'Permno', OPT_.DAY_LAG);
% industry = myunstack(industry,'FFid');

clear ia ib pos
%% Signal and HPR #1: last half hour
results.signal = getIntradayRet(struct('hhmm', 930,'type','exact'),...
                                struct('hhmm',1200,'type','exact'), mst, price_fl, OPT_.DATAPATH);
results.hpr    = getIntradayRet(struct('hhmm',1530,'type','exact'),...
                                struct('hhmm',1600,'type','exact'), mst, price_fl, OPT_.DATAPATH);
%% Signal and HPR #2: 13:30 to 15:30
results.signal = getIntradayRet(struct('hhmm', 930,'type','exact'),...
                                struct('hhmm',1300,'type','exact'), mst, price_fl, OPT_.DATAPATH);
results.hpr    = getIntradayRet(struct('hhmm',1330,'type','exact'),...
                                struct('hhmm',1530,'type','exact'), mst, price_fl, OPT_.DATAPATH);
%% TSMOM
% Univariate
results.ptfret       = makeTsmom(results.signal, results.hpr, [], [], [],1);
results.ptfret_stats = stratstats(results.dates, results.ptfret,'d',0)';

% Bivariate
[~,pos] = ismember(results.dates/100, amihud.dates);

results.ptfret_illiq = makeTsmomBiv(results, amihud.illiq(pos,:),  struct('PortfolioNumber',OPT_.NUM_PTF));
results.ptfret_cap   = makeTsmomBiv(results, double(cap{:,2:end}), struct('PortfolioNumber',OPT_.NUM_PTF));
results.ptfret_tick  = makeTsmomBiv(results, tick{:,2:end},        struct('PortfolioNumber',OPT_.NUM_PTF));

results.ptfret_illiq_stats = stratstats(results.dates, results.ptfret_illiq,'d',0)';
results.ptfret_cap_stats   = stratstats(results.dates, results.ptfret_cap  ,'d',0)';
results.ptfret_tick_stats  = stratstats(results.dates, results.ptfret_tick ,'d',0)';

% Plot
results.lvl       = plot_cumret(results.dates, results.ptfret      ,  1, true);
results.lvl_size  = plot_cumret(results.dates, results.ptfret_size , 20, true);
results.lvl_illiq = plot_cumret(results.dates, results.ptfret_illiq, 20, true);
results.lvl_cap   = plot_cumret(results.dates, results.ptfret_cap  , 20, true);
results.lvl_tick  = plot_cumret(results.dates, results.ptfret_tick ,  1, true);

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
