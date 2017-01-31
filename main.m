%% Options
OPT_.NO_MICRO          = true;
OPT_.DAY_LAG           = 1;
OPT_.RET_USE_OVERNIGHT = false;
OPT_.DATAPATH          = '..\data\TAQ\sampled\5min\nobad_vw';

OPT_.NUM_PTF_UNI = 10;

OPT_.DATE_RANGE = [];
% OPT_.DATE_RANGE = [-inf, 20010431];
% OPT_.DATE_RANGE = [20010501, inf];

OPT_.VOL_AVG   = 'e';
OPT_.VOL_LAG   = 60;
OPT_.VOL_SHIFT = OPT_.VOL_LAG - 1 + OPT_.DAY_LAG;

OPT_.REGRESSION_LONG_MINOBS = 10;
OPT_.REGRESSION_LONG_ALPHA  = 0.05;
%% Data
try
    load data_snapshot.mat
catch
    myunstack = @(tb,vname) sortrows(unstack(tb(:,{'Permno','Date',vname}),vname,'Permno'),'Date');

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
    cap = getMktCap(mst,OPT_.DAY_LAG);
    cap = myunstack(cap,'Cap');
    cap = log(double(cap{:,2:end}));

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

    % Moving average of rskew
    skew        = loadresults('rskew');
    idx         = ismembIdDate(skew.Permno, skew.Date, mst.Permno, mst.Date);
    skew        = skew(idx & ~isnan(skew.Skew),:);
    skew.Skew   = tsmovavg(skew.Skew,OPT_.VOL_AVG, OPT_.VOL_LAG,1);
    skew        = lagpanel(skew,'Permno',OPT_.VOL_SHIFT);
    [~,col]     = ismember(unique(skew.Permno),permnos);
    skew        = myunstack(skew,'Skew');
    skew        = skew{:,2:end};
    skew(:,col) = skew;
    
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
    tick       = loadresults('tick');
    idx        = ismembIdDate(tick.Permno, tick.Date, mst.Permno, mst.Date);
    tick       = tick(idx & ~isnan(tick.Ratio),:);
    tick.Ratio = tsmovavg(tick.Ratio,OPT_.VOL_AVG, OPT_.VOL_LAG,1);
    tick       = lagpanel(tick,'Permno',OPT_.VOL_SHIFT);
    tick       = myunstack(tick,'Ratio');
    tick       = tick{:,2:end};

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

    % SP500 members
    issp     = mst(:,{'Permno','Date'});
    issp.Val = issp500member(mst);
    issp     = myunstack(issp,'Val');
    issp     = issp{:,2:end};

    % Reorganize into one data structure
    data.mst      = mst;
    data.price_fl = price_fl;
    data.cap      = cap;
    data.reton    = reton;
    data.tick     = tick;
    data.vol      = vol;
    data.skew     = skew;
    data.volume   = volume;
    data.industry = industry;
    data.amihud   = amihud;
    data.issp     = issp;

    save data_snapshot.mat data dates permnos OPT_ myunstack -v7.3
end
%% Correlations characteristics
names   = {'size','illiq','tick','std','skew','volume'};
corrmat = corrxs(cat(3, data.cap, data.amihud, data.tick, data.vol, data.skew,data.volume), names);
order   = {'size','volume','skew','illiq','tick','std'};
corrmat = corrmat(order,order);

%% TSMOM
ptfret_ts                           = {}; stats_ts = {};
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
ptfret_xs                           = {}; stats_xs = {};
[ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.NINE_TO_NOON, specs.LAST_E,       data,dates,OPT_,true);
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
a = estimateSorts(specs.NINE_TO_NOON, specs.LAST_E     , data, dates, OPT_);
b = estimateSorts(specs.NINE_TO_ONE , specs.AFTERNOON_E, data, dates, OPT_);

% % Tstats
% [arrayfun(@(x)sprintf('[%.1f]',x), a.Tstat{1},'un',0) 
% arrayfun(@(x)sprintf('[%.1f]',x), a.Tstat{2},'un',0) 
% arrayfun(@(x)sprintf('[%.1f]',x), a.Tstat{3},'un',0) 
% arrayfun(@(x)sprintf('[%.1f]',x), b.Tstat{1},'un',0) 
% arrayfun(@(x)sprintf('[%.1f]',x), b.Tstat{2},'un',0) 
% arrayfun(@(x)sprintf('[%.1f]',x), b.Tstat{3},'un',0)]


%% Regress on long-only
results = regressOnLongOnly(results, OPT_.REGRESSION_LONG_MINOBS, OPT_.REGRESSION_LONG_ALPHA);

%% RA factors
factors = loadresults('RAfactors');

[~,ia,ib] = intersect(dates, factors.Date);
ptfret    = ptfret_xs{2}(ia,:);
factors   = factors(ib,:);
n         = size(ptfret,1);
opts      = {'intercept',false,'display','off','type','HAC','bandwidth',floor(4*(n/100)^(2/9))+1,'weights','BT'};
f         = @(x,y)  hac(x, y, opts{:});

[~,se,coeff] = f([ones(n-1999,1), factors{2000:end,[2,9]}*100], ptfret{2000:end,end});
tratio       = coeff./se;
pval         = 2 * normcdf(-abs(tratio));