function  prices = getPrices(s, permnos, mst, datapath, price_fl, vwap)
prices = NaN(1,numel(permnos));
switch s.type

    case 'exact'
        % First
        if s.hhmm == 930
            [idx,col]   = ismember(price_fl.Permno, permnos);
            prices(col) = price_fl.FirstPrice(idx);
        % Last
        elseif s.hhmm == 1600
            [idx,col]   = ismember(price_fl.Permno, permnos);
            prices(col) = price_fl.LastPrice(idx);
        % Any other on the 5 minute grid
        else
            tmp         = getTaqData([],[],[],[],[],datapath,mst,false);
            idx         = serial2hhmmss(tmp.Datetime) == s.hhmm*100;
            [~,col]     = ismember(tmp.Permno(idx), permnos);
            prices(col) = tmp.Price(idx);
        end

    case 'vwap'
        [~,col]     = ismember(vwap.Permno, permnos);
        f           = fieldnames(vwap);
        idx         = strncmp('T',f,1);
        prices(col) = vwap.(f{idx});
end
end
