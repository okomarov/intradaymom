function out = estimateSorts(spec_sig, spec_hpr, data, dates, OPT_)
signal = getIntradayRet(spec_sig);
hpr    = getIntradayRet(spec_hpr)*100;

idx = in(dates,OPT_.DATE_RANGE);

out = table();
fun = @(ret,count,sig,N) [reshape(nanmean(ret),N)*252, round(reshape(nanmean(count),N)), reshape(nanmean(sig),N(1),[],1)];
% 
N = [3,5];
% [ptfret, ~, count, avg_sig] = portfolio_sort(hpr(idx,:), {data.cap(idx,:), signal(idx,:)},'PortfolioNumber',N);
% out = formatOut(out,'Size',fun, ptfret, count,avg_sig,N);
% 
% [ptfret, ~, count, avg_sig] = portfolio_sort(hpr(idx,:), {data.vol(idx,:), signal(idx,:)},'PortfolioNumber',N);
% out = formatOut(out,'Volatility',fun, ptfret, count,avg_sig,N);
% 
% [ptfret, ~, count, avg_sig] = portfolio_sort(hpr(idx,:), {data.volume(idx,:), signal(idx,:)},'PortfolioNumber',N);
% out = formatOut(out,'Volume',fun, ptfret, count, avg_sig, N);
% 
% [ptfret, ~, count, avg_sig] = portfolio_sort(hpr(idx,:), {data.skew(idx,:), signal(idx,:)},'PortfolioNumber',N);
% out = formatOut(out,'Skewness',fun, ptfret, count,avg_sig,N);
% 
[ptfret, ~, count, avg_sig] = portfolio_sort(hpr(idx,:), {data.tick(idx,:), signal(idx,:)},'PortfolioNumber',N);
out = formatOut(out,'Tick',fun, ptfret, count,avg_sig,N);
% 
% [ptfret, ~, count, avg_sig] = portfolio_sort(hpr(idx,:), {data.amihud(idx,:), signal(idx,:)},'PortfolioNumber',N);
% out = formatOut(out,'Illiquidity',fun, ptfret, count,avg_sig,N);
% 
% N = [2,5];
% [ptfret, ~, count, avg_sig] = portfolio_sort(hpr(idx,:), {data.issp(idx,:)+1, signal(idx,:)},'PortfolioNumber',N, 'PortfolioEdges',{1:3,[]});
% out = formatOut(out,'Size',fun, ptfret, count,avg_sig,N);
% 
% N = [12,5];
% [ptfret, ~, count,avg_sig] = portfolio_sort(hpr(idx,:), {double(data.industry(idx,:)), signal(idx,:)},'PortfolioNumber',N,'PortfolioEdges',{0:12,[]});
% out = formatOut(out,'Industry',fun, ptfret, count, avg_sig, N);
% 
% % Weekdays
% N = 5;
% for ii = 1:N
%     iday = weekday(yyyymmdd2datetime(dates))-1 == ii;
%     [tret{ii,1}, ~, tcount{ii,1}, tsig{ii,1}] = portfolio_sort(hpr(iday & idx,:), signal(iday & idx,:),'PortfolioNumber',N);
% end
% f   = @(in) cell2mat(cellfun(@(x) nanmean(x),in,'un',0));
% fun = @(ret,count,sig,~) [f(ret)*252, round(f(count)), f(sig)];
% out = formatOut(out, 'Weekday',fun,  tret, tcount, tsig, [N,N]);
end

function out = formatOut(out, label, fun, ret,count,sig,N)
out{label,'Res'}    = {fun(ret, count, sig, N)};
out{label,'SparkR'} = {getSparkline(out.Res{label}(:,1:N(2)),[-0.1,0.9])};
out{label,'SparkC'} = {getSparkline(out.Res{label}(:,N(2)+1:N(2)*2),[-0.1,0.9])};
end