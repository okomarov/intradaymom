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
ptfret.ew_long = ptfret.ew_pos - ptfret.ew_neg;

% VOLW long-only
ptfret.volw_long = ptfret.volw_pos - ptfret.volw_neg;

% VW long-only
ptfret.vw_long = ptfret.vw_pos - ptfret.vw_neg;

% LIW long-only
ptfret.liw_long = ptfret.liw_pos - ptfret.liw_neg;

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