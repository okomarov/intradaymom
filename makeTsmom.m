function [ptfret, avgsignal] = makeTsmom(signal, hpr)
ptfret = table();

% Equal weighted
hpr_win       = apply_mask(signal, 1,hpr);
hpr_los       = apply_mask(signal,-1,hpr);
count_win     = sum(~isnan(hpr_win),2);
count_los     = sum(~isnan(hpr_los),2);
count         = count_win + count_los;
ptfret.ew_win = nanmean(hpr_win,2);
ptfret.ew_win_ = ptfret.ew_win.*count_win./count;
ptfret.ew_los = nanmean(hpr_los,2);
ptfret.ew_los_ = ptfret.ew_los.*count_los./count;
ptfret.ew_fun = ptfret.ew_win - ptfret.ew_los;
ptfret.ew_sgn = (nansum(hpr_win,2) - nansum(hpr_los,2)) ./ count;

% EW long-only
ptfret.ew_long  = ptfret.ew_win + ptfret.ew_los;
ptfret.ew_long_ = (nansum(hpr_win,2) + nansum(hpr_los,2)) ./ count;

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
