function results = regressOnLongOnly(results, OPT_REGRESSION_LONG_MINOBS)
opts = {'intercept',false,'display','off','type','HAC','bandwidth',floor(4*(results.N/100)^(2/9))+1,'weights','BT'};

fields  = results.Names;
fields  = fields(cellfun(@isempty, regexp(fields,'_long')));
nfields = numel(fields);
for ii = 1:nfields
    f          = fields{ii};
    l          = ones(results.N, 1);
    X          = num2cell(results.tsmom.(f)() * 100,1);
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
end
