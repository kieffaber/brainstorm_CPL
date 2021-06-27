function varargout = process_ERSPimage( varargin )
% PROCESS_ERPIMAGE: Generate ERSP image plot sorted by event metadata.
%
% USAGE:              [hFig, iDS, iFig] = process_ERSPimage('Run', sProcess, sInputs)

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
sProcess.Comment     = 'ESRP Image test';
sProcess.Category    = 'Custom';
sProcess.SubGroup    = {'CPL', 'Visualization'};
sProcess.Index       = 302;
sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Averaging#Averaging';
% Definition of the input accepted by this process
%sProcess.InputTypes  = {'data', 'results', 'timefreq', 'matrix'};
sProcess.InputTypes  = {'timefreq'};
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
% === IS FREQ BANDS
sProcess.options.isfreqbands.Comment = 'Group by frequency bands (name/freqs/function):';
sProcess.options.isfreqbands.Type    = 'checkbox';
sProcess.options.isfreqbands.Value   = 1;
% === FREQ BANDS
sProcess.options.freqbands.Comment = '';
sProcess.options.freqbands.Type    = 'groupbands';
sProcess.options.freqbands.Value   = bst_get('DefaultFreqBands');
sProcess.options.direction.Comment = {'Ascending', 'Descending', 'Sort Direction'};
sProcess.options.direction.Type    = 'radio_line';
sProcess.options.direction.Value   = 1;
% === PLOT OPTIONS
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
function [sMat] = Run(sProcess, sInputs)
% Get Metadata to import
MetaFile  = sProcess.options.evtfile.Value{1};
MetaFileFormat = sProcess.options.evtfile.Value{2};
FreqBands=sProcess.options.freqbands.Value;
addCurve=sProcess.options.curve.Value;
if isempty(MetaFile)
    bst_report('Error', sProcess, [], 'Event file not selected.');
    return
end
% Import the Metadata file
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
        bst_report('Error', sProcess, [], 'You must select a sorting direction');
        return;
end

%Will want to add functionality for PSD and Hilbert eventually
% Check type of input files
%if ~isempty(strfind(sInputs(1).FileName, 'timefreq_pac')) || ~isempty(strfind(sInputs(1).FileName, 'timefreq_dpac'))
%    bst_report('Error', sProcess, [], ['Cannot average PAC maps after their computation.' 10 'Please use the process option "Save average PAC across trials" instead.']);
%    return;
%end
% Sort the input files
[DataFiles, SortVals] = SortFiles(sInputs, T, SortVals, direction);

%Make ERSP file
[sMat]=MakeERSPimage(DataFiles,FreqBands,sProcess,sInputs,addCurve, SortVals);

end


%% ===== SORT FILES =====
function [DataFiles, sortVals, iStudy] = SortFiles(sInputs, T, SortVals, direction)
DataFiles={sInputs.FileName};
sortMtx=cat(2,[1:length(DataFiles)]',SortVals);
sortMtx=sortrows(sortMtx,2,direction);
sortVals=sortMtx(:,2);
DataFiles=DataFiles(sortMtx(:,1));
iStudy=sInputs(1).iStudy;
end

%% ====== MAKE TEMP FILES ======
function [sMat]=MakeERSPimage(DataFiles,FreqBands,sProcess,sInputs, addCurve, SortVals)

%first need to check for consistency across TF files
for band=1:size(FreqBands,1) %loop over designated frequency bands
    bandlabel=FreqBands{band,1};
    FakeTF=[];
    for file=1:length(DataFiles) %loop over input files (in sorted order)
        SubData=in_bst(DataFiles{file});
        freqs=str2num(FreqBands{band,2});
        % Find designated frequencies
        if length(freqs)==1 % if only one frequency given
            f=find(abs(SubData.Freqs-freqs)==min(abs(SubData.Freqs-freqs)));
        elseif length(freqs)==2 % if two frequencies given
            f(1)=find(abs(SubData.Freqs-freqs(1))==min(abs(SubData.Freqs-freqs(1))));
            f(2)=find(abs(SubData.Freqs-freqs(2))==min(abs(SubData.Freqs-freqs(2))));
        else
            bst_report('Error', sProcess, [], 'You must designate either one or two frequencies');
            return;
        end
        if length(f)>1
            try
                FakeTF(:,:,file)=squeeze(mean(SubData.TF(:,:,f(1):f(2)),3));
            catch
                bst_report('Error', sProcess, [], 'Files have different number of channels...interpolate bad channels or unreject bad');
            end
        else
            try
                FakeTF(:,:,file)=squeeze(SubData.TF(:,:,f));
            catch
                bst_report('Error', sProcess, [], 'Files have different number of channels...interpolate bad channels or unreject bad');
            end
        end
    end
    
    
    % Get output structure
    [sStudy, iStudy, Comment, uniqueDataFile] = bst_process('GetOutputStudy', sProcess, sInputs);
    
    % Initialize output data file
    SubData=in_bst(DataFiles{1});
    % create new file based on timefreq template
    sMat = db_template('timefreq');
    % Fill the required fields of the structure
    sMat.TF             = FakeTF;
    sMat.Description    = {'Data for ERSP image'};
    sMat.Time           = SubData.Time;
    sMat.Freqs          =1:length(DataFiles);
    sMat.Measure        ='power';
    sMat.Method         ='morlet';
    sMat.RowNames       =SubData.RowNames;
    sMat.DataType       ='data';
    sMat.Comment        = ['ERSPimage_' bandlabel];
    
    % === SAVE FILE ===
    % Output filename
    if strcmpi(sInputs(1).FileType, 'data')
        allFiles = {};
        for i = 1:length(sInputs)
            [tmp, allFiles{end+1}, tmp] = bst_fileparts(sInputs(i).FileName);
        end
        fileTag = str_common_path(allFiles, '_');
    else
        fileTag = bst_process('GetFileTag', sInputs(1).FileName);
    end
    OutputFile = bst_process('GetNewFilename', bst_fileparts(sStudy.FileName), [fileTag, '_ERSP']);
    % Save on disk
    bst_save(OutputFile, sMat, 'v6');
    % Register in database
    db_add_data(iStudy, OutputFile, sMat);
    % Add curve (if requested)
    if addCurve
        [hFig, iDS, iFig] = view_timefreq(OutputFile, 'singlesensor', 'FZ', 1);
        %Check if if sorting values <> times (in case sortVals are in ms units?)
        if any(SortVals>max(sMat.Time)) || any(SortVals<min(sMat.Time))
            SortVals=SortVals./1000;
        end
        %xVec=[];
        %for i=1:length(SortVals)
        %    xVec=cat(2,xVec,find(abs(sMat.Time-SortVals(i))==min(abs(sMat.Time-SortVals(i)))));
        %end
        kids=get(hFig,'children');
        hold(kids(3),'on');
        set(kids(3),'Ydir','normal')
        plot3(kids(3),SortVals,1.5:1:length(sInputs)+.5,ones(length(sInputs)),'LineWidth',3,'color','g');
    end
end
db_reload_studies(iStudy);

end