function varargout = process_rejecttrials( varargin )
% PROCESS_REJECTTRIALS: ACCEPT/REJECT TRIALS AFTER BAD CHANNEL REJECTION.

% @=============================================================================
% This function is part of the CPLtoolkit:
% 
% 
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% AUTHOR DOES NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% =============================================================================@
%
% Authors: Paul Kieffaber, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Reject Bad Trials';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = {'CPL','Artifacts'};
    sProcess.Index       = 116;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/MedianNerveCtf#Review_the_individual_trials';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data'};
    sProcess.OutputTypes = {'data'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    
    % Warning
    sProcess.options.warning.Comment = ['<B>Warning</B>: We do not recommend using this process for<BR>' ...
                                        'automatic detection of bad channels/trials. It is based only<BR>' ...
                                        'on the maximum of the signals, which is not representative<BR>' ...
                                        'of the data quality. For accurate bad segment identification,<BR>' ...
                                        'the only reliable option is the manual inspection of the data.<BR><BR>'];
    sProcess.options.warning.Type    = 'label';
    sProcess.options.sep1.Type    = 'separator';
    % Number of bad channels option
    sProcess.options.nbadchan.Comment = 'Maximum Number of Bad Channels:';
    sProcess.options.nbadchan.Type    = 'value';
    sProcess.options.nbadchan.Value   = {[],'#',0};
    % Explanations
end

%% ===== PREPARE STRINGS =====
function s = str_pad(s)
    padsize = 12;
    if (length(s) < padsize)
        s = [repmat('&nbsp;', 1, padsize - length(s)), s];
    end
    s = ['<FONT FACE="monospace">' s '</FONT>'];
end





%% ===== RUN =====
function OutputFiles = Run(sProcess, sInputs) %#ok<DEFNU>
    % ===== GET OPTIONS =====
    % Get options values
    isEmpty = [];
    Criteria.nbadchan = sProcess.options.nbadchan.Value{1}
    isEmpty(end+1) = all(Criteria.nbadchan == 0);
    
    % If no criteria defined: nothing to do
    if isempty(Criteria) || all(isEmpty)
        bst_report('Error', sProcess, [], 'No criteria was defined to detect bad trials.');
        OutputFiles = [];
        return;
    end
    
    % Initializations
    iBadTrials = [];
    progressPos = bst_progress('get');
    prevChannelFile = '';
    
    % ===== LOOP ON FILES =====
    for iFile = 1:length(sInputs)
        % === LOAD ALL DATA ===
        % Progress bar
        bst_progress('set', progressPos + round(iFile / length(sInputs) * 100));
        % Get file in database
        [sStudy, iStudy, iData] = bst_get('DataFile', sInputs(iFile).FileName);
        % Load channel file (if not already loaded
        ChannelFile = sInputs(iFile).ChannelFile;
        if isempty(prevChannelFile) || ~strcmpi(ChannelFile, prevChannelFile)
            prevChannelFile = ChannelFile;
            ChannelMat = in_bst_channel(ChannelFile);
        end
        % Get modalities
        Modalities = unique({ChannelMat.Channel.Type});
        % Load file
        DataMat = in_bst_data(sInputs(iFile).FileName, 'F', 'ChannelFlag', 'History', 'Time');
        % List of bad channels for this file
        iBadChan = [];
        
%         % === LOOP ON MODALITIES ===
%         for iMod = 1:length(Modalities)
%             % === GET REJECTION CRITERIA ===
%             % Get threshold according to the modality
%             if ismember(Modalities{iMod}, {'MEG', 'MEG GRAD'})
%                 Threshold = Criteria.meggrad;
%             elseif strcmpi(Modalities{iMod}, 'MEG MAG')
%                 Threshold = Criteria.megmag;
%             elseif strcmpi(Modalities{iMod}, 'EEG')
%                 Threshold = Criteria.eeg;
%             elseif ismember(Modalities{iMod}, {'SEEG', 'EOCG'})
%                 Threshold = Criteria.ieeg;
%             elseif ~isempty(strfind(lower(Modalities{iMod}), 'eog'))
%                 Threshold = Criteria.eog;
%             elseif ~isempty(strfind(lower(Modalities{iMod}), 'ecg')) || ~isempty(strfind(lower(Modalities{iMod}), 'ekg'))
%                 Threshold = Criteria.ecg;
%             else
%                 continue;
%             end
%             % If threshold is [0 0]: nothing to do
%             if isequal(Threshold, [0 0])
%                 continue;
%             end            
%         end
        
        % === Check Number of Bad Channels ===
        s.ChannelFlag = DataMat.ChannelFlag;
        if sum(s.ChannelFlag == -1)>= Criteria.nbadchan
            % Mark trial as bad
            iBadTrials(end+1) = iFile;
            % Report
            bst_report('Info', sProcess, sInputs(iFile), 'Marked as bad trial.');
            % Update study
            sStudy.Data(iData).BadTrial = 1;
            bst_set('Study', iStudy, sStudy);
        end        
    end
    
    % Record bad trials in study
    if ~isempty(iBadTrials)
        SetTrialStatus({sInputs(iBadTrials).FileName}, 1);
        bst_report('Info', sProcess, sInputs(iFile), sprintf('Epochs tested: %d - Bad epochs: %d (%d%%)', length(sInputs), length(iBadTrials), round(nnz(iBadTrials)/length(sInputs)*100)));
    end
    % Return only good trials
    iGoodTrials = setdiff(1:length(sInputs), iBadTrials);
    OutputFiles = {sInputs(iGoodTrials).FileName};
end


%% ===== SET STUDY BAD TRIALS =====
% USAGE:  SetTrialStatus(FileNames, isBad)
%         SetTrialStatus(FileName, isBad)
%         SetTrialStatus(BstNodes, isBad)
function SetTrialStatus(FileNames, isBad)
    bst_progress('start', 'Set trial status', 'Updating list of bad trials...');
    % ===== PARSE INPUTS =====
    % CALL: SetTrialStatus(FileName, isBad)
    if ischar(FileNames)
        FileNames = {FileNames};
        [tmp__, iStudies, iDatas] = bst_get('DataFile', FileNames{1});
    % CALL: SetTrialStatus(FileNames, isBad)
    elseif iscell(FileNames)
        % Get studies indices
        iStudies = zeros(size(FileNames));
        iDatas   = zeros(size(FileNames));
        for i = 1:length(FileNames)
            [tmp__, iStudies(i), iDatas(i)] = bst_get('DataFile', FileNames{i});
        end
    % CALL: SetTrialStatus(BstNodes, isBad)
    else
        % Get dependent nodes
        [iStudies, iDatas] = tree_dependencies(FileNames, 'data', [], 1);
        % If an error occurred when looking for the for the files in the database
        if isequal(iStudies, -10)
            bst_error('Error in file selection.', 'Set trial status', 0);
            return;
        end
        % Get study
        sStudies = bst_get('Study', iStudies);
        % Get data filenames
        FileNames = cell(size(iStudies));
        for i = 1:length(iStudies)
            FileNames{i} = sStudies(i).Data(iDatas(i)).FileName;
        end
    end
    
    % Get protocol folders
    ProtocolInfo = bst_get('ProtocolInfo');
    % Get unique list of studies
    uniqueStudies = unique(iStudies);
    % Remove path from all files
    for i = 1:length(FileNames)
        [fPath, fBase, fExt] = bst_fileparts(FileNames{i});
        FileNames{i} = [fBase, fExt];
    end
    
    % ===== CHANGE TRIALS STATUS =====
    % Update each the study
    for i = 1:length(uniqueStudies)
        % === CHANGE STATUS IN DATABASE ===
        % Get files for this study
        iStudy = uniqueStudies(i);
        iFiles = find(iStudy == iStudies);
        % Get study
        sStudy = bst_get('Study', iStudy);
        % Mark trial as bad
        [sStudy.Data(iDatas(iFiles)).BadTrial] = deal(isBad);
        % Update database
        bst_set('Study', iStudy, sStudy);
        
        % === CHANGE NODES STATUS ===
        for iFile = 1:length(iFiles)
            % Get node
            bstNode = panel_protocols('GetNode', [], 'data', iStudy, iDatas(iFiles(iFile)));
            % Update node
            if ~isempty(bstNode)
                bstNode.setModifier(isBad);
            end
        end
        
        % === CHANGE STATUS IN STUDY FILE ===
        % Load study file
        StudyFile = bst_fullfile(ProtocolInfo.STUDIES, sStudy.FileName);
        StudyMat = load(StudyFile);
        % Get previous list of bad trials
        if ~isfield(StudyMat, 'BadTrials') || isempty(StudyMat.BadTrials)
            StudyMat.BadTrials = {};
        end
        % Add bad/good trials to current list
        if isBad
            StudyMat.BadTrials = union(StudyMat.BadTrials, FileNames(iFiles));
        else
            StudyMat.BadTrials = setdiff(StudyMat.BadTrials, FileNames(iFiles));
        end
        % Save list of bad trials in the study file
        bst_save(StudyFile, StudyMat, 'v7');
    end
    % Update tree
    %panel_protocols('UpdateNode', 'Study', uniqueStudies);
    panel_protocols('RepaintTree');
    bst_progress('stop');
end




