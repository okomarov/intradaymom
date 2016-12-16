function out = estimateSorts(spec_sig, spec_hpr, data, dates)
signal = getIntradayRet(spec_sig);
hpr    = getIntradayRet(spec_hpr)*100;

out = table();
fun = @(ret,count,sig,N) [reshape(nanmean(ret),N)*252, round(reshape(nanmean(count),N)), reshape(nanmean(sig),N(1),[],1)];

N = [3,5];
% [ptfret, ~, count, avg_sig] = portfolio_sort(hpr, {data.cap, signal},'PortfolioNumber',N);
% out = formatOut(out,'Size',fun, ptfret, count,avg_sig,N);
% 
% [ptfret, ~, count, avg_sig] = portfolio_sort(hpr, {data.vol, signal},'PortfolioNumber',N);
% out = formatOut(out,'Volatility',fun, ptfret, count,avg_sig,N);
% 
% [ptfret, ~, count, avg_sig] = portfolio_sort(hpr, {data.volume, signal},'PortfolioNumber',N);
% out = formatOut(out,'Volume',fun, ptfret, count, avg_sig, N);

[ptfret, ~, count, avg_sig] = portfolio_sort(hpr, {data.skew, signal},'PortfolioNumber',N);
out = formatOut(out,'Skewness',fun, ptfret, count,avg_sig,N);
% 
% N = [12,5];
% [ptfret, ~, count,avg_sig] = portfolio_sort(hpr, {double(data.industry), signal},'PortfolioNumber',N,'PortfolioEdges',{0:12,[]});
% out = formatOut(out,'Industry',fun, ptfret, count, avg_sig, N);
% 
% N = 5;
% for ii = 1:N
%     idx = weekday(yyyymmdd2datetime(dates))-1 == ii;
%     [tret{ii,1}, ~, tcount{ii,1}, tsig{ii,1}] = portfolio_sort(hpr(idx,:), signal(idx,:),'PortfolioNumber',N);
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