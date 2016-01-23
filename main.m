%% Options
OPT_LAGDAY  = 1;
OPT_NOMICRO = true;

OPT_HASWEIGHTS = true;
OPT_INDEP_SORT = false;

OPT_PTFNUM        = 10;
OPT_PTFNUM_DOUBLE = [5,5];

% Choose one from the dictionary
OPT_PRICE_TYPE = 1;
OPT_TYPE_DICT  = {1, 'taq_exact' 
                  2, 'taq_vwap' 
                  3, 'taq_exact/vwap'};
OPT_PRICE_TYPE = OPT_TYPE_DICT{ismember([OPT_TYPE_DICT{:,1}], OPT_PRICE_TYPE),2};
%% Data
datapath = '..\data\TAQ\sampled\5min\nobad';

% Index data
master = loadresults('master');

% First and last price
price_fl = loadresults('price_fl');

% VWAP
vwap = loadresults('vwap');

% Permnos
permnos = unique(master.mst.Permno);
nseries = numel(permnos);

% Capitalizations
cap = loadresults('cap');

% NYSE breakpoints
if OPT_NOMICRO
    bpoints = loadresults('ME_breakpoints_TXT');
end
%% Lag 1 period
% w = [NaN(1,nseries); cap.Data(1+OPT_LAGDAY:end,:)];

% Lag
if OPT_NOMICRO
    bpoints.Var3 = [NaN(OPT_LAGDAY,1); bpoints.Var3(1:end-OPT_LAGDAY)];
end
%% Cache by dates

% master
master.mst     = sortrows(master.mst,'Date','ascend');
[dates,~,subs] = unique(master.mst.Date);
N              = numel(dates);
nrows          = accumarray(subs,1);
mst            = mat2cell(master.mst,nrows,6);

% price first last
price_fl   = sortrows(price_fl,'Date','ascend');
[~,~,subs] = unique(price_fl.Date);
nrows      = accumarray(subs,1);
price_fl   = mat2cell(price_fl,nrows,size(price_fl,2));

vwap           = sortrows(vwap,'Date','ascend');
[dates,~,subs] = unique(vwap.Date);
nrows          = accumarray(subs,1);
vwap           = mat2cell(vwap,nrows,size(vwap,2));

% cap
w = num2cell(w,2);
%%

ptf    = NaN(N,OPT_PTFNUM);
ptf2   = NaN(N,prod(OPT_PTFNUM_DOUBLE));
bin1   = NaN(N, nseries);
bin2   = NaN(N, nseries);
signal = NaN(N, nseries);

% 12:00, 12:30 and 13:00
END_TIME_SIGNAL = 120000;
START_TIME_HPR  = 121000;

poolStartup(8,'AttachedFiles',{'poolStartup.m'})
tic
parfor ii = 2:N
    disp(ii)
    
    % TAQ_EXACT
    s = struct('datapath',datapath, 'mst', mst{ii},'price_fl',price_fl{ii},...
        'END_TIME_SIGNAL', END_TIME_SIGNAL, 'START_TIME_HPR',START_TIME_HPR)
    
    % TAQ_VWAP 
    s = struct('vwap',vwap{ii})
    
    [st_signal, en_signal, st_hpr, end_hpr] = getPrices(OPT_PRICE_TYPE, permnos, s);

    % Signal: Filled back half-day ret
    signal(ii,:) = en_signal./st_signal-1;

    % hpr with 5 min skip
    hpr = end_hpr./st_hpr-1;
    
    % Filter microcaps
    if OPT_NOMICRO
        nyseCap = bpoints.Var3(ismember(bpoints.Date, price_fl{ii}.Date/100));
        if isnan(nyseCap), nyseCap = inf; end
        idx      = st_signal < 5 | w{ii} < nyseCap;
        hpr(idx) = NaN;
    end
    
    if OPT_HASWEIGHTS
        weight = w{ii};
    else
        weight = [];
    end
    
    % PTF ret
    [ptf(ii,:), bin1(ii,:)] = portfolio_sort(hpr,signal(ii,:), 'PortfolioNumber',OPT_PTFNUM, 'Weights',weight);
    
%     % PTF ret
%     [ptf2(ii,:), bin2(ii,:)] = portfolio_sort(hpr,{w{ii},signal(ii,:)}, 'PortfolioNumber',OPT_PTFNUM_DOUBLE,...
%         'Weights',weight,'IndependentSort',OPT_INDEP_SORT);
end
toc

t = stratstats(dates, [ptf, ptf(:,1)-ptf(:,end)] ,'d',0);

col          = nan2zero(bin1)+1;
row          = repmat((1:N)',1,nseries);
subs         = [row(:),col(:)];
sigMin       = accumarray(subs, signal(:), [],@nanmin);
sigMax       = accumarray(subs, signal(:), [],@nanmax);
t.Signal_Min = [nanmean(sigMin(2:end,2:end))'; NaN];
t.Signal_Max = [nanmean(sigMax(2:end,2:end))'; NaN];
t{:,:}'

t2 = stratstats(dates, ptf2 ,'d',0);
t2{:,:}'
reshape(t2.Annret, OPT_PTFNUM_DOUBLE)'
% t.Properties.VariableNames'

OPT_HASWEIGHTS
