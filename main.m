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

% Value weighted
w        = double(cap{:,2:end});
getw     = @(val) w .* isign(val) ./ nansum(w .* isign(val), 2);
w        = getw(1) + getw(-1);
ptfret_w = nansum(sign(signal) .* hpr .* w,2);

t = [stratstats(dates, ptfret_e,'d',0);
    stratstats(dates, ptfret_w,'d',0);
    stratstats(dates, nanmean(hpr   ,2),'d',0);
    stratstats(dates, nansum (hpr.*w,2),'d',0);
    ]';

OPT_HASWEIGHTS
