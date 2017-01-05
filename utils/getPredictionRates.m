function tb = getPredictionRates(spec_sig, spec_hpr, dates)
signal = getIntradayRet(spec_sig);
hpr    = getIntradayRet(spec_hpr);

Total     = sum(~isnan(signal),2);
sign_sig  = sign(signal);
sign_hpr  = sign(hpr);
Correct   = sum((sign_sig == 1 & sign_hpr == 1) | (sign_sig == -1 & sign_hpr == -1),2);
Null      = sum(sign_sig == 0,2);
Long_sig  = sum(sign_sig == 1,2);
Long_hpr  = sum(sign_hpr == 1,2);


if nargout == 0
    plot(yyyymmdd2datetime(dates), movmean([Correct, Long_sig, Long_hpr]./(Total-Null),[252,0])*100)
    title '252-day moving averages'
    legend 'correctly predicted' 'long positions' 'long hpr'
    ytickformat('percentage')
else
    tb = table(Correct, Null, Total, Long_sig, Long_hpr);
end
end
