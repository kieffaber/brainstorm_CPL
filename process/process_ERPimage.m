function varargout = process_ERPimage( varargin )
% PROCESS_ERPIMAGE: Generate ERP image plot sorted by event metadata.
%
% USAGE:              [hFig, iDS, iFig] = process_ERPimage('Run', sProcess, sInputs)

% @=============================================================================
% This function is part of the CPL Toolbox written for Brainstorm software:
%
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
%
% THIS SOFTWARE IS PROVIDED "AS IS," AND THE AUTHORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% =============================================================================@
%
% Authors: Paul Kieffaber 2021
%  - modified from process_average.m & view_image of the Brainstorm software

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
% Description the process
sProcess.Comment     = 'ERP Image';
sProcess.Category    = 'Custom';
sProcess.SubGroup    = {'CPL', 'Visualization'};
sProcess.Index       = 302;
sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Averaging#Averaging';
% Definition of the input accepted by this process
%sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
sProcess.InputTypes  = {'data'};
sProcess.OutputTypes = {'data', 'results', 'timefreq', 'matrix'};
sProcess.nInputs     = 1;
sProcess.nMinFiles   = 2;
sProcess.isSeparator = 1;
SelectOptions = {...
    '', ...                               % Filename
    '', ...                               % FileFormat
    'open', ...                           % Dialog type: {open,save}
    'Select Sorting Values...', ...       % Window title
    'ImportData', ...                     % LastUsedDir: {ImportData,ImportChannel,ImportAnat,ExportChannel,ExportData,ExportAnat,ExportProtocol,ExportImage,ExportScript}
    'single', ...                         % Selection mode: {single,multiple}
    'files', ...                          % Selection mode: {files,dirs,files_and_dirs}
    {{'.csv'},{'Comma separated values'},{'CSV'}}, ... % Limit to csv file format
    'EventsIn'};                          % DefaultFormats: {ChannelIn,DataIn,DipolesIn,EventsIn,MriIn,NoiseCovIn,ResultsIn,SspIn,SurfaceIn,TimefreqIn
% Option: Event file
sProcess.options.evtfile.Comment = 'Select Metadata file (.csv):';
sProcess.options.evtfile.Type    = 'filename';
sProcess.options.evtfile.Value   = SelectOptions;
sProcess.options.tag.Comment = 'Enter Metadata Tag:';
sProcess.options.tag.Type    = 'text';
sProcess.options.tag.Value   = '';
sProcess.options.direction.Comment = {'Ascending', 'Descending', 'Sort Direction'};
sProcess.options.direction.Type    = 'radio_line';
sProcess.options.direction.Value   = 1;
sProcess.options.label1.Comment = '<U><B>Plot Options</B></U>:';
sProcess.options.label1.Type    = 'label';
sProcess.options.curve.Comment    = 'Add Curve Line';
sProcess.options.curve.Type       = 'checkbox';
sProcess.options.curve.Value      = 0;
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess)

end


%% ===== RUN =====
function [hFig, iDS, iFig, sMat] = Run(sProcess, sInputs)
% Get filenames to import
MetaFile  = sProcess.options.evtfile.Value{1};
MetaFileFormat = sProcess.options.evtfile.Value{2};
addCurve=sProcess.options.curve.Value;
if isempty(MetaFile)
    bst_report('Error', sProcess, [], 'Event file not selected.');
    return
end
% Import the Meta file
T=readtable(MetaFile,'Delimiter',',','ReadVariableNames',1);

% Get the sorting column name
sortCol = sProcess.options.tag.Value;
% Pull out selected sorting values and remove NaNs (blank cells)
eval(['SortVals=double(T.' sortCol ');']);
SortVals=SortVals(~isnan(SortVals));
% Check that length(sort values) == length(sInputs.FileName)
if length(SortVals) ~= length({sInputs.FileName})
    bst_report('Error', sProcess, [], ['Number of sorting values (' num2str(length(SortVals)) ') does not match the number of input files (' num2str(length({sInputs.FileName})) ').']);
    return;
end
% Get sorting direction
switch sProcess.options.direction.Value
    case 1
        direction = 'ascend';
    case 2
        direction = 'descend';
    otherwise
        bst_report('Error', sProcess, [], 'No sorting direction specified.');
        return;
end

% Sort the input files
[DataFiles, SortVals, iStudy] = SortFiles(sInputs, T, SortVals, direction);

%Make ERSP file
[sMat]=MakeERPimage(DataFiles,sProcess,sInputs);

%Make Figure
[hFig, iDS, iFig] = view_erpimage( DataFiles, 'erpimage', 'EEG');


% Add curve (if requested)
if addCurve
    [sMat, matName] = in_bst(sInputs(1).FileName);
    %Check if values <> times (in case sortVals are in ms units
    if any(SortVals>max(sMat.Time)) || any(SortVals<min(sMat.Time))
        SortVals=SortVals./1000;
    end
    xVec=[];
    for i=1:length(SortVals)
        xVec=cat(2,xVec,find(abs(sMat.Time-SortVals(i))==min(abs(sMat.Time-SortVals(i)))));
    end
    kids=get(hFig,'children');
    hold(kids(3),'on');
    set(kids(3),'Ydir','normal')
    plot3(kids(3),xVec,1.5:1:length(sInputs)+.5,ones(length(sInputs)),'LineWidth',3,'color','k');
end
end


%% ===== SORT FILES =====
function [DataFiles, SortVals, iStudy] = SortFiles(sInputs, T, SortVals, direction)
DataFiles={sInputs.FileName};
sortMtx=cat(2,[1:length(DataFiles)]',SortVals);
sortMtx=sortrows(sortMtx,2,direction);
SortVals=sortMtx(:,2);
DataFiles=DataFiles(sortMtx(:,1));
iStudy=sInputs(1).iStudy;
end

%% ====== MAKE TEMP FILES ======
function [sMat]=MakeERPimage(DataFiles,sProcess,sInputs)
    ERSPdata=[];
    for file=1:length(DataFiles) %loop over input files (in sorted order)
        SubData=in_bst(DataFiles{file});
        ERSPdata=cat(3,ERSPdata,SubData.F);
    end
    
% Initialize an empty "matrix" structure
sMat = db_template('matrix');
% Fill the required fields of the structure
sMat.Value       = ERSPdata;
sMat.Comment     = 'ERPimage_data';
sMat.Description = {'Data for ERP image'};
sMat.Time        = SubData.Time;

%OutputFile = db_add(iStudy, sMat);
%TempDataFiles=cat(1,TempDataFiles,OutputFile);
    % Get output structure
    [sStudy, iStudy, Comment, uniqueDataFile] = bst_process('GetOutputStudy', sProcess, sInputs);

% Get the full path to the new folder
% (same folder as the brainstormstudy.mat file for this study)
OutputFolder = bst_fileparts(file_fullpath(sStudy.FileName));
% Get a new unique filename (including a timestamp)
MatrixFile = bst_process('GetNewFilename', OutputFolder, 'matrix');
%sMat.DataFile=MatrixFile;
% Save file
bst_save(MatrixFile, sMat, 'v6', 0);
%bst_add_data(iStudy, thisfile, SubData);
%TempDataFiles=cat(1,TempDataFiles,thisfile)

db_reload_studies(iStudy);
end