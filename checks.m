%% Number of series
ret = getIntradayRet(specs.LAST_E);
nnz(~all(isnan(ret)))
mean(sum(~isnan(ret),2))

%% Ret: average and std
try
    load('results\avg_hh_ret.mat')
catch
    OPT_RANGES = [930, 1000, 1030, 1100, 1130, 1200, 1230, 1300, 1330, 1400, 1430, 1500, 1530]'*100;
    OPT_LAGDAY = 1;
    NSERIES    = 8924;
    NDATES     = 4338;

    price_fl = loadresults('price_fl');
    idx      = isMicrocap(price_fl, 'LastPrice',OPT_LAGDAY);
    price_fl = price_fl(~idx,:);

    nranges         = numel(OPT_RANGES);
    [avg_ts,dev_ts] = deal(NaN(NSERIES,nranges));
    [avg_xs,dev_xs] = deal(NaN(NDATES,nranges));
    for ii = 1:nranges
        % Load ret
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

    % Overnight
    tmp     = loadresults('return_intraday_overnight','..\hfandlow\results');
    idx     = ismembIdDate(tmp.Permno, tmp.Date, price_fl.Permno, price_fl.Date);
    tmp     = tmp(idx,:);
    [~,~,g] = unique(tmp.Permno);
    avg_ts  = [grpstats(tmp.RetCO,g,'mean') avg_ts];
    dev_ts  = [grpstats(tmp.RetCO,g,'std')  dev_ts];
    [~,~,g] = unique(tmp.Date);
    avg_xs  = [grpstats(tmp.RetCO,g,'mean') avg_xs];
    dev_xs  = [grpstats(tmp.RetCO,g,'std')  dev_xs];

    labels = ['R\textsuperscript{on}'; arrayfun(@(h,m) sprintf('%d:%02d\n', h,m), fix(OPT_RANGES/10000), fix(mod(OPT_RANGES/100,100)),'un',0)];
    save results\avg_hh_ret.mat avg_* dev_* labels nranges und
end

% Plot overall averages
figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.4],'PaperPositionMode','auto')
XLIM = [0, nranges+2];
favg = @(p) prctile(avg_ts,p,1)*252*100;
errorbar(1:nranges+1,favg(50),favg(25)-favg(50),favg(75)-favg(50),'x','MarkerEdgeCOlor','r','LineWidth',0.75);
hold on
h    = plot(XLIM, [0,0],'Color',[0.85,0.85,0.85]);
uistack(h,'bottom');
set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YTick',-50:50:100,'Ylim',[-55,85],'XTick',1:nranges+1, 'XTickLabel',labels([1,2:2:end],:),'Xlim',XLIM)
print('imom_avgret','-depsc','-r200','-loose')

% Plot overall deviations
figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.4],'PaperPositionMode','auto')
fdev = @(p) prctile(dev_ts,p,1)*sqrt(252)*100;
errorbar(1:nranges+1,fdev(50),fdev(25)-fdev(50),fdev(75)-fdev(50),'x','MarkerEdgeCOlor','r','LineWidth',0.75);
set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YTick',0:25:50, 'Ylim',[0,50],'XTick',1:nranges+1, 'XTickLabel',labels, 'Xlim',XLIM)
print('imom_avgdev','-depsc','-r200','-loose')

% Plot time-evolution
figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.4],'PaperPositionMode','auto')
dt             = yyyymmdd2datetime(und);
[unyear,pos,g] = unique(year(dt),'last');
yret           = splitapply(@nanmean, avg_xs, g);
h              = ribbon(yret*252*100);
set(h, {'CData'}, get(h,'ZData'), 'FaceColor','interp','LineStyle','none')
view(0,90)
set(gca,'TickLabelInterpreter','latex','Layer','Top',...
    'Box','on','XGrid','off','YGrid','off','ZGrid','off',...
    'XTick',1:nranges+1, 'XTickLabel',labels([1,2:2:end]),'Xlim',XLIM,...
    'YDir','reverse','Ylim',[1,numel(unyear)],'YTick',2:4:numel(unyear),'YTickLabel',unyear(2:4:end))
colorbar('TickLabelInterpreter','latex','Ticks',[-40:40:80])
hold on
bar(repmat(18,1,nranges+1),'FaceColor','none','BarWidth',0.76)
caxis([-40,80]);
matlab2tikz('avg_time_reton.tex','StrictFontSize',true)

% Time evolution without reton
figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.4],'PaperPositionMode','auto')
yret(:,1) = NaN;
h         = ribbon(yret*252*100);
set(h, {'CData'}, get(h,'ZData'), 'FaceColor','interp','LineStyle','none')
view(0,90)
set(gca,'TickLabelInterpreter','latex','Layer','Top',...
    'Box','on','XGrid','off','YGrid','off','ZGrid','off',...
    'XTick',1:nranges+1, 'XTickLabel',labels([1,2:2:end]),'Xlim',XLIM,...
    'YDir','reverse','Ylim',[1,numel(unyear)],'YTick',2:4:numel(unyear),'YTickLabel',unyear(2:4:end))
colorbar('TickLabelInterpreter','latex')
ca        = caxis();
hold on
bar([NaN repmat(18,1,nranges)],'FaceColor','none','BarWidth',0.76)
caxis([-35 35]);
matlab2tikz('avg_time.tex','StrictFontSize',true)

% print('imom_avg_time','-depsc','-r200','-loose')
%% Volume: average and std
try
    load('results\avg_hh_volume.mat')
catch

    OPT_RANGES = [930, 1000, 1030, 1100, 1130, 1200, 1230, 1300, 1330, 1400, 1430, 1500, 1530]'*100;
    OPT_LAGDAY = 1;
    NSERIES    = 8924;
    NDATES     = 4338;

    price_fl = loadresults('price_fl');
    idx      = isMicrocap(price_fl, 'LastPrice',OPT_LAGDAY);
    price_fl = price_fl(~idx,:);

    nranges         = numel(OPT_RANGES);
    [avg_ts,dev_ts] = deal(NaN(NSERIES,nranges));
    [avg_xs,dev_xs] = deal(NaN(NDATES,nranges));
    for ii = 1:nranges
        % Load ret
        tmp   = loadresults(sprintf('volume_30_%d',OPT_RANGES(ii)),'..\results\vwap');
        idx   = ismembIdDate(tmp.Permno, tmp.Date, price_fl.Permno, price_fl.Date);
        tmp   = tmp(idx,:);
        tname = sprintf('Vol%d',OPT_RANGES(ii));
        tmp   = tmp(tmp.(tname)~=0,:);

        % Group by permno
        [unp,~,g]                        = unique(tmp.Permno);
        n                                = numel(unp);
        %     count(1:n,ii)              = accumarray(g,1);
        [avg_ts(1:n,ii), dev_ts(1:n,ii)] = grpstats(double(tmp.(tname)),g,{'mean','std'});

        % Group by date
        [und,~,g]                    = unique(tmp.Date);
        [avg_xs(:,ii), dev_xs(:,ii)] = grpstats(double(tmp.(tname)),g,{'mean','std'});
    end
    % avg(count < 10) = NaN;
    % dev(count < 10) = NaN;

    labels = arrayfun(@(h,m) sprintf('%d:%02d\n', h,m), fix(OPT_RANGES/10000), fix(mod(OPT_RANGES/100,100)),'un',0);
    save results\avg_hh_volume.mat avg_* dev_* labels nranges und
end

% Plot overall averages
figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.4],'PaperPositionMode','auto')
favg = @(p) prctile(avg_ts,p,1);
errorbar(1:nranges,favg(50),favg(25)-favg(50),favg(75)-favg(50),'x','MarkerEdgeCOlor','r','LineWidth',0.75);
set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YTick',0:200:600,'Ylim',[0,600],'XTick',1:nranges, 'XTickLabel',labels)
print('imom_avgvol','-depsc','-r200','-loose')

figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.4],'PaperPositionMode','auto')
fdev = @(p) prctile(dev_ts,p,1);
errorbar(1:nranges,fdev(50),fdev(25)-fdev(50),fdev(75)-fdev(50),'x','MarkerEdgeCOlor','r','LineWidth',0.75);
set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'Ylim',[0,1200],'XTick',1:nranges, 'XTickLabel',labels)
print('imom_avgdevvol','-depsc','-r200','-loose')

% Plot time-evolution
figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.72],'PaperPositionMode','auto')
dt             = yyyymmdd2datetime(und);
[unyear,pos,g] = unique(year(dt),'last');
yret           = splitapply(@mean, avg_xs, g);
h              = ribbon(yret);
set(h, {'CData'}, get(h,'ZData'), 'FaceColor','interp','MeshStyle','column')
set(gca,'TickLabelInterpreter','latex','Layer','Top',...
    'Box','on','XGrid','off','YGrid','off','ZGrid','off',...
    'XTick',1:nranges, 'XTickLabel',labels(1:2:end),...
    'Ylim',[1,numel(unyear)],'YTick',2:4:numel(unyear),'YTickLabel',unyear(2:4:end))
view(25,30)
print('imom_avg_vol_time','-depsc','-r200','-loose')
%% Stategy plots: ts
load dates.mat

% LAST
rets = makeTsmom(getIntradayRet(specs.NINE_TO_NOON), getIntradayRet(specs.LAST_E));

figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.40],'PaperPositionMode','auto')
[lvl,dt,h] = plot_cumret(dates,rets,1,1);
hl(4)      = h(4);
legend off, title ''
% Recession patches
YLIM       = [0.95,25];
XLIM       = xlim();
recessions = [730925,731170; 733391,733939];
X          = recessions-datenum(XLIM(1));
h          = patch(X(:,[1,1,2,2])', repmat([YLIM fliplr(YLIM)]',1,2),[0.9,0.9,0.9],'EdgeColor','none');
uistack(h,'bottom')  
% Markers
hold on
mrkStep    = 15;
set(gca,'ColorOrderIndex',1)
hl(1:3)    = plot(dt(1:mrkStep:end),lvl(1:mrkStep:end,1),'x',...
               dt(1:mrkStep:end),lvl(1:mrkStep:end,2),'o',...
               dt(1:mrkStep:end),lvl(1:mrkStep:end,3),'^');
set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YScale','log','YLim',YLIM,'YTick',[1,5,10,20])

[h,hi] = legend(hl,{'win','lose','WML','long'},'Box','off');
set(h,'Location','northwest')
set(hi(1:4),'Interpreter','latex')
set(hi(5:2:11),'LineStyle','-')
print('imom_tsmom_last30','-depsc','-r200','-loose')


% AFTERNOON
rets = makeTsmom(getIntradayRet(specs.NINE_TO_ONE), getIntradayRet(specs.AFTERNOON_E));

figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.40],'PaperPositionMode','auto')
[lvl,dt]   = plot_cumret(dates,rets,1,1);
legend off, title ''
% Recession patches
YLIM       = [0.40,6];
XLIM       = xlim();
recessions = [730925,731170; 733391,733939];
X          = recessions-datenum(XLIM(1));
h          = patch(X(:,[1,1,2,2])', repmat([YLIM fliplr(YLIM)]',1,2),[0.9,0.9,0.9],'EdgeColor','none');
uistack(h,'bottom')
% Markers
hold on
mrkStep    = 15;
set(gca,'ColorOrderIndex',1)
plot(dt(1:mrkStep:end),lvl(1:mrkStep:end,1),'x',...
     dt(1:mrkStep:end),lvl(1:mrkStep:end,2),'o',...
     dt(1:mrkStep:end),lvl(1:mrkStep:end,3),'^')

set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YScale','log','YLim',YLIM,'YTick',[0.45,1,2,5])
print('imom_tsmom_afternoon','-depsc','-r200','-loose')
%% Signal prediction rate
load dates

p{1} = getPredictionRates(specs.NINE_TO_NOON, specs.LAST_E, dates);

perc = p{1}.Correct ./(p{1}.Total - p{1}.Null); 
mean(perc) % 43.7%
mean(perc(dates > 20010431)) % 49.1%

p{2} = getPredictionRates(specs.NINE_TO_ONE, specs.AFTERNOON_E, dates);
perc = p{2}.Correct ./(p{2}.Total- p{2}.Null); 
mean(perc) % 45.1%
mean(perc(dates > 20010431)) % 48.0%
%% Strategy plots: xs
NUM_PTF_UNI = 5;

load dates.mat

% LAST
rets = portfolio_sort(getIntradayRet(specs.LAST_E),getIntradayRet(specs.NINE_TO_NOON),'PortfolioNumber',NUM_PTF_UNI);

figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.40],'PaperPositionMode','auto')
[lvl,dt,hl] = plot_cumret(dates,rets,1,1);
legend off, title ''

% Recession patches
YLIM       = [1,11];
XLIM       = xlim();
recessions = [730925,731170; 733391,733939];
X          = recessions-datenum(XLIM(1));
h          = patch(X(:,[1,1,2,2])', repmat([YLIM fliplr(YLIM)]',1,2),[0.9,0.9,0.9],'EdgeColor','none');
uistack(h,'bottom')  

% Markers
y       = get(hl,'Ydata');
c       = get(hl,'Color');
mrkStep = 15;
text(dt(1:mrkStep:end), y{1}(1:mrkStep:end),'1','HorizontalAl','center','color',c{1})
text(dt(1:mrkStep:end), y{5}(1:mrkStep:end),'5','HorizontalAl','center','color',c{5})

set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YScale','log','YLim',YLIM,'YTick',[1,2,5,10])

print('imom_xs_last30','-depsc','-r200','-loose')


% AFTERNOON
rets = portfolio_sort(getIntradayRet(specs.AFTERNOON_E),getIntradayRet(specs.NINE_TO_ONE),'PortfolioNumber',NUM_PTF_UNI);

figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.40],'PaperPositionMode','auto')
[lvl,dt,hl] = plot_cumret(dates,rets,1,1);
legend off, title ''

% Recession patches
YLIM       = [0.4,5];
XLIM       = xlim();
recessions = [730925,731170; 733391,733939];
X          = recessions-datenum(XLIM(1));
h          = patch(X(:,[1,1,2,2])', repmat([YLIM fliplr(YLIM)]',1,2),[0.9,0.9,0.9],'EdgeColor','none');
uistack(h,'bottom')  

% Markers
y       = get(hl,'Ydata');
c       = get(hl,'Color');
mrkStep = 15;
text(dt(1:mrkStep:end), y{1}(1:mrkStep:end),'1','HorizontalAl','center','color',c{1})
text(dt(1:mrkStep:end), y{5}(1:mrkStep:end),'5','HorizontalAl','center','color',c{5})

set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YScale','log','YLim',YLIM,'YTick',[0.5, 1, 2, 4])
print('imom_xs_afternoon','-depsc','-r200','-loose')
%% Strategy plots: xs plus overnight
NUM_PTF_UNI = 5;

load data_snapshot.mat

% LAST
signal = getIntradayRet(specs.NINE_TO_NOON);
rets   = portfolio_sort(getIntradayRet(specs.LAST_E),signal,'PortfolioNumber',NUM_PTF_UNI);
rets   = rets(:,[1,end]);
signal = (1+signal) .* (1 + data.reton) - 1;
tmp    = portfolio_sort(getIntradayRet(specs.LAST_E),signal,'PortfolioNumber',NUM_PTF_UNI);
rets   = [rets(:,1),tmp(:,1), rets(:,end),tmp(:,end)];

figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.40],'PaperPositionMode','auto')
[lvl,dt,hl] = plot_cumret(dates,rets,1,1);
legend off, title ''
set(hl([2,4]),'LineStyle','--')

% Recession patches
YLIM       = [0.6,40];
XLIM       = xlim();
recessions = [730925,731170; 733391,733939];
X          = recessions-datenum(XLIM(1));
h          = patch(X(:,[1,1,2,2])', repmat([YLIM fliplr(YLIM)]',1,2),[0.9,0.9,0.9],'EdgeColor','none');
uistack(h,'bottom')  

% Markers
y       = get(hl,'Ydata');
c       = get(hl,'Color');
mrkStep = 15;
text(dt(1:mrkStep:end), y{1}(1:mrkStep:end),'1','HorizontalAl','center','color',c{1})
text(dt(1:mrkStep:end), y{2}(1:mrkStep:end),'1','HorizontalAl','center','color',c{1})
text(dt(1:mrkStep:end), y{3}(1:mrkStep:end),'5','HorizontalAl','center','color',c{2})
text(dt(1:mrkStep:end), y{4}(1:mrkStep:end),'5','HorizontalAl','center','color',c{2})
set(hl(2),'Color',c{1})
set(hl(3),'Color',c{2})
set(hl(4),'Color',c{2})


set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YScale','log','YLim',YLIM,'YTick',[1,3,10,30])

print('imom_xs_last_on','-depsc','-r200','-loose')

% AFTERNOON
signal = getIntradayRet(specs.NINE_TO_ONE);
rets   = portfolio_sort(getIntradayRet(specs.AFTERNOON_E),signal,'PortfolioNumber',NUM_PTF_UNI);
rets   = rets(:,[1,end]);
signal = (1+signal) .* (1 + data.reton) - 1;
tmp    = portfolio_sort(getIntradayRet(specs.AFTERNOON_E),signal,'PortfolioNumber',NUM_PTF_UNI);
rets   = [rets(:,1),tmp(:,1), rets(:,end),tmp(:,end)];

figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.40],'PaperPositionMode','auto')
[lvl,dt,hl] = plot_cumret(dates,rets,1,1);
legend off, title ''
set(hl([2,4]),'LineStyle','--')

% Recession patches
YLIM       = [0.6,10];
XLIM       = xlim();
recessions = [730925,731170; 733391,733939];
X          = recessions-datenum(XLIM(1));
h          = patch(X(:,[1,1,2,2])', repmat([YLIM fliplr(YLIM)]',1,2),[0.9,0.9,0.9],'EdgeColor','none');
uistack(h,'bottom')  

% Markers
y       = get(hl,'Ydata');
c       = get(hl,'Color');
mrkStep = 15;
text(dt(1:mrkStep:end), y{1}(1:mrkStep:end),'1','HorizontalAl','center','color',c{1})
text(dt(1:mrkStep:end), y{2}(1:mrkStep:end),'1','HorizontalAl','center','color',c{1})
text(dt(1:mrkStep:end), y{3}(1:mrkStep:end),'5','HorizontalAl','center','color',c{2})
text(dt(1:mrkStep:end), y{4}(1:mrkStep:end),'5','HorizontalAl','center','color',c{2})
set(hl(2),'Color',c{1})
set(hl(3),'Color',c{2})
set(hl(4),'Color',c{2})

set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YScale','log','YLim',YLIM,'YTick',[1,2,4,8])

print('imom_xs_afternoon_on','-depsc','-r200','-loose')
%% Alternative specifications
getWML = @(signal,hpr) subsref(makeTsmom(getIntradayRet(signal), getIntradayRet(hpr)),struct('type','.','subs','ew_fun'));
corr([getWML(specs.NINE_TO_NOON, specs.LAST_E),...
    getWML(specs.NINE_TO_NOON, specs.LAST_V),...
    getWML(specs.TEN_TO_ONE, specs.LAST_E),...
    getWML(specs.FIRST, specs.LAST_E),...
    getWML(specs.NINE_TO_ONE, specs.AFTERNOON_E),...
    getWML(specs.NINE_TO_ONE, specs.AFTERNOON_V),...
    getWML(specs.NINE_TO_ONE, specs.SLAST_E),...
    getWML(specs.TEN_TO_ONE, specs.SLAST_E)],'rows','pairwise')

NUM_PTF_UNI = 5;
getXS       = @(signal,hpr) portfolio_sort(getIntradayRet(hpr),getIntradayRet(signal),'PortfolioNumber',NUM_PTF_UNI);
ptf         = cat(3,getXS(specs.NINE_TO_NOON, specs.LAST_E),...
    getXS(specs.NINE_TO_NOON, specs.LAST_V),...
    getXS(specs.TEN_TO_ONE, specs.LAST_E),...
    getXS(specs.FIRST, specs.LAST_E),...
    getXS(specs.NINE_TO_ONE, specs.AFTERNOON_E),...
    getXS(specs.NINE_TO_ONE, specs.AFTERNOON_V),...
    getXS(specs.NINE_TO_ONE, specs.SLAST_E),...
    getXS(specs.TEN_TO_ONE, specs.SLAST_E));
tmp         = arrayfun(@(x) corr(squeeze(ptf(:,x,:)),'rows','pairwise'),1:NUM_PTF_UNI,'un',0);
tmp         = nanmean(cat(3,tmp{:}),3)
%% Cost analysis

load data_snapshot.mat

ptfret_xs                           = {}; stats_xs = {};
[ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.NINE_TO_NOON, specs.LAST_E,       data,dates,OPT_,true);
[ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.NINE_TO_NOON, specs.LAST_V,       data,dates,OPT_,false);
[ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.NINE_TO_ONE , specs.AFTERNOON_E, 	data,dates,OPT_,true);
[ptfret_xs{end+1}, stats_xs{end+1}] = estimateXSmom(specs.NINE_TO_ONE , specs.AFTERNOON_V,  data,dates,OPT_,false);

% High-low spread by 2012 Corwin, Schults
hl                       = estimateHighLowSpread(OPT_.VOL_LAG);
[~,pos]                  = ismembIdDate(data.mst.Permno, data.mst.Date, hl.Permno, hl.Date);
spread.hl                = myunstack(hl(pos,:),'Spread');
spread.hl                = spread.hl{:,2:end};
spread.hl(spread.hl < 0) = 0;

% Closing bid-ask spread to the mid-point
dsf          = loadresults('dsfquery','..\results');
[~,pos]      = ismembIdDate(data.mst.Permno, data.mst.Date, dsf.Permno, dsf.Date);
dsf          = dsf(pos,:);
dsf          = convertColumn(dsf,'double',{'Bid','Ask'});
dsf.BAspread = 2*(dsf.Ask-dsf.Bid)./(dsf.Ask+dsf.Bid);
spread.ba    = myunstack(dsf(:,{'Permno','Date','BAspread'}),'BAspread');
spread.ba    = spread.ba{:,2:end};
clear hl dsf

% Ptfret costs
spread.hl_ptf = portfolio_sort(spread.hl, getIntradayRet(specs.NINE_TO_NOON),'PortfolioNumber',OPT_.NUM_PTF_UNI);
spread.ba_ptf = portfolio_sort(spread.ba, getIntradayRet(specs.NINE_TO_NOON),'PortfolioNumber',OPT_.NUM_PTF_UNI);

ptfdiff = @(ret, cost, costall) nan2zero(ret) - nan2zero([cost, costall]);

% Table
printse = @(retdiff) arrayfun(@(x)sprintf('[%.3f]',x), sqrt(nwse(retdiff)),'un',0);
mydisp  = @(retdiff) [num2cell(nanmean(retdiff));  printse(retdiff)];

[mydisp(ptfret_xs{1}{:,:});
 mydisp(ptfret_xs{3}{:,:});
 num2cell([nanmean(spread.hl_ptf,1), nanmean(nanmean(spread.hl,2),1)]); 
 num2cell([nanmean(spread.ba_ptf,1), nanmean(nanmean(spread.ba,2),1)]);
 mydisp(ptfdiff(ptfret_xs{1}{:,:}, spread.hl_ptf, nanmean(spread.hl,2)));
 mydisp(ptfdiff(ptfret_xs{1}{:,:}, spread.ba_ptf, nanmean(spread.ba,2)));
 mydisp(ptfret_xs{2}{:,:});
 mydisp(ptfdiff(ptfret_xs{2}{:,:}, spread.hl_ptf, nanmean(spread.hl,2)));
 mydisp(ptfdiff(ptfret_xs{2}{:,:}, spread.ba_ptf, nanmean(spread.ba,2)));
 mydisp(ptfret_xs{4}{:,:})]; 

% Figure last
y  = [nanmean(ptfret_xs{1}{:,:},1); 
      nanmean(ptfdiff(ptfret_xs{1}{:,:}, spread.hl_ptf, nanmean(spread.hl,2)),1);
      nanmean(ptfret_xs{2}{:,:},1)];
y  = [y(:,1:end-1) NaN(3,1) y(:,end)];
se = 2*[stats_xs{1}{'Se',:}; 
      sqrt(nwse(ptfdiff(ptfret_xs{1}{:,:}, spread.hl_ptf, nanmean(spread.hl,2))));
      stats_xs{2}{'Se',:}]; 
se = [se(:,1:end-1) NaN(3,1) se(:,end)];   

figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.4],'PaperPositionMode','auto')
h      = bar(y',1,'grouped','LineStyle','none');
styles = {'--s','-.^',':*'};
hold on
for ii = 1:numel(h)
    errorbar(getBarCenter(h(ii)), y(ii,:), se(ii,:), styles{ii},'MarkerSize',5,'MarkerFaceColor','auto');
end
delete(h)
XLIM = [0,13];
h    = plot(XLIM, [0,0],'Color',[0.85,0.85,0.85]);
uistack(h,'bottom');
set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YLim',[-0.02,0.1],'Ytick',0:0.03:0.09,'XLim',XLIM,'XTick',[1:10, 12],'XtickLabels',['Lose'; cellstr(num2str((2:9)')); 'Win'; 'All'])
print('imom_cost_last','-depsc','-r200','-loose')

% Figure afternoon
y  = [nanmean(ptfret_xs{3}{:,:},1); 
      nanmean(ptfdiff(ptfret_xs{3}{:,:}, spread.hl_ptf, nanmean(spread.hl,2)),1);
      nanmean(ptfret_xs{4}{:,:},1)];
y  = [y(:,1:end-1) NaN(3,1) y(:,end)];
se = 2*[stats_xs{3}{'Se',:}; 
      sqrt(nwse(ptfdiff(ptfret_xs{3}{:,:}, spread.hl_ptf, nanmean(spread.hl,2))));
      stats_xs{4}{'Se',:}]; 
se = [se(:,1:end-1) NaN(3,1) se(:,end)];   

figure
set(gcf, 'Position', get(gcf,'Position').*[1,1,1,0.4],'PaperPositionMode','auto')
h      = bar(y',1,'grouped','LineStyle','none');
styles = {'--s','-.^',':*'};
hold on
for ii = 1:numel(h)
    errorbar(getBarCenter(h(ii)), y(ii,:), se(ii,:), styles{ii},'MarkerSize',5,'MarkerFaceColor','auto');
end
delete(h)
XLIM = [0,13];
h    = plot(XLIM, [0,0],'Color',[0.85,0.85,0.85]);
uistack(h,'bottom');
set(gca, 'TickLabelInterpreter','latex','Layer','Top',...
    'YLim',[-0.06,0.1],'Ytick',-0.04:0.04:0.08,'XLim',XLIM,'XTick',[1:10, 12],'XtickLabels',['Lose'; cellstr(num2str((2:9)')); 'Win'; 'All'])
print('imom_cost_afternoon','-depsc','-r200','-loose')

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