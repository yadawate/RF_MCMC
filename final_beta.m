clc;
clear all;
close all;
%% Data

T1 = readtable('seasons0.xlsx','Sheet','winter');
T2 = readtable('seasons0.xlsx','Sheet','spring');
T3 = readtable('seasons0.xlsx','Sheet','summer');
T4 = readtable('seasons0.xlsx','Sheet','autumn');

X = [T1.Air_T T1.depth T1.time;
    T2.Air_T T2.depth T2.time;
    T3.Air_T T3.depth T3.time;
    T4.Air_T T4.depth T4.time];
Y = [T1.AspaltTD;T2.TDMeasured;T3.TDMeasured;T4.TDMeasured];
X = X./max(X);
Y = Y./max(Y);
n = size(X,1);
num_train = floor(0.7*n);
n_idx = randperm(n,num_train);
n_tst = ~ismember(1:n,n_idx);
X_train = X(n_idx,:);
X_test = X(n_tst,:);
y_train = Y(n_idx,:);
y_test = Y(n_tst,:);

%% Clustering
idx = kmeans([X_train(:,2) X_train(:,3)],40);

%idx = clusterdata([X_train y_train],'Maxclust',80); 

%gm = fitgmdist([X_train y_train],10);
%idx = cluster(gm,[X_train y_train]);


u_idx = unique(idx);

%% Cluster idetification using RF
rand('state', 0);
randn('state', 0);


opts= struct;
opts.depth= 9;
opts.numTrees= 100;
opts.numSplits= 25;
numTrees= opts.numTrees; 
treeModels= cell(1, numTrees);
for i=1:numTrees
   treeModels{i} = treeTrain([X_train(:,2) X_train(:,3)], idx, opts);
end
model.treeModels = treeModels;
%% Loop over unique clusters
n_burnin = 2000;

for itx = 1:length(u_idx)
    X_trn = X_train(idx==u_idx(itx),:);
    Y_trn = y_train(idx==u_idx(itx));
    
    %% MH algo for time
    
    [N,p] = size(X_trn);
    beta_0 = [0 0 0]';
    sample = [];
    var_r = 0.0003;
    p_0 = X_trn*beta_0;
    for i = 1:10000
        beta_t(:,1) = mvnrnd(beta_0(1),var_r);
        beta_t(:,2) = mvnrnd(beta_0(2),var_r);
        beta_t(:,3) = mvnrnd(beta_0(3),var_r);
        beta_t = beta_t';
        p_t = X_trn*beta_t;
        u = log(rand);
        lik0 = posterior(beta_0,p_0,Y_trn);
        likt = posterior(beta_t,p_t,Y_trn);
        acc = likt - lik0;
        if acc >= u
            beta_0 = beta_t;
            p_0 = p_t;
            sample = [sample beta_t];
        end
    end
    rel_out = sample(:,n_burnin:end);
    r_mean(itx,:) = mean(rel_out');
end

%% test of output against test data

c_pred = forestTest(model, [X_test(:,2) X_test(:,3)]);

for i = 1:length(c_pred)
    id_num = c_pred(i);
    r_coeff = r_mean(id_num,:);
    y_pred(i) = X_test(i,:)*r_coeff';
end

R = corr(y_pred',y_test)
mse = (sum((y_pred' - y_test).^2)/length(y_test))

