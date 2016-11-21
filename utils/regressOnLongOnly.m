function results = regressOnLongOnly(results, OPT_REGRESSION_LONG_MINOBS, OPT_REGRESSION_LONG_ALPHA)
opts = {'intercept',false,'display','off','type','HAC','bandwidth',floor(4*(results.N/100)^(2/9))+1,'weights','BT'};

fields  = regexp(results.Names,'\w+(?=_long)','match','once');
fields  = fields(~cellfun(@isempty, fields));
nfields = numel(fields);
for ii = 1:nfields
    f          = fields{ii};
    l          = ones(results.N, 1);
    X          = results.tsmom.(f)(1);
    tmp        = results.tsmom.(f)(-1);
    idx        = results.tsmom.isign(-1);
    X(idx)     = tmp(idx);
    X          = num2cell(X * 100,1);
    y          = results.tsmom.([f '_long'])()*100;
    enough_obs = sum(~isnan(y)) > OPT_REGRESSION_LONG_MINOBS;
    y          = num2cell(y,1);

    [se, coeff] = deal(NaN(results.nseries,2));
    parfor c = 1:results.nseries
        if enough_obs(c)
            [~,se(c,:), coeff(c,:)] = hac([l X{c}],y{c}, opts{:});
        end
    end

    tratio = coeff./se;
    pval   = 2 * normcdf(-abs(tratio));

    results.RegressOnLong.(f).Coeff  = coeff;
    results.RegressOnLong.(f).Se     = se;
    results.RegressOnLong.(f).Tratio = tratio;
    results.RegressOnLong.(f).Pval   = pval;
end

% Plot percentage positive and negative
X = NaN(nfields,3);
for ii = 1:nfields
    f       = fields{ii};
    data    = results.RegressOnLong.(f);
    tot     = nnz(~isnan(data.Coeff(:,1)));
    neg     = nnz(data.Coeff(:,1) < 0 & data.Pval < OPT_REGRESSION_LONG_ALPHA);
    pos     = nnz(data.Coeff(:,1) > 0 & data.Pval < OPT_REGRESSION_LONG_ALPHA);
    X(ii,:) = [neg, tot-neg-pos, pos]./tot;
end
figure
h = barh(X*100,'stacked');
set(gcf,'Position', [680 795 550 200])
set(h(1),'FaceColor',[0.85, 0.325, 0.098])
set(h(2),'FaceColor',[0.929, 0.694, 0.125])
set(h(3),'FaceColor',[0, 0.447, 0.741])
title 'Alphas from TSMOM regressed on long-only positions'
legend({'stat. neagative','insignificant','stat. positive'},'Location','southoutside','Orientation','horizontal')
xtickformat('percentage')
yticklabels(fields)
end
