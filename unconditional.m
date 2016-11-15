%% Options
OPT_LAGDAY     = 1;
OPT_HASWEIGHTS = true;
OPT_NOMICRO    = true;

OPT_CHECK_CRSP = true;

OPT_PTFNUM_UN = 5;

OPT_RANGES = [930, 1000, 1030, 1100, 1130, 1200, 1230, 1300, 1330, 1400, 1430, 1500, 1530]'*100; 
%% Intraday-average: data
taq = loadresults('price_fl');

if OPT_NOMICRO
    idx = isMicrocap(taq,'LastPrice',OPT_LAGDAY);
    taq = taq(~idx,:);
end

if OPT_CHECK_CRSP
    crsp      = loadresults('dsfquery');
    crsp.Prc  = abs(crsp.Prc);
    [~,ia,ib] = intersectIdDate(crsp.Permno,crsp.Date, taq.Permno, taq.Date);
    crsp      = crsp(ia,:);
    taq       = taq(ib,:);
    isequal(crsp.Date, taq.Date)
    isequal(crsp.Permno, taq.Permno)
    permnos   = unique(taq.Permno);
end

% Get market caps
cap = getMktCap(taq,OPT_LAGDAY,true);
cap = struct('Permnos', {getVariableNames(cap(:,2:end))}, ...
    'Dates', cap{:,1},...
    'Data', cap{:,2:end});

% % FF49-industries classification
% ff49 = getFF49IndustryCodes(taq,1);
% ff49 = struct('Permnos', {getVariableNames(ff49(:,2:end))}, ...
%     'Dates', ff49{:,1},...
%     'Data', ff49{:,2:end});

% Unstack returns
myunstack = @(tb,vname) sortrows(unstack(tb(:,{'Permno','Date',vname}),vname,'Permno'),'Date');
taq.Ret   = double(taq.LastPrice)./double(taq.FirstPrice)-1;
ret_taq   = myunstack(taq, 'Ret');
ret_taq   = ret_taq{:,2:end};
if OPT_CHECK_CRSP
    crsp.Ret = double(crsp.Prc)./double(crsp.Openprc)-1;
    ret_crsp = myunstack(crsp, 'Ret');
    ret_crsp = ret_crsp{:,2:end};
else
    ret_crsp = NaN(size(ret_taq));
end

%% Intraday-average: return
if OPT_HASWEIGHTS
    w = bsxfun(@rdivide, cap.Data, nansum(cap.Data,2));
else
    w = repmat(1./sum(~isnan(ret_taq),2), 1,size(ret_taq,2));
end
ret_taq_w  = ret_taq.*w;
ret_crsp_w = ret_crsp.*w;

avg = [nansum(ret_crsp_w,2), nansum(ret_taq_w,2)];
disp(nanmean(avg)*252*100)

if OPT_HASWEIGHTS
    save .\results\avg_ts_vw avg
else
    save .\results\avg_ts_ew avg
end
%% Intraday-average: by size
% ptfret_ew = portfolio_sort(ret_taq, cap.Data, struct('PortfolioNumber',OPT_PTFNUM_UN));
ptfret_vw = portfolio_sort(ret_taq, cap.Data, struct('PortfolioNumber',OPT_PTFNUM_UN, 'Weights', cap.Data));
save .\results\avg_ts_size_vw ptfret_vw
%% Intraday-average: by industry
nobs    = numel(ff49.Dates);
nseries = numel(ff49.Permnos);
row     = repmat((1:nobs)', 1, nseries);
subs    = [row(:), double(ff49.Data(:)+1)];

if OPT_HASWEIGHTS
    w = bsxfun(@rdivide, cap.Data, nansum(cap.Data,2));
else
    w = repmat(1./sum(~isnan(ret_taq),2), 1,size(ret_taq,2));
end
ret_taq_w = ret_taq.*w;
% ret_crsp_w = ret_crsp.*w;

ptfret_vw = accumarray(subs, ret_taq_w(:),[],@nansum);
% ptfret_vw = accumarray(subs, ret_crsp_w(:),[],@nansum);

ptfret_vw = ptfret_vw(:,2:end);

[dict,des] = getFF49Classification;
labels     = regexprep(des.FF49_ShortLabel,'[, ]','');

c                   = corr(double(ptfret_vw)); 
c(logical(eye(49))) = NaN;
% schemaball(c .* double(c > .65),labels)

d = pdist(ptfret_vw','correlation');
Z = linkage(d,'average'); 
figure
dendrogram(Z,0,'orientation','left','Labels',labels)

Z = transz(Z);
G = graph(Z(:,1),Z(:,2), Z(:,3),labels);
figure
plot(G,'layout','force')

% A = zeros(size(c));
% pos = sub2ind(size(c),Z(:,1),Z(:,2));
% A(pos) = Z(:,3);
% B = [[{''},labels(:)']; [labels(:), arrayfun(@(x) sprintf('%.4g',x),A,'un',0)]]';
% fid = fopen('test.csv','w');
% fmt = [repmat('%s;',1,numel(labels)), '%s\n'];
% fprintf(fid,fmt, B{:});
% fclose(fid)

save .\results\avg_ts_industry_vw ptfret_vw
%% Half-hour averages: data
% Index data
mst = loadresults('master');

% Taq open price
taq                   = loadresults('price_fl');
[idx,pos]             = ismembIdDate(mst.Permno, mst.Date,taq.Permno,taq.Date);
mst.FirstPrice(idx,1) = taq.FirstPrice(pos(idx));
mst.LastPrice(idx,1)  = taq.LastPrice(pos(idx));

if OPT_NOMICRO
    idx = isMicrocap(mst, 'LastPrice',OPT_LAGDAY);
    mst = mst(~idx,:);
end

if OPT_HASWEIGHTS
    mst = getMktCap(mst,OPT_LAGDAY,false);
end

% Permnos
permnos = unique(mst.Permno);
nseries = numel(permnos);

% Dates
dates = unique(mst.Date);

%% Half-hour averages
avg      = table();
avg.Date = dates;

% Returns
for ii = 1:numel(OPT_RANGES)
    tmp       = loadresults(sprintf('halfHourRet%d',OPT_RANGES(ii)));
    idx       = ismembIdDate(tmp.Permno, tmp.Date, mst.Permno, mst.Date);
    tmp       = tmp(idx,:);
    tname     = sprintf('T%d',OPT_RANGES(ii));
    tmp       = tmp(~isnan(tmp.(tname)),:);
    [idx,pos] = ismember(tmp.Date, avg.Date);
    if OPT_HASWEIGHTS
        tmp         = getMktCap(tmp,OPT_LAGDAY);
        avg.(tname) = double(accumarray(pos(idx), tmp.(tname)(idx).* tmp.Cap(idx))) ./ ...
                      double(accumarray(pos(idx), tmp.Cap(idx)));
    else
        avg.(tname) = double(accumarray(pos(idx), tmp.(tname)(idx), [],@mean));
    end
end

if OPT_HASWEIGHTS
    save .\results\avg_ts_30min_vw avg
else
    save .\results\avg_ts_30min_ew avg
end
%% Half-hour averages: plot
avg_vw     = loadresults('avg_ts_30min_vw');
avg_ew     = loadresults('avg_ts_30min_ew');
avg_ew     = avg_ew{:,2:end};
avg_vw     = avg_vw{:,2:end};
avg_vw_all = loadresults('avg_ts_vw');
avg_ew_all = loadresults('avg_ts_ew');

% Averages
figure
f = 252*100;

% ha      = subplot(211);
% [~, se] = nwse(avg_ew*f);
% 
% errorbar(nanmean(avg_ew)*f, nwse(avg_ew)*sqrt(252))
% (nanmean(avg_ew)*f)

subplot(211)
bar(nanmean(avg_ew)*f)
hold on
bar(14, mean(avg_ew_all(:,2))*f,'r')
title('Average annualized % returns - EW')
set(gca,'XtickLabel',OPT_RANGES/100)

subplot(212)
bar(nanmean(avg_vw)*f)
hold on
bar(14, mean(avg_vw_all(:,2))*f,'r')
title('Average annualized % returns - VW')
set(gca,'XtickLabel',OPT_RANGES/100)
legend('half-hour','open-to-close','Location','NorthWest')

% Cumulated returns
figure
dts = yyyymmdd2datetime(dates);
subplot(221)
hl  = plot(dts,cumprod(nan2zero(avg_ew)+1));
title('Cumulative returns - EW')

subplot(222)
sel = [1,2,size(avg_ew,2)];
hl2 = plot(dts,cumprod(nan2zero(avg_ew(:,sel))+1));
set(hl2,{'Color'}, get(hl(sel),'Color'))

subplot(223)
hl = plot(dts, cumprod(nan2zero(avg_vw)+1));
title('Cumulative returns - VW')

subplot(224)
hl2 = plot(dts, cumprod(nan2zero(avg_vw(:,sel))+1));
set(hl2,{'Color'}, get(hl(sel),'Color'))

legend(num2str(OPT_RANGES(sel)),'Location','East')