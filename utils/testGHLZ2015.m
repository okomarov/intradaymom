function [tstat, coeff, R] = testGHLZ2015(OPT_)
if nargin == 0
    OPT_.PREDICT_SKIP      = false;
    OPT_.RET_USE_OVERNIGHT = true;
    OPT_.USE_UNIVARIATE    = true;
end

stats = loadresults('dailystats','..\hfandlow\results');
stats = addPermno(stats);
stats = stats(stats.Permno == 84398,:);
dates = stats.Date(stats.Nrets > 500);
% Their sample starts in Jun 1997 and not 1993!
% plot(yyyymmdd2datetime(stats.Date), log(stats.Nrets), yyyymmdd2datetime(stats.Date([1,end])),log([500,500]))

spy = loadresults('spy5m','..\hfandlow\results');
spy = spy(ismember(serial2yyyymmdd(spy.Datetime), dates),:);

prices = reshape(spy.Price,79,[]);
prices = flipud(nanfillts(flipud(prices)))';
prices = prices(:,1:6:79);

ret = prices(:, 2:end)./prices(:,1:end-1)-1;

if OPT_.RET_USE_OVERNIGHT
    reton    = loadresults('return_intraday_overnight','..\hfandlow\results');
    reton    = reton(reton.Permno == 84398,:);
    reton    = reton(ismember(reton.Date, dates),:);
    ret(:,1) = (ret(:,1)+1).*(reton.RetCO+1)-1;
end

if ~OPT_.USE_UNIVARIATE
    [tstat, coeff, R] = estimateMultivariate(ret,OPT_);
else
    [tstat, coeff, R] = estimateUnivariate(ret,OPT_);
end
end

function [tstat, coeff, R] = estimateMultivariate(ret,OPT_)
% h13 ~ constant + h12, h11 ... h1
% h12 ~ constant + h11, h10 ... h1
% ...
n                 = size(ret,2);
ncols             = n - OPT_.PREDICT_SKIP;
nrows             = ncols - 1; % no intercept
[tstat, coeff, R] = deal(NaN(nrows, ncols));
for ypos = 2+OPT_.PREDICT_SKIP:n
    xpos       = 1:ypos-1-OPT_.PREDICT_SKIP;
    X          = ret(:,xpos);
    y          = ret(:,ypos);
    tb         = fitlm(X,y,'linear');
    c          = 1:xpos(end)+1;
    r          = nrows-ypos + 2 + OPT_.PREDICT_SKIP;
    R(r,c)     = tb.Rsquared.Ordinary;
    tstat(r,c) = tb.Coefficients.tStat;
    coeff(r,c) = tb.Coefficients.Estimate;
end
end

function [tstat, coeff, R] = estimateUnivariate(ret,OPT_)
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
        X          = ret(:,xpos);
        y          = ret(:,ypos);
        tb         = fitlm(X,y,'linear');
        c          = xpos+1;
        r          = nrows-ypos + 2 + OPT_.PREDICT_SKIP;
        R(r,c)     = tb.Rsquared.Ordinary;
        tstat(r,c) = tb.Coefficients.tStat(2);
        coeff(r,c) = tb.Coefficients.Estimate(2);
    end
end
end
