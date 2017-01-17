function [lvl,dt,h] = plot_cumret(dates, ret, nlag, to_monthly)

REQUIREALL = false;

if istable(ret)
    vnames = ret.Properties.VariableNames;
    ret    = ret{:,:};
else
    vnames = {};
end

if nargin < 3 || isempty(nlag), nlag = 0; end
if nargin < 4 || to_monthly
    [ret,dates] = dret2mret(ret(1+nlag:end,:), dates(1+nlag:end), REQUIREALL);
    unit        = 'month';
else
    unit = 'day';
end

nptf = size(ret,2);
lvl  = [ones(1,nptf); cumprod(1+nan2zero(ret))];
dt   = yyyymmdd2datetime(dates);
dt   = [dateshift(dt(1),'end',unit,'previous'); dt];
h    = plot(dt, lvl);

title 'Cumulated returns'
if ~isempty(vnames)
    legend(vnames,'Interpreter','none');
end
end
