%% Opts
OPT_NOMICRO    = true;
OPT_DATE_RANGE = [19900101, 20010131];

OPT_RANGES = [930, 1000, 1030, 1100, 1130, 1200, 1230, 1300, 1330, 1400, 1430, 1500,1530]'*100;
OPT_LAG    = 1;

OPT_VOL_STANDARDIZE = true;
OPT_VOL_AVG         = 'e';
OPT_VOL_LAG         = 40;
OPT_VOL_SHIFT       = OPT_VOL_LAG-1+OPT_LAG;
%% Data

% Index data
mst = loadresults('master');

% SUB-PERIOD
if ~isempty(OPT_DATE_RANGE)
    idx = in(mst.Date, OPT_DATE_RANGE, '[]');
    mst = mst(idx,:);
end

% Taq open price
taq                   = loadresults('price_fl');
[idx,pos]             = ismembIdDate(mst.Permno, mst.Date,taq.Permno,taq.Date);
mst.FirstPrice(idx,1) = taq.FirstPrice(pos(idx));
mst.LastPrice(idx,1)  = taq.LastPrice(pos(idx));

if OPT_NOMICRO
    idx = isMicrocap(mst, 'LastPrice',OPT_LAG);
    mst = mst(~idx,:);
end

% Returns
ret = mst(:,{'Permno','Date'});
ret = ret(ret.Permno ~= 84398,:);
for ii = 1:numel(OPT_RANGES)
    tmp         = loadresults(sprintf('halfHourRet%d',OPT_RANGES(ii)));
    [~,pos]     = ismembIdDate(ret.Permno, ret.Date, tmp.Permno, tmp.Date);
    tname       = sprintf('T%d',OPT_RANGES(ii));
    ret.(tname) = double(tmp.(tname)(pos));
end
ret = sortrows(ret,{'Permno','Date'});

% Variance
vol = mst(:,{'Permno','Date'});
vol = vol(vol.Permno ~= 84398,:);
for ii = 1:numel(OPT_RANGES)
    tmp         = loadresults(sprintf('halfHourVol%d',OPT_RANGES(ii)));
    [~,pos]     = ismembIdDate(vol.Permno, vol.Date, tmp.Permno, tmp.Date);
    tname       = sprintf('RV5_%d',OPT_RANGES(ii));
    vol.(tname) = double(tmp.(tname)(pos));
end
vol = sortrows(vol,{'Permno','Date'});
clear tmp
% isequal(vol.Permno, ret.Permno)
% isequal(vol.Date, ret.Date)

% Extract
permnos = ret.Permno;
dates   = ret.Date;
ret     = ret{:,3:end};
vol     = vol{:,3:end};

% Group observations by dates, for clustered standard errors
[~,~,g] = unique(dates);

clear tname taq
%% Sigma

% 40-day moving average lagged 1 standard deviation
sigma = sqrt(tsmovavg(vol,OPT_VOL_AVG, OPT_VOL_LAG,1));
sigma = [NaN(OPT_LAG,size(sigma,2)); sigma(1:end-OPT_LAG,:)]; % ex-ante

% Do not use lags from other permnos
idx           = [false(OPT_VOL_SHIFT,1); permnos(1+OPT_VOL_SHIFT:end) == permnos(1:end-OPT_VOL_SHIFT)];
sigma(~idx,:) = NaN;
clear idx pos

%% NaN out
inan        = any(isnan(ret),2) | any(isnan(sigma),2);
ret(inan,:) = NaN;
%% Multivariate
% Regress
% h13 ~ constant + h11, h10 ... h1
% h12 ~ constant + h10, h19 ... h1
% ...
n              = numel(OPT_RANGES);
[tstat, coeff] = deal(NaN(n-1,n-2));
for ypos = n:-1:3
    % Standardizing returns by vol
    xpos = 1:ypos-2;
    if OPT_VOL_STANDARDIZE
        X = ret(:,xpos)./sigma(:,xpos);
        y = ret(:,ypos)./sigma(:,ypos);
    else
        X = ret(:,xpos);
        y = ret(:,ypos);
    end
    tb         = clusterreg(y,X,g,'linear');
    r          = 1:xpos(end)+1;
    c          = ypos-2;
    tstat(r,c) = tb.tStat;
    coeff(r,c) = tb.Estimate;
end
results.tstat = tstat;
results.coeff = coeff;
clear tstat coeff X y ypos xpos tb r c

%% Univariate
% Regress
% h13 ~ constant + h11
% h13 ~ constant + h10
% ...
% h12 ~ constant + h10
% h12 ~ constant + h9
% ...
n              = numel(OPT_RANGES);
[tstat, coeff] = deal(NaN(n-1,n-2));
for ypos = n:-1:3
    for xpos = ypos-2:-1:1
        % Standardizing returns by vol
        if OPT_VOL_STANDARDIZE
            X = ret(:,xpos)./sigma(:,xpos);
            y = ret(:,ypos)./sigma(:,ypos);
        else
            X = ret(:,xpos);
            y = ret(:,ypos);
        end
        tb         = clusterreg(y,X,g,'linear');
        r          = xpos+1;
        c          = ypos-2;
        tstat(r,c) = tb.tStat(2);
        coeff(r,c) = tb.Estimate(2);
    end
end
results.tstat = tstat;
results.coeff = coeff;

clear tstat coeff X y ypos xpos tb r c