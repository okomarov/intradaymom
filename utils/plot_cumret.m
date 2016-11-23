function lvl = plot_cumret(dates, ret, nlag, to_monthly)

REQUIREALL = true;

if istable(ret)
    vnames = ret.Properties.VariableNames;
    ret    = ret{:,:};
else
    vnames = {};
end

if nargin < 3 || isempty(nlag), nlag = 0; end
if nargin < 4 || to_monthly
    [ret,dates] = dret2mret(ret(nlag:end,:), dates(nlag:end), REQUIREALL);
    unit        = 'month';
else
    unit = 'day';
end

nptf      = size(ret,2);
lvl       = [ones(1,nptf); cumprod(1+ret)];
plotdates = yyyymmdd2datetime(dates);
plotdates = [dateshift(plotdates(1),'end',unit,'previous'); plotdates];
plot(plotdates, lvl)

title 'Cumulated returns'
if ~isempty(vnames)
    legend(vnames,'Interpreter','none');
end
end
