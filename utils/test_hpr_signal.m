if ~exist('SIGNAL_ST','var')
    load results\test_signal.mat
end

target.signal = NaN;
target.hpr    = NaN;

while isnan(target.signal) || isnan(target.hpr)
    [target.permno,col] = datasample(permnos,1);
    [target.date,row]   = datasample(dates,1);
    idx                 = ismember(SIGNAL_ST{row}.Permno, target.permno);
    target.signal_st    = SIGNAL_ST{row}.T93000(idx);
    target.signal_en    = SIGNAL_EN{row}.T120000(idx);
    target.hpr_st       = HPR_ST{row}.T123000(idx);
    target.hpr_en       = HPR_EN{row}.T153000(idx);
    target.signal       = signal(row,col);
    target.hpr          = hpr(row,col);
end

prices = getTaqData('permno',target.permno,target.date,target.date);

prices = prices(~isInvalidTrade(prices),:);

MULTIPLIER = 10;
medprice   = median(prices.Price);
ibad       = prices.Price./medprice >= MULTIPLIER |...
             medprice./prices.Price >= MULTIPLIER;
prices     = prices(~ibad,:);

prices = consolidateTimestamp(prices, 'median');

ranges     = [ 930, 1000, 1030, 1100, 1130, 1200, 1230, 1300, 1330, 1400, 1430, 1500, 1530, 1600]'*100;
[~,~,subs] = histcounts(serial2hhmmss(prices.Datetime), ranges);
voltot     = accumarray(subs, double(prices.Volume));
p          = accumarray(subs, double(prices.Price).* double(prices.Volume)) ./ voltot;

verify.permno    = target.permno;
verify.date      = target.date;
verify.signal_st = p(1);
verify.signal_en = p(6);
verify.hpr_st    = p(7);
verify.hpr_en    = p(end);
verify.signal    = verify.signal_en./verify.signal_st-1;
verify.hpr       = verify.hpr_en./verify.hpr_st-1;

target
verify