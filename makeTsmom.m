function [ptfret,tsmom] = makeTsmom(signal, hpr, w, vol, OPT_VOL_TARGET)
% Equal weighted
ptfret        = table();
isign         = @(val) sign(signal) == val;
getew         = @(val) isign(val) ./ nansum(isign(val), 2);
tsmom.ew      = @(val) sign(signal) .* hpr .* getew(val);
pos           = tsmom.ew(1);
neg           = tsmom.ew(-1);
ptfret.ew_pos = nansum(pos,2);
ptfret.ew_neg = nansum(neg,2);
ptfret.ew     = nansum(pos,2) + nansum(neg,2);

% Volatility weighted
tsmom.volw      = @(val) sign(signal) .* hpr .* getew(val) .* (OPT_VOL_TARGET./vol);
pos             = tsmom.volw(1);
neg             = tsmom.volw(-1);
ptfret.volw_pos = nansum(pos,2);
ptfret.volw_neg = nansum(neg,2);
ptfret.volw     = nansum(pos,2) + nansum(neg,2);

% Value weighted
getvw         = @(val) w .* isign(val) ./ nansum(w .* isign(val), 2);
tsmom.vw      = @(val) sign(signal) .* hpr .* getvw(val);
pos           = tsmom.vw(1);
neg           = tsmom.vw(-1);
ptfret.vw_pos = nansum(pos,2);
ptfret.vw_neg = nansum(neg,2);
ptfret.vw     = nansum(pos,2) + nansum(neg,2);

% Linear increasing in the extremes
tsmom.liw      = @(val) sign(signal) .* hpr .* getliw(signal, isign(val));
pos            = tsmom.liw(1);
neg            = tsmom.liw(-1);
ptfret.liw_pos = nansum(pos,2);
ptfret.liw_neg = nansum(neg,2);
ptfret.liw     = nansum(pos,2) + nansum(neg,2);

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