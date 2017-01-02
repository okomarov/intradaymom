function [ptfret, avgsignal] = makeTsmom(signal, hpr)
ptfret = table();

% Equal weighted
hpr_win       = apply_mask(signal, 1,hpr);
hpr_los       = apply_mask(signal,-1,hpr);
ptfret.ew_win = nanmean(hpr_win,2);
ptfret.ew_los = nanmean(hpr_los,2);
ptfret.ew_fun = ptfret.ew_win - ptfret.ew_los;

% EW long-only
ptfret.ew_long = ptfret.ew_win + ptfret.ew_los;

if nargout == 2
    avgsignal = [nanmean(apply_mask(signal, 1,signal),2),...
                 nanmean(apply_mask(signal,-1,signal),2)];
end
end

function mask = isign(signal,val)
mask = sign(signal) == val;
end

function out = apply_mask(signal,val,hpr)
    out       = NaN(size(hpr));
    mask      = isign(signal,val);
    out(mask) = hpr(mask);
end
