
featurecodepath =  fullfile(pwd);%set to the repository root dir
assert(exist(fullfile(featurecodepath,'nnf_sparse_code','build','Release','3DDIS_OMP.exe'), 'file') == 2,'not in code root folder')
addpath(genpath(featurecodepath))
ddis_params.code_path = pwd;
ddis_params.surface_recon = 'LOAD';%can choose POISON if taking a point cloud
ddis_params.keypoints_str = 'ALL';%look in the cpp for different options. other options implemented but not tested
ddis_params.normals = 'MESHNORMS';%
ddis_params.distances = 'GEODESIC';%can choose euclidean for experimental reasons. default is geodesic
ddis_params.feature.type = 'FPFH';%supports FPFH(paper),SHOT,ROPS,PFH and loading of HKS
ddis_params.similarity = 'TRIDIS'; %Options are TRIDIS(paper version),WDIS(single scale), DDIS(similar to Talmi'17) TRIDISP(gaussian kernels as distance penalty)
ddis_params.feature.rad = 3.00; %fraction prefcentage of sqrt(Area(M)) to use for FPFH radius
ddis_params.deformation_frac = 0.5; %distance penalty coefficient(epsilon). has negligent effect
ddis_params.geodesic_disc_frac = 60.0; %Sparse algorithm beta. would input [beta,2*beta/3,beta/3]
ddis_params.nnrej=1; % if lower than 1 results in rejecting very NN's which have a very similar 2nd best match
ddis_params.threads = 6; %number of threads to run the sparse correpsondence algorithm on. should be less thna number of threads on pc
ddis_params.use_greedy_opt = true; %if false no refinement is done
ddis_params.set = 'topology' 

FSPM_params.num_eigen = 90; %number of eigenfunctions for the Fully Spectral part of the method
FSPM_params.max_iter = 100; %maximal number of optimization iterations
FSPM_params.manopt_maxiter = 100;
FSPM_params.icp_maxiter = 0; %FSPM uses 0 by default
FSPM_params.mu.dense =1e-1; %delta size around sparse correspondence
FSPM_params.mu.sparse =1e-1; %delta size in FSPM refinment steps

FSPM_params.verbose = true; %true for printing output and figures to screen
FSPM_params.num_reiterate = 1; %number of refinement steps in Fully Spectral. Best result for Topological Noise is obtained with 1

models_dir = 'D:\OneDrive\SHREC16B\';%path to SHREC'16 Matching of Deformable Shapes with Topological Noise root dir (obtain from https://vision.in.tum.de/~laehner/shrec2016/dataset.php)
cd(models_dir)
null_model_dir = fullfile(models_dir);
part_model_dir = fullfile(models_dir);
similarity = 'TRIDIS';
feature='FPFH';
R_thresh='60.0';
matches = cell(numel(files),1);
frac = '3.00';
divfrac = '0.5';
NNR='1.00';
matches_folder = [ '.\' similarity '_' R_thresh ...
    '_DF_' divfrac ...
    '_NNR_' NNR ...
    '_FR_' frac ...
    '\']
mkdir(matches_folder)
dense_match_folder = fullfile(matches_folder,'dense')
mkdir(dense_match_folder)

for j=16:25
    null_model = ['kid', num2str(j)];
    
    for i=16:25
        if i~=j
            prob = ['kid', num2str(i), '_kid', num2str(j)];
            name = ['kid', num2str(i)];
            fprintf('-------------------------------------\nProcessing shape %d of %d\n',fi, numel(files));
            %clear M;
            %clear N;
            
            N = off_to_shape(fullfile(part_model_dir,[name '.off']));
            M = off_to_shape(fullfile(null_model_dir,[null_model '.off']));
            
            tic;
            
            [matches_sparse] = DDIS_sparse_correspondences(null_model,null_model_dir,name,part_model_dir,ddis_params);
            rmdir(name,'s')
            times(fi)=toc
            
            barmap = shape_point_to_barycentric_map(M);
            diam=sqrt(sum(calc_tri_areas(M)));
            FSPM_params.num_deltas = round(N.n/5);
            FSPM_params.init_delta_radius = 1/sqrt(pi*numel(matches_sparse)/2)*diam;
            FSPM_params.delta_radius = FSPM_params.init_delta_radius*1/(numel(matches_sparse)/2/FSPM_params.num_deltas);
            
            save(fullfile(matches_folder,'times'),'times')
            
            tic;matches = [(1:N.n)' RPFM(M,N,FSPM_params,matches_sparse)];
            
            dlmwrite(fullfile(dense_match_folder,[name '.csv']),matches);
            times_dense(fi)=toc
            save(fullfile(matches_folder,'times_dense'),'times_dense')
            
        end
    end
end
