%%% Description: MPM QSM pipeline
% main steps:
% 1) complex-fit over echoes for pdw and t1w images,
%    simple phase difference for mtw images
%    for odd and even echoes done separately
% 2) ROMEO phase unwrapping
% 3) masking based on ROMEO quality map
% 4) rotation to scanner space
% 5) PDF background field removal
% 6) star QSM for dipole inversion as default (optional: non-linear dipole inversion)


%%% Publications:
% Please remember to give credit to the authors of the methods used:
% 1. SEPIA toolbox:
% Chan, K.-S., Marques, J.P., 2021. Neuroimage 227, 117611.
% 2. SPM12 - rigid body registration:
% Friston KJ, et al. Magnetic Resonance in Medicine 35 (1995):346-355
% 3. complex fit of the phase:
% Liu, Tian, et al. MRM 69.2 (2013): 467-476.
% 4. ROMEO phase uwnrapping:
% Dymerska, Barbara, and Eckstein, Korbinian et al. Magnetic Resonance in Medicine (2020).
% 5. PDF background field removal:
% Liu, Tian, et al. NMR in Biomed. 24.9 (2011): 1129-1136.
% 6. starQSM:
% Wei, Hongjiang, et al. NMR in Biomed. 28.10 (2015): 1294-1303.

%%% Inputs:
% romeo_command          : path to romeo phase uwnrapping followed by romeo command, i.e. (in linux) '/your_path/bin/romeo' or (in windows) 'D:\your_path\bin\romeo'
% in_root_dir            : root directory to input nifti files
% out_root_dir           : root directory to output nifti files
% B0                     : magnetic field strength, in Tesla
% dipole_inv             : dipole inversion method, either 'Star-QSM' or 'ndi'
%                          'ndi'      - non-linear dipole inversion
%                                       (also known as iterative Tikhonov),
%                                       may give more contrast than Star-QSM but is less robust to noise
%                          'Star-QSM' - is very robust to noise and quick

%%%% Inputs - directories, parameters and files specific to given contrast
% ATTENTION: ensure only niftis you want to use are in that folder, with increasing echo numbering:
% mag_dir                : % folder with magnitude niftis
% ph_dir                 : % folder with phase inftis
% TEs                    : % echo time in ms
% output_dir             : % output QSM directory for a specific MPM contrast
% calc_mean_qsm          : % 'yes' or 'no' , if 'yes' it calculates mean QSM from all contrasts

%%% Outputs:
%%%% combined final results in out_root_dir:
% QSM_all_mean.nii             : mean QSM over all contrasts in scanner space (3rd dimension is along B0-axis)
% QSM_all_invrot_mean.nii      : mean QSM over all contrasts in image space (as acquired, for comparison with MPM quantitative maps)
% QSM_pdw_t1w_mean.nii         : mean QSM over PDw and T1w contrasts (without noisy MTw) in scanner space
% QSM_pdw_t1w_invrot_mean.nii  : mean QSM over PDw and T1w contrasts in image space

%%%% final results - per contrast in subfolders in out_root_dir:
% sepia_QSM.nii             : QSM in scanner space
% sepia_QSM_invrot.nii      : QSM in image space

%%%% additional outputs:
% ph.nii                    : two volumes (odd and even) of fitted phase
% ph_romeo.nii              : ph.nii unwrapped with ROMEO
% quality.nii               : quality map calculated by ROMEO algorithm and used for masking
% mask.nii                  : binary mask in image space
% mask_rot.nii              : binary mask in scanner space
% B0.nii                    : field map in Hz in image space
% B0_rot.nii                : field map in Hz in scanner space
% sepia_local-field.nii.gz  : map of local field variations (after background field removal using PDF)
% settings_romeo.txt        : settings used for ROMEO unwrapping (useful if unwrapping again outside MPM QSM the pipeline)
% header_sepia.mat          : header used for SEPIA toolbox (useful when exploring SEPIA GUI)

% script created by Barbara Dymerska
% @ UCL FIL Physics

totstart = tic ;

%%%%% USER PARAMETERS %%%%%
para.romeo_command = 'C:\wtcnapps\mritools_Windows_3.6.4\bin\romeo' ;
para.in_root_dir = 'C:\Users\czhang\Documents\DATA' ;
para.out_root_dir =   'C:\Users\czhang\Documents\DATA';

para.B0 = 7;
para.B0_dir = [0;1;0];	% main magnetic field direction after reslicing the data
para.dipole_inv = 'Star-QSM' ;

para.data_cleanup = 'no' ; % 'small' leaves B0 maps and QSMs, 'big' leaves only QSMs 

for run = 2:24
    
    switch run
        case 1 % PDw351_1
            para.mag_dir = '20220505.M700351\pdw_scan1\MPM_pdw\mag_dc.nii' ; % folder with magnitude niftis
            para.ph_dir = '20220505.M700351\pdw_scan1\MPM_pdw\ph_dc.nii' ; % folder with phase inftis
            para.TEs =  [2.2 4.58 6.96 9.34 11.72 14.10] ;  % echo time in ms
            para.output_dir = '20220505.M700351\pdw_scan1\QSM_MPM_pdw_v2' ; % output directory for a specific submeasurement from MPM
            para.mask_thr = 0.2 ; % larger threshold smaller mask
            
        case 2 % T1w351_1
            para.mag_dir = '20220505.M700351\t1w_scan1\MPM_t1w\mag_dc.nii' ; %added .nii to all mag_dc and ph_dc
            para.ph_dir = '20220505.M700351\t1w_scan1\MPM_t1w\ph_dc.nii' ;
            para.TEs = [2.3 4.68 7.06 9.44 11.82 14.20] ;
            para.output_dir = '20220505.M700351\t1w_scan1\QSM_MPM_t1w_v2' ;
            para.mask_thr = 0.2 ; 
            
        case 3 % MTw351_1
            para.mag_dir = '20220505.M700351\mtw_scan1\MPM_mtw\mag_dc.nii' ;
            para.ph_dir = '20220505.M700351\mtw_scan1\MPM_mtw\ph_dc.nii' ;
            para.TEs = [2.2 4.58 6.96 9.34] ; 
            para.output_dir = '20220505.M700351\mtw_scan1\QSM_MPM_mtw_v2' ;
            para.mask_thr = 0.15 ; 
 
        case 4 % PDw351_2
            para.mag_dir = '20220505.M700351\pdw_scan2\MPM_pdw\mag_dc.nii' ; % folder with magnitude niftis
            para.ph_dir = '20220505.M700351\pdw_scan2\MPM_pdw\ph_dc.nii' ; % folder with phase inftis
            para.TEs =  [2.2 4.58 6.96 9.34 11.72 14.10] ;  % echo time in ms
            para.output_dir = '20220505.M700351\pdw_scan2\QSM_MPM_pdw_v2' ; % output directory for a specific submeasurement from MPM
            para.mask_thr = 0.2 ; % larger threshold smaller mask
            
        case 5 % T1w351_2
            para.mag_dir = '20220505.M700351\t1w_scan2\MPM_t1w\mag_dc.nii' ;
            para.ph_dir = '20220505.M700351\t1w_scan2\MPM_t1w\ph_dc.nii' ;
            para.TEs = [2.3 4.68 7.06 9.44 11.82 14.20] ;
            para.output_dir = '20220505.M700351\t1w_scan2\QSM_MPM_t1w_v2' ;
            para.mask_thr = 0.2 ; 
            
        case 6 % MTw351_2
            para.mag_dir = '20220505.M700351\mtw_scan2\MPM_mtw\mag_dc.nii' ;
            para.ph_dir = '20220505.M700351\mtw_scan2\MPM_mtw\ph_dc.nii' ;
            para.TEs = [2.2 4.58 6.96 9.34] ; 
            para.output_dir = '20220505.M700351\mtw_scan2\QSM_MPM_mtw_v2' ;
            para.mask_thr = 0.15 ;
        
        case 7 % PDw198_1
            para.mag_dir = '20210623.M700198\pdw_scan1\MPM_pdw\mag_dc.nii' ; % folder with magnitude niftis
            para.ph_dir = '20210623.M700198\pdw_scan1\MPM_pdw\ph_dc.nii' ; % folder with phase inftis
            para.TEs =  [2.2 4.58 6.96 9.34 11.72 14.10] ;  % echo time in ms
            para.output_dir = '20210623.M700198\pdw_scan1\QSM_MPM_pdw_v2' ; % output directory for a specific submeasurement from MPM
            para.mask_thr = 0.2 ; % larger threshold smaller mask
            
        case 8 % T1w198_1
            para.mag_dir = '20210623.M700198\t1w_scan1\MPM_t1w\mag_dc.nii' ;
            para.ph_dir = '20210623.M700198\t1w_scan1\MPM_t1w\ph_dc.nii' ;
            para.TEs = [2.3 4.68 7.06 9.44 11.82 14.20] ;
            para.output_dir = '20210623.M700198\t1w_scan1\QSM_MPM_t1w_v2' ;
            para.mask_thr = 0.2 ; 
            
        case 9 % MTw198_1
            para.mag_dir = '20210623.M700198\mtw_scan1\MPM_mtw\mag_dc.nii' ;
            para.ph_dir = '20210623.M700198\mtw_scan1\MPM_mtw\ph_dc.nii' ;
            para.TEs = [2.2 4.58 6.96 9.34] ; 
            para.output_dir = '20210623.M700198\mtw_scan1\QSM_MPM_mtw_v2' ;
            para.mask_thr = 0.15 ;
         
        case 10 % PDw198_2
            para.mag_dir = '20210623.M700198\pdw_scan2\MPM_pdw\mag_dc.nii' ; % folder with magnitude niftis
            para.ph_dir = '20210623.M700198\pdw_scan2\MPM_pdw\ph_dc.nii' ; % folder with phase inftis
            para.TEs =  [2.2 4.58 6.96 9.34 11.72 14.10] ;  % echo time in ms
            para.output_dir = '20210623.M700198\pdw_scan2\QSM_MPM_pdw_v2' ; % output directory for a specific submeasurement from MPM
            para.mask_thr = 0.2 ; % larger threshold smaller mask
            
        case 11 % T1w198_2
            para.mag_dir = '20210623.M700198\t1w_scan2\MPM_t1w\mag_dc.nii' ;
            para.ph_dir = '20210623.M700198\t1w_scan2\MPM_t1w\ph_dc.nii' ;
            para.TEs = [2.3 4.68 7.06 9.44 11.82 14.20] ;
            para.output_dir = '20210623.M700198\t1w_scan2\QSM_MPM_t1w_v2' ;
            para.mask_thr = 0.2 ; 
            
        case 12 % MTw198_2
            para.mag_dir = '20210623.M700198\mtw_scan2\MPM_mtw\mag_dc.nii' ;
            para.ph_dir = '20210623.M700198\mtw_scan2\MPM_mtw\ph_dc.nii' ;
            para.TEs = [2.2 4.58 6.96 9.34] ; 
            para.output_dir = '20210623.M700198\mtw_scan2\QSM_MPM_mtw_v2' ;
            para.mask_thr = 0.15 ;
        
        case 13 % PDw350_1
            para.mag_dir = '20220504.M700350\pdw_scan1\MPM_pdw\mag_dc.nii' ; % folder with magnitude niftis
            para.ph_dir = '20220504.M700350\pdw_scan1\MPM_pdw\ph_dc.nii' ; % folder with phase inftis
            para.TEs =  [2.2 4.58 6.96 9.34 11.72 14.10] ;  % echo time in ms
            para.output_dir = '20220504.M700350\pdw_scan1\QSM_MPM_pdw_v2' ; % output directory for a specific submeasurement from MPM
            para.mask_thr = 0.2 ; % larger threshold smaller mask
            
        case 14 % T1w350_1
            para.mag_dir = '20220504.M700350\t1w_scan1\MPM_t1w\mag_dc.nii' ;
            para.ph_dir = '20220504.M700350\t1w_scan1\MPM_t1w\ph_dc.nii' ;
            para.TEs = [2.3 4.68 7.06 9.44 11.82 14.20] ;
            para.output_dir = '20220504.M700350\t1w_scan1\QSM_MPM_t1w_v2' ;
            para.mask_thr = 0.2 ; 
            
        case 15 % MTw350_1
            para.mag_dir = '20220504.M700350\mtw_scan1\MPM_mtw\mag_dc.nii' ;
            para.ph_dir = '20220504.M700350\mtw_scan1\MPM_mtw\ph_dc.nii' ;
            para.TEs = [2.2 4.58 6.96 9.34] ; 
            para.output_dir = '20220504.M700350\mtw_scan1\QSM_MPM_mtw_v2' ;
            para.mask_thr = 0.15 ;
                    
        case 16 % PDw350_2
            para.mag_dir = '20220504.M700350\pdw_scan2\MPM_pdw\mag_dc.nii' ; % folder with magnitude niftis
            para.ph_dir = '20220504.M700350\pdw_scan2\MPM_pdw\ph_dc.nii' ; % folder with phase inftis
            para.TEs =  [2.2 4.58 6.96 9.34 11.72 14.10] ;  % echo time in ms
            para.output_dir = '20220504.M700350\pdw_scan2\QSM_MPM_pdw_v2' ; % output directory for a specific submeasurement from MPM
            para.mask_thr = 0.2 ; % larger threshold smaller mask
            
        case 17 % T1w350_2
            para.mag_dir = '20220504.M700350\t1w_scan2\MPM_t1w\mag_dc.nii' ;
            para.ph_dir = '20220504.M700350\t1w_scan2\MPM_t1w\ph_dc.nii' ;
            para.TEs = [2.3 4.68 7.06 9.44 11.82 14.20] ;
            para.output_dir = '20220504.M700350\t1w_scan2\QSM_MPM_t1w_v2' ;
            para.mask_thr = 0.2 ; 
            
        case 18 % MTw350_2
            para.mag_dir = '20220504.M700350\mtw_scan2\MPM_mtw\mag_dc.nii' ;
            para.ph_dir = '20220504.M700350\mtw_scan2\MPM_mtw\ph_dc.nii' ;
            para.TEs = [2.2 4.58 6.96 9.34] ; 
            para.output_dir = '20220504.M700350\mtw_scan2\QSM_MPM_mtw_v2' ;
            para.mask_thr = 0.15 ;
                    
        case 19 % PDw213_1
            para.mag_dir = '20221114.M700213\pdw_scan1\MPM_pdw\mag_dc.nii' ; % folder with magnitude niftis
            para.ph_dir = '20221114.M700213\pdw_scan1\MPM_pdw\ph_dc.nii' ; % folder with phase inftis
            para.TEs =  [2.2 4.58 6.96 9.34 11.72 14.10] ;  % echo time in ms
            para.output_dir = '20221114.M700213\pdw_scan1\QSM_MPM_pdw_v2' ; % output directory for a specific submeasurement from MPM
            para.mask_thr = 0.2 ; % larger threshold smaller mask
            
        case 20 % T1w213_1
            para.mag_dir = '20221114.M700213\t1w_scan1\MPM_t1w\mag_dc.nii' ;
            para.ph_dir = '20221114.M700213\t1w_scan1\MPM_t1w\ph_dc.nii' ;
            para.TEs = [2.3 4.68 7.06 9.44 11.82 14.20] ;
            para.output_dir = '20221114.M700213\t1w_scan1\QSM_MPM_t1w_v2' ;
            para.mask_thr = 0.2 ; 
            
        case 21 % MTw213_1
            para.mag_dir = '20221114.M700213\mtw_scan1\MPM_mtw\mag_dc.nii' ;
            para.ph_dir = '20221114.M700213\mtw_scan1\MPM_mtw\ph_dc.nii' ;
            para.TEs = [2.2 4.58 6.96 9.34] ; 
            para.output_dir = '20221114.M700213\mtw_scan1\QSM_MPM_mtw_v2' ;
            para.mask_thr = 0.15 ;
                    
        case 22 % PDw213_2
            para.mag_dir = '20221114.M700213\pdw_scan2\MPM_pdw\mag_dc.nii' ; % folder with magnitude niftis
            para.ph_dir = '20221114.M700213\pdw_scan2\MPM_pdw\ph_dc.nii' ; % folder with phase inftis
            para.TEs =  [2.2 4.58 6.96 9.34 11.72 14.10] ;  % echo time in ms
            para.output_dir = '20221114.M700213\pdw_scan2\QSM_MPM_pdw_v2' ; % output directory for a specific submeasurement from MPM
            para.mask_thr = 0.2 ; % larger threshold smaller mask
            
        case 23 % T1w213_2
            para.mag_dir = '20221114.M700213\t1w_scan2\MPM_t1w\mag_dc.nii' ;
            para.ph_dir = '20221114.M700213\t1w_scan2\MPM_t1w\ph_dc.nii' ;
            para.TEs = [2.3 4.68 7.06 9.44 11.82 14.20] ;
            para.output_dir = '20221114.M700213\t1w_scan2\QSM_MPM_t1w_v2' ;
            para.mask_thr = 0.2 ; 
            
        case 24 % MTw213_2
            para.mag_dir = '20221114.M700213\mtw_scan2\MPM_mtw\mag_dc.nii' ;
            para.ph_dir = '20221114.M700213\mtw_scan2\MPM_mtw\ph_dc.nii' ;
            para.TEs = [2.2 4.58 6.96 9.34] ; 
            para.output_dir = '20221114.M700213\mtw_scan2\QSM_MPM_mtw_v2' ;
            para.mask_thr = 0.15 ;
 
    end
    %%%%% END OF USER PARAMETERS %%%%%
    
MPM_QSM_4d(para) ;
    
end

sprintf('total processing finished after %s' , secs2hms(toc(totstart)))
clear
