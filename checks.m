%% average and std
OPT_RANGES   = [930, 1000, 1030, 1100, 1130, 1200, 1230, 1300, 1330, 1400, 1430, 1500, 1530]'*100;
OPT_NO_MICRO = true;
OPT_LAGDAY   = 1;
NSERIES      = 8924;
NDATES       = 4338;

price_fl = loadresults('price_fl');
if OPT_NO_MICRO
    idx      = isMicrocap(price_fl, 'LastPrice',OPT_LAGDAY);
    price_fl = price_fl(~idx,:);
end

nranges         = numel(OPT_RANGES);
[avg_ts,dev_ts] = deal(NaN(NSERIES,nranges));
[avg_xs,dev_xs] = deal(NaN(NDATES,nranges));
for ii = 1:nranges
    tmp   = loadresults(sprintf('halfHourRet%d',OPT_RANGES(ii)));
    idx   = ismembIdDate(tmp.Permno, tmp.Date, price_fl.Permno, price_fl.Date);
    tmp   = tmp(idx,:);
    tname = sprintf('T%d',OPT_RANGES(ii));
    tmp   = tmp(~isnan(tmp.(tname)),:);

    % Group by permno
    [unp,~,g]                        = unique(tmp.Permno);
    n                                = numel(unp);
    %     count(1:n,ii)              = accumarray(g,1);
    [avg_ts(1:n,ii), dev_ts(1:n,ii)] = grpstats(tmp.(tname),g,{'mean','std'});

    % Group by date
    [und,~,g]                    = unique(tmp.Date);
    [avg_xs(:,ii), dev_xs(:,ii)] = grpstats(tmp.(tname),g,{'mean','std'});
end
% avg(count < 10) = NaN;
% dev(count < 10) = NaN;

labels = arrayfun(@(h,m) sprintf('%d:%02d\n', h,m), fix(OPT_RANGES/10000), fix(mod(OPT_RANGES/100,100)),'un',0);

% Plot overall averages
figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.4],'PaperPositionMode','auto')
favg = @(p) prctile(avg_ts,p,1)*252*100;
errorbar(1:nranges,favg(50),favg(25)-favg(50),favg(75)-favg(50),'x','MarkerEdgeCOlor','r','LineWidth',0.75);
set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YTick',-50:25:50,'Ylim',[-50,50],'XTick',1:nranges, 'XTickLabel',labels(1:2:end,:))
print('avgret','-depsc','-r200','-loose')

figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.4],'PaperPositionMode','auto')
fdev = @(p) prctile(dev_ts,p,1)*sqrt(252)*100;
errorbar(1:nranges,fdev(50),fdev(25)-fdev(50),fdev(75)-fdev(50),'x','MarkerEdgeCOlor','r','LineWidth',0.75);
set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'Ylim',[0,40],'XTick',1:nranges, 'XTickLabel',labels(1:2:end,:))
print('avgdev','-depsc','-r200','-loose')

% Plot time-evolution
figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.72],'PaperPositionMode','auto')
dt             = yyyymmdd2datetime(und);
[unyear,pos,g] = unique(year(dt),'last');
yret           = splitapply(@(x) prod(1+x)-1, avg_xs, g);
h = ribbon(yret);
set(h, {'CData'}, get(h,'ZData'), 'FaceColor','interp','MeshStyle','column')
set(gca,'TickLabelInterpreter','latex','Layer','Top',...
    'Box','on','XGrid','off','YGrid','off','ZGrid','off',...
    'XTick',1:nranges, 'XTickLabel',labels(1:2:nranges),...
    'YDir','reverse','Ylim',[1,numel(unyear)],'YTick',2:4:numel(unyear),'YTickLabel',unyear(2:4:end),...
    'Zlim',[-0.3,0.3])
view(-35,25)
%% Stategy plots
load data_snapshot.mat

% Signal and HPR #4: last half hour vwap
clear specs
specs(1) = struct('hhmm', 930,'type','exact','duration',0);
specs(2) = struct('hhmm',1200,'type','exact','duration',0);
specs(3) = struct('hhmm',1525,'type','vwap' ,'duration',5);
specs(4) = struct('hhmm',1555,'type','vwap' ,'duration',5);
rets     = makeTsmom(getIntradayRet(specs(1),specs(2)), getIntradayRet(specs(3),specs(4)), [],[],[],1);

figure
% Strategy
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.40],'PaperPositionMode','auto')
[lvl,dt] = plot_cumret(results.dates,rets,1,1);
legend off, title ''
% Recession patches
YLIM = [1,10];
XLIM = xlim();
recessions = [730925,731170; 733391,733939];
X          = recessions-datenum(XLIM(1));
h          = patch(X(:,[1,1,2,2])', repmat([YLIM fliplr(YLIM)]',1,2),[0.9,0.9,0.9],'EdgeColor','none');
uistack(h,'bottom')
% Markers
hold on
mrkStep = 15;
set(gca,'ColorOrderIndex',1)
plot(dt(1:mrkStep:end),lvl(1:mrkStep:end,1),'x',...
     dt(1:mrkStep:end),lvl(1:mrkStep:end,2),'o',...
     dt(1:mrkStep:end),lvl(1:mrkStep:end,3),'^')

set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YScale','log','YLim',YLIM,'YTick',[1,5,10])
print('tsmom_last30','-depsc','-r200','-loose')


% Signal and HPR #5: 13:30 to 15:30 vwap
clear specs
specs(1) = struct('hhmm', 930,'type','exact','duration',0);
specs(2) = struct('hhmm',1300,'type','exact','duration',0);
specs(3) = struct('hhmm',1330,'type','vwap' ,'duration',5);
specs(4) = struct('hhmm',1525,'type','vwap' ,'duration',5);
rets     = makeTsmom(getIntradayRet(specs(1),specs(2)), getIntradayRet(specs(3),specs(4)), [],[],[],1);

figure
% Strategy
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.40],'PaperPositionMode','auto')
[lvl,dt] = plot_cumret(results.dates,rets,1,1);
legend off, title ''
% Recession patches
YLIM = [0.35,15];
XLIM = xlim();
recessions = [730925,731170; 733391,733939];
X          = recessions-datenum(XLIM(1));
h          = patch(X(:,[1,1,2,2])', repmat([YLIM fliplr(YLIM)]',1,2),[0.9,0.9,0.9],'EdgeColor','none');
uistack(h,'bottom')
% Markers
hold on
mrkStep = 15;
set(gca,'ColorOrderIndex',1)
plot(dt(1:mrkStep:end),lvl(1:mrkStep:end,1),'x',...
     dt(1:mrkStep:end),lvl(1:mrkStep:end,2),'o',...
     dt(1:mrkStep:end),lvl(1:mrkStep:end,3),'^')

set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YScale','log','YLim',YLIM,'YTick',[0.35,1,5,10])
print('tsmom_afternoon','-depsc','-r200','-loose')
%% Signal and HPR
% Signal and HPR #1: last half hour
specs(1) = struct('hhmm', 930,'type','exact');
specs(2) = struct('hhmm',1200,'type','exact');
specs(3) = struct('hhmm',1530,'type','exact');
specs(4) = struct('hhmm',1600,'type','exact');
% Signal and HPR #2: 13:30 to 15:30
specs(1) = struct('hhmm', 930,'type','exact');
specs(2) = struct('hhmm',1300,'type','exact');
specs(3) = struct('hhmm',1330,'type','exact');
specs(4) = struct('hhmm',1530,'type','exact');
% Signal and HPR #3: 13:30 to 15:30
specs(1) = struct('hhmm', 930,'type','vwap','duration',30);
specs(2) = struct('hhmm',1200,'type','vwap','duration',30);
specs(3) = struct('hhmm',1230,'type','vwap','duration',30);
specs(4) = struct('hhmm',1530,'type','vwap','duration',30);
% Signal and HPR #4: last half hour vwap
specs(1) = struct('hhmm', 930,'type','exact','duration',0);
specs(2) = struct('hhmm',1200,'type','exact','duration',0);
specs(3) = struct('hhmm',1525,'type','vwap' ,'duration',5);
specs(4) = struct('hhmm',1555,'type','vwap' ,'duration',5);
% Signal and HPR #5: 13:30 to 15:30 vwap
specs(1) = struct('hhmm', 930,'type','exact','duration',0);
specs(2) = struct('hhmm',1300,'type','exact','duration',0);
specs(3) = struct('hhmm',1330,'type','vwap' ,'duration',5);
specs(4) = struct('hhmm',1525,'type','vwap' ,'duration',5);
%% Signal prediction rate
load dates
results.signal = getIntradayRet(specs(1),specs(2));
results.hpr    = getIntradayRet(specs(3),specs(4));

% Correctly predicted and long positions
total   = sum(~isnan(results.signal),2);
correct = sum(sign(results.signal) == sign(results.hpr),2);
long    = sum(results.signal > 0,2);

% subplot(211)
plot(yyyymmdd2datetime(results.dates), movmean([correct,long]./total,[252,0])*100)
title '252-day moving averages'
legend 'correctly predicted' 'long positions'
ytickformat('percentage')

%% Check Open/Close in TAQ vs CRSP
OPT_NOMICRO            = true;
OPT_OUTLIERS_THRESHOLD = 1;
OPT_LAGDAY             = 1;
taq                    = loadresults('sampleFirstLast','..\results');
% taq = load('D:\TAQ\HF\results\20150921_0044_sampleFirstLast.mat');
% taq = taq.res;

if OPT_NOMICRO
    idx = isMicrocap(taq,'LastPrice',OPT_LAGDAY);
    taq = taq(~idx,:);
end

crsp      = loadresults('dsfquery','..\results');
crsp      = crsp(crsp.Prc > 0,:);
[~,ia,ib] = intersectIdDate(crsp.Permno,crsp.Date, taq.Permno, taq.Date);
crsp      = crsp(ia,:);
taq       = taq(ib,:);

% Filter outliers
taq.TAQret   = taq.LastPrice./taq.FirstPrice-1;
iout         = taq.TAQret          > OPT_OUTLIERS_THRESHOLD |...
               1./(taq.TAQret+1)-1 > OPT_OUTLIERS_THRESHOLD;
taq(iout,:)  = [];
crsp(iout,:) = [];

% Comparison table
cmp         = [crsp(:,{'Date','Permno','Openprc'}) taq(:,'FirstPrice'), ...
               crsp(:,{'Bid','Ask','Prc'}),taq(:,{'LastPrice','TAQret'})];
cmp.CRSPret = cmp.Prc./cmp.Openprc-1;

% Filter NaNs
inan = isnan(cmp.TAQret) | isnan(cmp.CRSPret);
cmp  = cmp(~inan,:);

corr(cmp.TAQret, cmp.CRSPret)
ir = mean(rets(:,1)-rets(:,2))/std(rets(:,1)-rets(:,2));

[dts,~,subs] = unique(cmp.Date);
rets         = [accumarray(subs,cmp.TAQret,[],@mean), accumarray(subs,cmp.CRSPret,[],@mean)];
plot(yyyymmdd2datetime(dts), cumprod(rets+1))

retdiff = abs(cmp.CRSPret - cmp.TAQret);
idx     = retdiff > eps*1e12;
boxplot(retdiff(idx))

%% Check new/old ff49
load('D:\TAQ\HF\intradaymom\results\bck\FF49.mat')

taq  = loadresults('price_fl');
ff49 = getFF49IndustryCodes(taq,1);
ff49 = struct('Permno', xstr2num(getVariableNames(ff49(:,2:end))), ...
    'Dates', ff49{:,1},...
    'Data', ff49{:,2:end});

% Intersect permno
[~,ia,ib]       = intersect(industry.Permno, ff49.Permno);
industry.Data   = industry.Data(:,ia);
industry.Permno = industry.Permno(ia);
ff49.Data       = ff49.Data(:,ib);
ff49.Permno     = ff49.Permno(ib);

% intersect date
[~,ia,ib]     = intersect(industry.Date, ff49.Dates);
industry.Data = industry.Data(ia,:);
industry.Date = industry.Date(ia);
ff49.Data     = ff49.Data(ib,:);
ff49.Dates    = ff49.Dates(ib);

[r,c] = find(ff49.Data ~= industry.Data & ff49.Data ~= 0)
%% CRSP ind correlations
OPT_LAGDAY     = 1;
OPT_HASWEIGHTS = true;

crsp     = loadresults('dsfquery');
crsp.Prc = abs(crsp.Prc);
idx      = isMicrocap(crsp,'Prc',OPT_LAGDAY);
crsp     = crsp(~idx,:);

% Get market caps
cap = getMktCap(crsp,OPT_LAGDAY,true);
cap = struct('Permnos', {getVariableNames(cap(:,2:end))}, ...
    'Dates', cap{:,1},...
    'Data', cap{:,2:end});

% FF49-industries classification
ff49 = getFF49IndustryCodes(crsp,1);
ff49 = struct('Permnos', {getVariableNames(ff49(:,2:end))}, ...
    'Dates', ff49{:,1},...
    'Data', ff49{:,2:end});

% Unstack returns
crsp.Ret = crsp.Prc./crsp.Openprc-1;
ret_crsp = sortrows(unstack(crsp(:,{'Permno','Date','Ret'}), 'Ret','Permno'),'Date');
ret_crsp = ret_crsp{:,2:end};

if OPT_HASWEIGHTS
    w = bsxfun(@rdivide, cap.Data, nansum(cap.Data,2));
else
    w = repmat(1./sum(~isnan(ret_taq),2), 1,size(ret_taq,2));
end
ret_crsp_w = ret_crsp.*w;

nobs    = numel(ff49.Dates);
nseries = numel(ff49.Permnos);
row     = repmat((1:nobs)', 1, nseries);
subs    = [row(:), double(ff49.Data(:)+1)];

ptfret_vw = accumarray(subs, ret_crsp_w(:),[],@nansum);
c         = corr(ptfret_vw); c(logical(eye(50))) = NaN