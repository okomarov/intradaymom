function [ptfret,tsmom] = makeTsmom(signal, hpr, w, vol, OPT_VOL_TARGET)
% Equal weighted
ptfret        = table();
isign         = @(val) sign(signal) == val;
getew         = @(val) isign(val) ./ nansum(isign(val), 2);
tsmom.ew      = @(val) sign(signal) .* hpr .* getew(val);
ptfret.ew_pos = nansum(tsmom.ew(1),2);
ptfret.ew_neg = nansum(tsmom.ew(-1),2);
ptfret.ew     = ptfret.ew_pos + ptfret.ew_neg;

% Volatility weighted
tsmom.volw      = @(val) sign(signal) .* hpr .* getew(val) .* (OPT_VOL_TARGET./vol);
ptfret.volw_pos = nansum(tsmom.volw(1),2);
ptfret.volw_neg = nansum(tsmom.volw(-1),2);
ptfret.volw     = ptfret.volw_pos + ptfret.volw_neg;

% Value weighted
getvw         = @(val) w .* isign(val) ./ nansum(w .* isign(val), 2);
tsmom.vw      = @(val) sign(signal) .* hpr .* getvw(val);
ptfret.vw_pos = nansum(tsmom.vw(1),2);
ptfret.vw_neg = nansum(tsmom.vw(-1),2);
ptfret.vw     = ptfret.vw_pos + ptfret.vw_neg;

% Linear increasing in the extremes
tsmom.liw      = @(val) sign(signal) .* hpr .* getliw(signal, isign(val));
ptfret.liw_pos = nansum(tsmom.liw(1),2);
ptfret.liw_neg = nansum(tsmom.liw(-1),2);
ptfret.liw     = ptfret.liw_pos + ptfret.liw_neg;

% EW long-only
tsmom.ew_long  = @() hpr .* (getew(1)+getew(-1));
ptfret.ew_long = nansum(tsmom.ew_long(),2);

% VOLW long-only
tsmom.volw_long  = @() hpr .* (getew(1)+getew(-1)) .* (OPT_VOL_TARGET./vol);
ptfret.volw_long = nansum(tsmom.volw_long(),2);

% VW long-only
tsmom.vw_long  = @() hpr .* (getvw(1)+getvw(-1));
ptfret.vw_long = nansum(tsmom.vw_long(),2);

% LIW long-only
tsmom.liw_long  = @() hpr .* (getliw(signal, isign(1)) + getliw(signal, isign(-1)));
ptfret.liw_long = nansum(tsmom.liw_long(),2);

tsmom.isign  = isign;
tsmom.getew  = getew;
tsmom.getvw  = getvw;
tsmom.getliw = @getliw;
end

function w = getliw(signal, idx)
signal(~idx) = NaN;
signal       = abs(signal);

% rank
[nobs,nseries] = size(signal);
z              = NaN(nobs,nseries);
for ii = 1:nobs
    z(ii,:) = tiedrank(signal(ii,:));
end
w = nan2zero(bsxfun(@rdivide,  z, nansum(z,2)));
end