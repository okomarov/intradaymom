%%
OPT_LAGDAY = 1;
%% Import data
% Index data
datapath = '..\data\TAQ\sampled\5min\nobad_vw';
master   = load(fullfile(datapath,'master'),'-mat');
master   = master.mst(master.mst.Permno ~= 0,:);
master   = sortrows(master,{'Permno','Date'});

% Get market
mkt = master(master.Permno == 84398,:);

% Common shares
idx    = iscommonshare(master);
master = master(idx,:);

% Incomplete days
idx    = isprobdate(master.Date);
master = master(~idx,:);

% Minobs
res               = loadresults('countBadPrices','..\results');
isEnoughObs       = (res.Ntot - res.Nbadtot) >= 79;
res               = addPermno(res);
[~,pos]           = ismembIdDate(master.Permno, master.Date, res.Permno, res.Date);
isEnoughObs       = isEnoughObs(pos,:);
[~,idx,pos]       = lagpanel(master(:,{'Date','Permno'}),'Permno',OPT_LAGDAY);
isEnoughObs(~idx) = isEnoughObs(pos);
master            = master(isEnoughObs,:);

% Has mkt cap on the previous day
cap    = getMktCap(master, OPT_LAGDAY);
idx    = cap.Cap ~= 0;
master = master(idx,:);

% % Count
% [~,~,subs] = unique(master.Date);
% accumarray(subs,1)

% % Number of observations per 30 min
% res         = AnalyzeImom('avgObsPerBucket',[],[],'data\TAQ\count\',[],8);
% [un,~,subs] = unique(res(:,{'Date','HHMMSS'}));
% un.Avg      = accumarray(subs, res.Sum)./accumarray(subs, res.N);

% CRSP returns
dsf       = loadresults('dsfquery','..\results');
[~,ia,ib] = intersectIdDate(dsf.Permno, dsf.Date,master.Permno, master.Date);
dsf       = dsf(ia,:);
master    = master(ib,:);

% Sample first and last price
price_fl = loadresults('sampleFirstLast','..\results');
price_fl = addPermno(price_fl);
[~,pos]  = ismembIdDate(master.Permno, master.Date, price_fl.Permno, price_fl.Date);
price_fl = price_fl(pos,:);

% Add back mkt
master = [master; mkt];

save('results\master.mat', 'master')
save('results\price_fl.mat','price_fl')
save('results\dsfquery.mat','dsf')

%% Half hour returns
clearvars -except master price_fl
[idx,pos]                = ismembIdDate(master.Permno, master.Date, price_fl.Permno, price_fl.Date);
master.FirstPrice(idx,1) = price_fl.FirstPrice(pos(idx));
master.LastPrice(idx,1)  = price_fl.LastPrice(pos(idx));
master                   = cache2cell(master,master.File);

ranges = [ 930, 1000, 1030, 1100, 1130, 1200, 1230, 1300, 1330, 1400, 1430,...
          1500, 1530, 1600]'*100;
ranges = [ranges(1:end-1), ranges(2:end)];

for r = 1:size(ranges,1)
    opt           = struct('HalfHourRange',ranges(r,:));
    [~, filename] = AnalyzeImom('halfHourRet',[],master,'..\data\TAQ\sampled\5min\nobad_vw',[],[],opt);

    % Rename file
    oldName = fullfile('results',filename);
    newName = fullfile('results', regexprep(filename, '.mat', sprintf('%d.mat',ranges(r,1))));
    movefile(oldName,newName)
end

for r = 1:size(ranges,1)
    opt           = struct('HalfHourRange',ranges(r,:));
    [~, filename] = AnalyzeImom('halfHourVol',[],master,'..\data\TAQ\sampled\5min\nobad_vw',[],[],opt);

    % Rename file
    oldName = fullfile('results',filename);
    newName = fullfile('results', regexprep(filename, '.mat', sprintf('%d.mat',ranges(r,1))));
    movefile(oldName,newName)
end