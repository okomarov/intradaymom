function [ptfret,tsmom] = makeTsmom(signal, hpr, w, vol, OPT_VOL_TARGET, only_ew)
if nargin < 6, only_ew = false; end

% Equal weighted
ptfret        = table();
isign         = @(signal,val) sign(signal) == val;
getew         = @(signal,val) isign(signal,val) ./ nansum(isign(signal,val), 2);
tsmom.ew      = @(signal,hpr,val) sign(signal) .* hpr .* getew(signal,val);
ptfret.ew_pos = nansum(tsmom.ew(signal,hpr,1),2);
ptfret.ew_neg = nansum(tsmom.ew(signal,hpr,-1),2);
ptfret.ew     = ptfret.ew_pos + ptfret.ew_neg;

if ~only_ew

    % Volatility weighted
    tsmom.volw      = @(signal,hpr,vol,val) sign(signal) .* hpr .* getew(signal,val) .* (OPT_VOL_TARGET./vol);
    ptfret.volw_pos = nansum(tsmom.volw(signal,hpr,vol,1),2);
    ptfret.volw_neg = nansum(tsmom.volw(signal,hpr,vol,-1),2);
    ptfret.volw     = ptfret.volw_pos + ptfret.volw_neg;


    % Value weighted
    getvw         = @(signal,val,w) w .* isign(signal,val) ./ nansum(w .* isign(signal,val), 2);
    tsmom.vw      = @(signal,hpr,w,val) sign(signal) .* hpr .* getvw(signal,val,w);
    ptfret.vw_pos = nansum(tsmom.vw(signal,hpr,w,1),2);
    ptfret.vw_neg = nansum(tsmom.vw(signal,hpr,w,-1),2);
    ptfret.vw     = ptfret.vw_pos + ptfret.vw_neg;

    % Linear increasing in the extremes
    tsmom.liw      = @(signal,hpr,val) sign(signal) .* hpr .* getliw(signal, isign(signal,val));
    ptfret.liw_pos = nansum(tsmom.liw(signal,hpr,1),2);
    ptfret.liw_neg = nansum(tsmom.liw(signal,hpr,-1),2);
    ptfret.liw     = ptfret.liw_pos + ptfret.liw_neg;

    % EW long-only
    ptfret.ew_long = ptfret.ew_pos - ptfret.ew_neg;

    % VOLW long-only
    ptfret.volw_long = ptfret.volw_pos - ptfret.volw_neg;

    % VW long-only
    ptfret.vw_long = ptfret.vw_pos - ptfret.vw_neg;

    % LIW long-only
    ptfret.liw_long = ptfret.liw_pos - ptfret.liw_neg;
end

if nargout == 2
    tsmom.isign  = isign;
    tsmom.getew  = getew;
    tsmom.getvw  = getvw;
    tsmom.getliw = @getliw;
end
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