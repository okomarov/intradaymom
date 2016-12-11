function [tstat,coeff,R,OPT_] = predictability(varargin)
%% Opts
p              = inputParser();
p.StructExpand = nargin == 1 && isstruct(varargin{1});

addOptional(p,'PREDICT_MULTI'       ,true);
addOptional(p,'PREDICT_SKIP'        ,1);
addOptional(p,'NO_MICRO'            ,true);
addOptional(p,'DAY_LAG'             ,1);
addOptional(p,'DATE_RANGE'          ,[]); % e.g. [-inf, 20010431], [20010501, inf];
addOptional(p,'RET_USE_OVERNIGHT'   ,false);
addOptional(p,'VOL_STANDARDIZE'     ,true);
addOptional(p,'VOL_TYPE'            ,'e');
addOptional(p,'VOL_LAG'             ,60);

p.parse(varargin{:});
OPT_ = p.Results;

OPT_.RANGES    = [930, 1000, 1030, 1100, 1130, 1200, 1230, 1300, 1330, 1400, 1430, 1500,1530]'*100;
OPT_.VOL_SHIFT = OPT_.VOL_LAG-1+OPT_.DAY_LAG;
%% Data
mst = loadresults('master');

% Sub-period
idx = in(mst.Date, OPT_.DATE_RANGE, '[]');
mst = mst(idx,:);

if OPT_.NO_MICRO
    taq                  = loadresults('price_fl');
    [idx,pos]            = ismembIdDate(mst.Permno, mst.Date,taq.Permno,taq.Date);
    %     mst.FirstPrice(idx,1) = taq.FirstPrice(pos(idx));
    mst.LastPrice(idx,1) = taq.LastPrice(pos(idx));
    idx                  = isMicrocap(mst, 'LastPrice',OPT_.DAY_LAG);
    mst                  = mst(~idx,:);
    clear taq
end

% Overnight
ret = mst(:,{'Permno','Date'});
ret = ret(ret.Permno ~= 84398,:);
if OPT_.RET_USE_OVERNIGHT
    reton          = loadresults('return_intraday_overnight','..\hfandlow\results');
    [~,pos]        = ismembIdDate(ret.Permno, ret.Date, reton.Permno, reton.Date);
    ret.RetCO(:,1) = reton.RetCO(pos);
    clear reton
end
% Returns
for ii = 1:numel(OPT_.RANGES)
    tmp         = loadresults(sprintf('halfHourRet%d',OPT_.RANGES(ii)));
    [~,pos]     = ismembIdDate(ret.Permno, ret.Date, tmp.Permno, tmp.Date);
    tname       = sprintf('T%d',OPT_.RANGES(ii));
    ret.(tname) = double(tmp.(tname)(pos));
end
ret     = sortrows(ret,{'Permno','Date'});
permnos = ret.Permno;
dates   = ret.Date;
ret     = ret{:,3:end};

% Variance
if OPT_.VOL_STANDARDIZE
    vol = mst(:,{'Permno','Date'});
    vol = vol(vol.Permno ~= 84398,:);
    if OPT_.RET_USE_OVERNIGHT
        vol.RVCO = ret(:,1).^2;
    end
    for ii = 1:numel(OPT_.RANGES)
        tmp         = loadresults(sprintf('halfHourVol%d',OPT_.RANGES(ii)));
        [~,pos]     = ismembIdDate(vol.Permno, vol.Date, tmp.Permno, tmp.Date);
        tname       = sprintf('RV5_%d',OPT_.RANGES(ii));
        vol.(tname) = double(tmp.(tname)(pos));
    end
    vol = sortrows(vol,{'Permno','Date'});
    % isequal(vol.Permno, ret.Permno)
    % isequal(vol.Date, ret.Date)
    vol = vol{:,3:end};

    % Moving average lagged 1 standard deviation
    vol = sqrt(tsmovavg(vol,OPT_.VOL_TYPE, OPT_.VOL_LAG,1));
    vol = [NaN(OPT_.DAY_LAG,size(vol,2)); vol(1:end-OPT_.DAY_LAG,:)]; % ex-ante

    % Do not use lags from other permnos
    idx         = [false(OPT_.VOL_SHIFT,1); permnos(1+OPT_.VOL_SHIFT:end) == permnos(1:end-OPT_.VOL_SHIFT)];
    vol(~idx,:) = NaN;
else
    vol = [];
end
clear idx pos tmp

% Require data on whole day
inan = any(isnan(ret),2);
if OPT_.VOL_STANDARDIZE
    inan = inan | any(isnan(vol),2);
end
ret(inan,:) = NaN;

%% Estimate
[~,~,g] = unique(dates);
if OPT_.PREDICT_MULTI
    [tstat, coeff, R] = estimateMultivariate(ret,vol,g,OPT_);
else
    [tstat, coeff, R] = estimateUnivariate(ret,vol,g,OPT_);
end

str_ranges = arrayfun(@(x) sprintf('h%d',x),OPT_.RANGES/100,'un',0)';
if OPT_.RET_USE_OVERNIGHT
    str_ranges = ['ON',str_ranges];
end
f     = @(x) array2table(x,'VariableNames',['c' str_ranges(1:end-OPT_.PREDICT_SKIP-1)],'RowNames',str_ranges(end:-1:2+OPT_.PREDICT_SKIP));
tstat = f(tstat);
coeff = f(coeff*100);
R     = f(R);
end

function [tstat, coeff, R] = estimateMultivariate(ret,sigma,g,OPT_)
% h13 ~ constant + h12, h11 ... h1
% h12 ~ constant + h11, h10 ... h1
% ...
n                 = size(ret,2);
ncols             = n - OPT_.PREDICT_SKIP;
nrows             = ncols - 1; % no intercept
[tstat, coeff, R] = deal(NaN(nrows, ncols));
for ypos = 2+OPT_.PREDICT_SKIP:n
    xpos = 1:ypos-1-OPT_.PREDICT_SKIP;
    if OPT_.VOL_STANDARDIZE
        X = ret(:,xpos)./sigma(:,xpos);
        y = ret(:,ypos)./sigma(:,ypos);
    else
        X = ret(:,xpos);
        y = ret(:,ypos);
    end
    c             = 1:xpos(end)+1;
    r             = nrows-ypos + 2 + OPT_.PREDICT_SKIP;
    [tb,~,R(r,c)] = clusterreg(y,X,g,'linear');
    tstat(r,c)    = tb.tStat;
    coeff(r,c)    = tb.Estimate;
end
end

function [tstat, coeff, R] = estimateUnivariate(ret,sigma,g,OPT_)
% h13 ~ constant + h12
% h13 ~ constant + h11
% ...
% h12 ~ constant + h11
% h12 ~ constant + h10
% ...
n                 = size(ret,2);
ncols             = n - OPT_.PREDICT_SKIP;
nrows             = ncols - 1; % no intercept
[tstat, coeff, R] = deal(NaN(nrows, ncols));
for ypos = 2+OPT_.PREDICT_SKIP:n
    for xpos = 1:ypos-1-OPT_.PREDICT_SKIP
        if OPT_.VOL_STANDARDIZE
            X = ret(:,xpos)./sigma(:,xpos);
            y = ret(:,ypos)./sigma(:,ypos);
        else
            X = ret(:,xpos);
            y = ret(:,ypos);
        end
        c             = xpos+1;
        r             = nrows-ypos + 2 + OPT_.PREDICT_SKIP;
        [tb,~,R(r,c)] = clusterreg(y,X,g,'linear');
        tstat(r,c)    = tb.tStat(2);
        coeff(r,c)    = tb.Estimate(2);
    end
end
end
