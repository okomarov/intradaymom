%% Options
OPT_.NO_MICRO          = true;
OPT_.DAY_LAG           = 1;
OPT_.RET_USE_OVERNIGHT = false;
OPT_.DATAPATH          = '..\data\TAQ\sampled\5min\nobad_vw';

OPT_.NUM_PTF_UNI = 10;

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
    permnos = unique(mst.Permno);
    nseries = numel(permnos);
    dates   = unique(mst.Date);

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
    idx            = ismember(amihud.permnos, permnos);
    amihud.illiq   = amihud.illiq(:,idx);
    amihud.permnos = amihud.permnos(idx);
    amihud.illiq   = [NaN(OPT_.DAY_LAG, size(amihud.illiq,2));
                      amihud.illiq(1:end-OPT_.DAY_LAG,:)];
    [~,pos]        = ismember(dates/100, amihud.dates);
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

    % Industry
    mst      = getFFIndustryCodes(mst,12);
    industry = lagpanel(mst(:,{'Permno','Date','FFid'}),'Permno', OPT_.DAY_LAG);
    industry = myunstack(industry,'FFid');
    industry = industry{:,2:end};

    % Reorganize into one data structure
    data.mst      = mst;
    data.price_fl = price_fl;
    data.cap      = cap;
    data.reton    = reton;
    data.tick     = tick;
    data.vol      = vol;
    data.volume = volume;
    data.industry = industry;
    data.amihud = amihud;

    save data_snapshot.mat data dates permnos OPT_ -v7.3
end
%% Correlations characteristics
names   = {'size','illiq','tick','vol','volume'};
corrmat = corrxs(cat(3, data.cap, data.amihud, data.tick, data.vol, data.volume), names);

%% TSMOM
ptfret_ts = {}; stats_ts = {};
[ptfret_ts{end+1}, stats_ts{end+1}] = estimateTSmom(specs.NINE_TO_NOON, specs.LAST_E,       data,dates,OPT_,false);
[ptfret_ts{end+1}, stats_ts{end+1}] = estimateTSmom(specs.NINE_TO_NOON, specs.LAST_V,       data,dates,OPT_,false);
% % These are similar to NINE_TO_NOON
% [ptfret_ts{end+1}, stats_ts{end+1}] = estimateTSmom(specs.TEN_TO_ONE  , specs.LAST_E,       data,dates,OPT_,true);
% [ptfret_ts{end+1}, stats_ts{end+1}] = estimateTSmom(specs.FIRST       , specs.LAST_E,       data,dates,OPT_,true);

[ptfret_ts{end+1}, stats_ts{end+1}] = estimateTSmom(specs.NINE_TO_ONE , specs.AFTERNOON_E, 	data,dates,OPT_,false);
[ptfret_ts{end+1}, stats_ts{end+1}] = estimateTSmom(specs.NINE_TO_ONE , specs.AFTERNOON_V,  data,dates,OPT_,false);

% % Similar to NINE_TO_ONE predicting AFTERNOON
% [ptfret_ts{end+1}, stats_ts{end+1}] = estimateTSmom(specs.NINE_TO_ONE , specs.SLAST_E,      data,dates,OPT_,true);
% [ptfret_ts{end+1}, stats_ts{end+1}] = estimateTSmom(specs.TEN_TO_ONE  , specs.SLAST_E,      data,dates,OPT_,true);

% corrmat = tril(corr(cell2mat(cellfun(@(x) x.ew_fun, ptfret_ts,'un',0)),'rows','pairwise'),-1);
% corrmat(corrmat == 0) = NaN;
%% XS
ptfret_xs = {}; stats_xs = {};
[ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.NINE_TO_NOON, specs.LAST_E,       data,dates,OPT_,false);
[ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.NINE_TO_NOON, specs.LAST_V,       data,dates,OPT_,false);
% % These are similar to NINE_TO_NOON
% [ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.TEN_TO_ONE  , specs.LAST_E,       data,dates,OPT_,true);
% [ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.FIRST       , specs.LAST_E,       data,dates,OPT_,true);

[ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.NINE_TO_ONE , specs.AFTERNOON_E, 	data,dates,OPT_,true);
[ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.NINE_TO_ONE , specs.AFTERNOON_V,  data,dates,OPT_,false);

% % Similar to NINE_TO_ONE predicting AFTERNOON
% [ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.NINE_TO_ONE , specs.SLAST_E,      data,dates,OPT_,true);
% [ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.TEN_TO_ONE  , specs.SLAST_E,      data,dates,OPT_,true);

% corrmat = tril(corr(cell2mat(cellfun(@(x) x{:,end}, ptfret_xs,'un',0)),'rows','pairwise'),-1);
% corrmat(corrmat == 0) = NaN;
%% Double sorts
tb = estimateSorts(specs.NINE_TO_NOON, specs.LAST_E     , data, dates);
tb = estimateSorts(specs.NINE_TO_ONE , specs.AFTERNOON_E, data, dates);


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
