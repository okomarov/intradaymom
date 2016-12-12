%% Options
OPT_.NO_MICRO          = true;
OPT_.DAY_LAG           = 1;
OPT_.RET_USE_OVERNIGHT = false;
OPT_.DATAPATH          = '..\data\TAQ\sampled\5min\nobad_vw';

OPT_.NUM_PTF = 3;

OPT_.DATE_RANGE = [];
% OPT_.DATE_RANGE = [-inf, 20010431];

OPT_.VOL_AVG    = 'e';
OPT_.VOL_LAG    = 60;
OPT_.VOL_SHIFT  = OPT_.VOL_LAG - 1 + OPT_.DAY_LAG;
OPT_.VOL_TARGET = 0.4;

OPT_.REGRESSION_LONG_MINOBS = 10;
OPT_.REGRESSION_LONG_ALPHA  = 0.05;
%% Data
try
    load data_snapshot.mat
catch
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
    cap       = log(double(cap{:,2:end}));

    % Overnight
    reton          = loadresults('return_intraday_overnight','..\hfandlow\results');
    [~,pos]        = ismembIdDate(mst.Permno, mst.Date, reton.Permno, reton.Date);
    mst.RetCO(:,1) = reton.RetCO(pos);
    mst.RetCO      = nan2zero(mst.RetCO);
    reton          = myunstack(mst,'RetCO');
    reton          = double(reton{:,2:end});

    % Moving average of RV
    vol            = loadresults('rv5');
    idx            = ismembIdDate(vol.Permno, vol.Date, mst.Permno, mst.Date);
    vol            = vol(idx & ~isnan(vol.RV),:);
    vol.Sigma      = sqrt(tsmovavg(vol.RV,OPT_.VOL_AVG, OPT_.VOL_LAG,1));
    vol(:,[1,2,4]) = lagpanel(vol(:,[1,2,4]),'Permno',OPT_.VOL_SHIFT);
    vol            = myunstack(vol,'Sigma');
    vol            = sqrt(252) * vol{:,2:end};

    % Illiquidity
    amihud         = loadresults('illiq');
    idx            = ismember(amihud.permnos, results.permnos);
    amihud.illiq   = amihud.illiq(:,idx);
    amihud.permnos = amihud.permnos(idx);
    amihud.illiq   = [NaN(OPT_.DAY_LAG, size(amihud.illiq,2));
                      amihud.illiq(1:end-OPT_.DAY_LAG,:)];
    [~,pos]        = ismember(results.dates/100, amihud.dates);
    amihud.illiq   = amihud.illiq(pos,:);
    amihud         = amihud.illiq;

    % Tick ratios
    tick = loadresults('tick');
    idx  = ismembIdDate(tick.Permno, tick.Date, mst.Permno, mst.Date);
    tick = tick(idx,:);
    tick = lagpanel(tick,'Permno',OPT_.DAY_LAG);
    tick = myunstack(tick,'Ratio');
    tick = tick{:,2:end};

    % Volume
    volume     = loadresults('volume');
    idx        = ismembIdDate(volume.Permno, volume.Date, mst.Permno, mst.Date);
    volume     = volume(idx,:);
    volume     = convertColumn(volume,'double','Vol');
    volume.Vol = tsmovavg(volume.Vol, 's', OPT_.VOL_LAG,1);
    volume     = lagpanel(volume,'Permno', OPT_.VOL_SHIFT);
    volume     = myunstack(volume,'Vol');
    volume     = log(volume{:,2:end});

    % % Industry - 49 categories seem too many
    % industry = loadresults('ff49');
    % idx      = ismembIdDate(industry.Permno, industry.Date, mst.Permno, mst.Date);
    % industry = industry(idx,:);
    % industry = lagpanel(industry,'Permno', OPT_.DAY_LAG);
    % industry = myunstack(industry,'FFid');
    save data_snapshot.mat
    clear ia ib pos idx
end
%% Correlations characteristics
names   = {'size','illiq','tick','vol','volume'};
corrmat = corrxs(cat(3, cap, amihud, tick, vol, volume), names);
%% Last half: exact
clear specs
specs(1) = struct('hhmm', 930,'type','exact');
specs(2) = struct('hhmm',1200,'type','exact');
specs(3) = struct('hhmm',1530,'type','exact');
specs(4) = struct('hhmm',1600,'type','exact');
fun      = @(win,los) win-los;
%% Last half: vwap
clear specs
specs(1) = struct('hhmm', 930,'type','exact','duration',0);
specs(2) = struct('hhmm',1200,'type','exact','duration',0);
specs(3) = struct('hhmm',1530,'type','vwap' ,'duration',5);
specs(4) = struct('hhmm',1555,'type','vwap' ,'duration',5);
fun      = @(win,los) win-los;
%% Afternoon: exact
clear specs
specs(1) = struct('hhmm', 930,'type','exact');
specs(2) = struct('hhmm',1300,'type','exact');
specs(3) = struct('hhmm',1330,'type','exact');
specs(4) = struct('hhmm',1530,'type','exact');
fun      = @(win,los) win-los;
%% Afternoon: vwap
clear specs
specs(1) = struct('hhmm', 930,'type','exact','duration',0);
specs(2) = struct('hhmm',1300,'type','exact','duration',0);
specs(3) = struct('hhmm',1330,'type','vwap' ,'duration',5);
specs(4) = struct('hhmm',1525,'type','vwap' ,'duration',5);
fun      = @(win,los) win-los;
%% Second last: vwap
clear specs
specs(1) = struct('hhmm', 930,'type','exact','duration',0);
specs(2) = struct('hhmm',1300,'type','exact','duration',0);
specs(3) = struct('hhmm',1500,'type','vwap','duration',5);
specs(4) = struct('hhmm',1525,'type','vwap','duration',5);
fun      = @(win,los) win-los;
%% Guofu: vwap
clear specs
specs(1) = struct('hhmm', 930,'type','exact','duration',0);
specs(2) = struct('hhmm',1000,'type','exact','duration',0);
specs(3) = struct('hhmm',1530,'type','vwap','duration',5);
specs(4) = struct('hhmm',1555,'type','vwap','duration',5);
fun      = @(win,los) win-los;
%% TSMOM
results.signal = getIntradayRet(specs(1),specs(2), mst, price_fl, OPT_.DATAPATH);
results.hpr    = getIntradayRet(specs(3),specs(4), mst, price_fl, OPT_.DATAPATH)*100;

if OPT_.RET_USE_OVERNIGHT
    results.signal = (1+results.signal) .* (1 + reton) - 1;
end

% Univariate
[results.ptfret.univariate, avg_sig] = makeTsmom(results.signal, results.hpr, fun);

fstat = @(dt,ptfret,signal) [stratstats(dt, ptfret,'Frequency','d','IsPercentageReturn',true),...
                             table([nanmean(signal,1), NaN(1,size(ptfret,2) - size(signal,2))]',...
                             'VariableNames',{'Avgsig'})] ;

results.stats.univariate = fstat(results.dates, results.ptfret.univariate,avg_sig)';

plot_cumret(results.dates, results.ptfret.univariate{:,:}./100, 1, true);
legend win lose wml long
legend location northwest
%% XS
results.signal = getIntradayRet(specs(1),specs(2), mst, price_fl, OPT_.DATAPATH);
results.hpr    = getIntradayRet(specs(3),specs(4), mst, price_fl, OPT_.DATAPATH)*100;

if OPT_.RET_USE_OVERNIGHT
    results.signal = (1+results.signal) .* (1 + reton) - 1;
end

% [results.ptfret, results.stats] = estimateTsmom(results, OPT_, names, fun, ...
%                             cap, amihud, tick, vol, volume, results.signal); 

[results.ptfret.xs, ~, ~, avg_sig] = portfolio_sort(results.hpr, results.signal,'PortfolioNumber',5);
results.ptfret.xs                  = array2table(results.ptfret.xs);
results.stats.xs              = fstat(results.dates, results.ptfret.xs,avg_sig)';

plot_cumret(results.dates, results.ptfret.xs{:,:}./100, 1, true);
legend 1 2 3 4 5
legend location northwest

% getSorts = @(results, feat) reshape(results.stats.(feat){'Annret',:},3,[]);
% [getSorts(results,names{1}); getSorts(results,names{2});getSorts(results,names{3});getSorts(results,names{4});getSorts(results,names{5})]
%% Plot
lvl.univariate_last = plot_cumret(results.dates, results.ptfret.univariate{:,:}./100, 1, true);


plot_cumret(results.dates, results.ptfret.xs{:,:}./100, 1, true);

results.lvl_size  = plot_cumret(results.dates, results.ptfret_size , 20, true);
results.lvl_illiq = plot_cumret(results.dates, results.ptfret_illiq, 20, true);
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
