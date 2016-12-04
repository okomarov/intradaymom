t = {}; c = {}; o = {};
% DEFAULT
[t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',1,'PREDICT_SKIP',1,'VOL_STANDARDIZE',1,'VOL_TYPE','e','VOL_LAG',60);
[t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',0,'PREDICT_SKIP',1,'VOL_STANDARDIZE',1,'VOL_TYPE','e','VOL_LAG',60);
% SIMPLE VOL
[t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',1,'VOL_TYPE','s');
% [t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',0,'VOL_TYPE','s');
% NO VOL
[t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',1,'VOL_STANDARDIZE',0);
% [t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',0,'VOL_STANDARDIZE',0);
% NO SKIP
[t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',1,'PREDICT_SKIP',0);
% [t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',0,'PREDICT_SKIP',0);
% OVERNIGHT
[t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',1,'RET_USE_OVERNIGHT',1);
% [t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',0,'RET_USE_OVERNIGHT',1);
% 10 LOOKBACK
[t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',1,'VOL_LAG',10);
% [t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',0,'VOL_LAG',10);
% 1993-2001
[t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',1,'DATE_RANGE',[-inf, 20010431]);
% [t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',0,'DATE_RANGE',[-inf, 20010431]);
% 2001-2010
[t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',1,'DATE_RANGE',[20010501,inf]);
% [t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',0,'DATE_RANGE',[20010501,inf]);
% Skip 2007-2009 recession
[t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',1,'DATE_RANGE',{[-inf,20071214] [20090616, inf]});
% [t{end+1},c{end+1},o{end+1}] = predictability('PREDICT_MULTI',0,'DATE_RANGE',{[-inf,20071214] [20090616, inf]});
