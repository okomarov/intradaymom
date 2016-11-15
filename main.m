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

START_SIGNAL = 930;
END_SIGNAL   = 1200;
START_HPR    = 1230;
END_HPR      = 1530;

OPT_VOL_AVG = 'e';
OPT_LAG_VOL = 40;
OPT_TARGET_VOL = 0.4;
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
vol.Sigma      = sqrt(tsmovavg(vol.RV5,OPT_VOL_AVG, OPT_LAG_VOL,1));
SHIFT          = OPT_LAG_VOL-1+OPT_LAGDAY;
vol(:,[1,2,4]) = lagpanel(vol(:,[1,2,4]),'Permno',SHIFT);
vol            = myunstack(vol,'Sigma');

% Permnos
permnos = unique(mst.Permno);
nseries = numel(permnos);

switch OPT_PRICE_TYPE
    case 'taq_vwap'
        p{1} = loadresults(sprintf('VWAP_30_%d', START_SIGNAL*100),'..\results\vwap');
        p{2} = loadresults(sprintf('VWAP_30_%d', END_SIGNAL*100),'..\results\vwap');
        p{3} = loadresults(sprintf('VWAP_30_%d', START_HPR*100),'..\results\vwap');
        p{4} = loadresults(sprintf('VWAP_30_%d', END_HPR*100),'..\results\vwap');
        for ii = 1:4
            [~,pos] = ismembIdDate(mst.Permno, mst.Date, p{ii}.Permno, p{ii}.Date);
            p{ii}   = p{ii}(pos,:);
        end
end

%% Cache by dates
[dates,~,g] = unique(mst.Date);
mst         = cache2cell(mst,g);
price_fl    = cache2cell(price_fl,g);

SIGNAL_ST = cache2cell(p{1},g);
SIGNAL_EN = cache2cell(p{2},g);
HPR_ST    = cache2cell(p{3},g);
HPR_EN    = cache2cell(p{4},g);
clear p
%%
N      = numel(dates);
% ptf    = NaN(N,OPT_PTFNUM);
% ptf2   = NaN(N,prod(OPT_PTFNUM_DOUBLE));
% bin1   = NaN(N, nseries);
% bin2   = NaN(N, nseries);
signal = NaN(N, nseries);
hpr    = NaN(N, nseries);

for ii = 2:N
    disp(ii)
    switch OPT_PRICE_TYPE
        case 'taq_exact'
            s = struct('datapath',datapath, 'mst', mst{ii},'price_fl',price_fl{ii},...
                       'START_SIGNAL', START_SIGNAL,'END_SIGNAL', END_SIGNAL,...
                       'START_HPR', START_HPR,'END_HPR',END_HPR);

        case 'taq_vwap'
            s = struct('START_SIGNAL', SIGNAL_ST{ii},'END_SIGNAL', SIGNAL_EN{ii},...
                       'START_HPR', HPR_ST{ii},'END_HPR',HPR_EN{ii});
        case 'taq_exact/vwap'
    end

    [signal_st, signal_en, hpr_st, hpr_en] = getPrices(OPT_PRICE_TYPE, permnos, s);


    % Signal: Filled back half-day ret
    signal(ii,:) = signal_en./signal_st-1;

    % hpr with 5 min skip
    hpr(ii,:) = hpr_en./hpr_st-1;

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

% Equal weighted
isign    = @(val) sign(signal) == val;
getw     = @(val) isign(val) ./ nansum(isign(val), 2);
w        = getw(1) + getw(-1);
ptfret_e = nansum(sign(signal) .* hpr .* w,2);

% Equal weighted
v        = vol{:,2:end}*sqrt(252);
ptfret_v = nansum(sign(signal) .* hpr .* w .* (OPT_TARGET_VOL./v),2);

% Value weighted
w        = double(cap{:,2:end});
getw     = @(val) w .* isign(val) ./ nansum(w .* isign(val), 2);
w        = getw(1) + getw(-1);
ptfret_w = nansum(sign(signal) .* hpr .* w,2);

allret = [ptfret_e, ptfret_w, ptfret_v, nanmean(hpr,2), nansum(hpr.*w,2)];
t      = stratstats(dates, allret,'d',0)';

%% Plot

% Cumulated returns
lvl = [ones(1,size(allret,2)); cumprod(1+allret(OPT_LAG_VOL:end,:))];
plot(yyyymmdd2datetime(dates(OPT_LAG_VOL-1:end)), log(lvl))
title 'Cumulated returns'
ylabel log
legend EW VW VOLW 'EW longonly' 'VW longonly'

% Correctly predicted and long positions
total   = sum(~isnan(signal),2);
correct = sum(sign(signal) == sign(hpr),2);
long    = sum(signal > 0,2);

% subplot(211)
plot(yyyymmdd2datetime(dates), movmean([correct,long]./total,[252,0])*100)
title '252-day moving averages'
legend 'correctly predicted' 'long positions'
ytickformat('percentage')

% dsf = loadresults('dsfquery','..\results');
% mkt = dsf(dsf.Permno == 84398,:);
% idt = ismember(mkt.Date, dates);
%
% subplot(212)
% plot(yyyymmdd2datetime(mkt.Date(idt)), mkt.Prc(idt))

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
