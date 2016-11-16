%% Options
OPT_LAGDAY  = 1;
OPT_NOMICRO = true;

% OPT_HASWEIGHTS = true;
% OPT_INDEP_SORT = false;

% OPT_PTFNUM        = 10;
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

OPT_MINOBS_REGRESSION_LONG = 10;
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
mst         = cache2cell(mst,g);
price_fl    = cache2cell(price_fl,g);

SIGNAL_ST = cache2cell(p{1},g);
SIGNAL_EN = cache2cell(p{2},g);
HPR_ST    = cache2cell(p{3},g);
HPR_EN    = cache2cell(p{4},g);
clear p g
%% TSMOM
results.N = numel(results.dates);
% ptf    = NaN(N,OPT_PTFNUM);
% ptf2   = NaN(N,prod(OPT_PTFNUM_DOUBLE));
% bin1   = NaN(N, nseries);
% bin2   = NaN(N, nseries);
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
    results.hpr(ii,:) = hpr_en./hpr_st-1;

    %     if OPT_HASWEIGHTS
    %         weight = w{ii};
    %     else
    %         weight = [];
    %     end
    %
    %     % PTF ret
    %     [ptf(ii,:), bin1(ii,:)] = portfolio_sort(hpr,signal(ii,:), 'PortfolioNumber',OPT_PTFNUM, 'Weights',weight);
    %
    %     % PTF ret
    %     [ptf2(ii,:), bin2(ii,:)] = portfolio_sort(hpr,{w{ii},signal(ii,:)}, 'PortfolioNumber',OPT_PTFNUM_DOUBLE,...
    %         'Weights',weight,'IndependentSort',OPT_INDEP_SORT);
end
clear signal_en signal_st hpr_en hpr_st s

% Equal weighted
results.ptfret    = table();
isign             = @(val) sign(results.signal) == val;
getew             = @(val) isign(val) ./ nansum(isign(val), 2);
tsmom.ew          = @() sign(results.signal) .* results.hpr .* (getew(1) + getew(-1));
results.ptfret.ew = nansum(tsmom.ew(),2);

% Volatility weighted
v                   = vol{:,2:end}*sqrt(252);
tsmom.volw          = @() sign(results.signal) .* results.hpr .* (getew(1) + getew(-1)) .* (OPT_VOL_TARGET./v);
results.ptfret.volw = nansum(tsmom.volw(),2);

% Value weighted
w                 = double(cap{:,2:end});
getvw             = @(val) w .* isign(val) ./ nansum(w .* isign(val), 2);
tsmom.vw          = @() sign(results.signal) .* results.hpr .* (getvw(1) + getvw(-1));
results.ptfret.vw = nansum(tsmom.vw(),2);

% EW long-only
tsmom.ew_long          = @() results.hpr .* (getew(1) + getew(-1));
results.ptfret.ew_long = nansum(tsmom.ew_long(),2);

% VW long-only
tsmom.vw_long          = @() results.hpr .* (getvw(1) + getvw(-1));
results.ptfret.vw_long = nansum(tsmom.vw_long(),2);

% VOLW long-only
tsmom.volw_long          = @() results.hpr .* (getew(1) + getew(-1)) .* (OPT_VOL_TARGET./v);
results.ptfret.volw_long = nansum(tsmom.volw_long(),2);

results.ptfret_stats = stratstats(results.dates, results.ptfret,'d',0)';
results.Names        = results.ptfret.Properties.VariableNames;
%% Plot

% Cumulated returns
results.lvl = [ones(1,size(results.ptfret{:,:},2)); cumprod(1+results.ptfret{:,:}(OPT_VOL_LAG:end,:))];
plot(yyyymmdd2datetime(results.dates(OPT_VOL_LAG-1:end)), log(results.lvl))
title 'Cumulated returns'
ylabel log
legend(results.Names,'Interpreter','none');

% Correctly predicted and long positions
total   = sum(~isnan(results.signal),2);
correct = sum(sign(results.signal) == sign(results.hpr),2);
long    = sum(results.signal > 0,2);

% subplot(211)
plot(yyyymmdd2datetime(results.dates), movmean([correct,long]./total,[252,0])*100)
title '252-day moving averages'
legend 'correctly predicted' 'long positions'
ytickformat('percentage')

% dsf = loadresults('dsfquery','..\results');
% mkt = dsf(dsf.Permno == 84398,:);
% idt = ismember(mkt.Date, dates);
%
% subplot(212)
% plot(yyyymmdd2datetime(mkt.Date(idt)), mkt.Prc(idt))
%% Regress on long-only
opts = {'intercept',false,'display','off','type','HAC','bandwidth',floor(4*(results.N/100)^(2/9))+1,'weights','BT'};

fields = results.Names;
fields = fields(cellfun(@isempty, regexp(fields,'_long')));
for ii = 1:numel(fields)
    f          = fields{ii};
    l          = ones(results.N, 1);
    X          = num2cell(tsmom.(f)() * 100,1);
    y          = tsmom.([f '_long'])()*100;
    enough_obs = sum(~isnan(y)) > OPT_MINOBS_REGRESSION_LONG;
    y          = num2cell(y,1);

    [se, coeff] = deal(NaN(results.nseries,2));
    parfor c = 1:results.nseries
        if enough_obs(c)
            [~,se(c,:), coeff(c,:)] = hac([l X{c}],y{c}, opts{:});
        end
    end

    tratio = coeff./se;
    pval   = 2 * normcdf(-abs(tratio));

    results.RegressOnLong.(f).Coeff  = coeff;
    results.RegressOnLong.(f).Se     = se;
    results.RegressOnLong.(f).Tratio = tratio;
    results.RegressOnLong.(f).Pval   = pval;
end
clear l X y enough_obs se coeff tratio pval fields
%% RA factors
factors = loadresults('RAfactors');

[~,ia,ib] = intersect(dates, factors.Date);
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
