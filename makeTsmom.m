function [ptfret,tsmom] = makeTsmom(signal, hpr, w, vol, OPT_VOL_TARGET)
% Equal weighted
ptfret    = table();
isign     = @(val) sign(signal) == val;
getew     = @(val) isign(val) ./ nansum(isign(val), 2);
tsmom.ew  = @() sign(signal) .* hpr .* (getew(1) + getew(-1));
ptfret.ew = nansum(tsmom.ew(),2);

% Volatility weighted
tsmom.volw  = @() sign(signal) .* hpr .* (getew(1) + getew(-1)) .* (OPT_VOL_TARGET./vol);
ptfret.volw = nansum(tsmom.volw(),2);

% Value weighted
getvw     = @(val) w .* isign(val) ./ nansum(w .* isign(val), 2);
tsmom.vw  = @() sign(signal) .* hpr .* (getvw(1) + getvw(-1));
ptfret.vw = nansum(tsmom.vw(),2);

% EW long-only
tsmom.ew_long  = @() hpr .* (getew(1) + getew(-1));
ptfret.ew_long = nansum(tsmom.ew_long(),2);

% VW long-only
tsmom.vw_long  = @() hpr .* (getvw(1) + getvw(-1));
ptfret.vw_long = nansum(tsmom.vw_long(),2);

% VOLW long-only
tsmom.volw_long  = @() hpr .* (getew(1) + getew(-1)) .* (OPT_VOL_TARGET./vol);
ptfret.volw_long = nansum(tsmom.volw_long(),2);

tsmom.isign = isign;
tsmom.getew = getew;
tsmom.getvw = getvw;
end
