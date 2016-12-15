function sparklines = getSparkline(v,ylim,xlim)
if nargin < 2
    ylim = [0,1];
end
if nargin < 3
    xlim = [0,1];
end
if isvector(v)
    v = v(:)';
end

% Rescale to [0,1] and then into ylim
vmin    = min(v,[],2);
vmax    = max(v,[],2);
vscaled = (v - vmin)./(vmax-vmin);
vscaled = vscaled.*(ylim(2)-ylim(1)) + ylim(1);

[rows,n]   = size(v);
x          = linspace(xlim(1),xlim(end),n);
sparklines = cell(rows,1);
for ii = 1:rows
    sparklines{ii} = sprintf('\\begin{sparkline}{%d}\\spark%s /\\end{sparkline}',n,sprintf(' %.3g %.3g',[x; vscaled(ii,:)]));
end
end
