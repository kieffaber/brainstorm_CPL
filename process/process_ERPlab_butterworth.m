function varargout = process_ERPlab_basicfilter( varargin )
% PROCESS_BUTTERWORTH: Frequency filters: Lowpass/Highpass/Bandpass
%
% USAGE:                sProcess = process_butterworth('GetDescription')
%                         sInput = process_butterworth('Run', sProcess, sInput, method=[])
%        [x, FiltSpec, Messages] = process_butterworth('Compute', x, sfreq, HighPass, LowPass, Method=[], isMirror=0, isRelax=0, TranBand=[])
%                              x = process_butterworth('Compute', x, sfreq, FiltSpec)

% @=============================================================================
% This function is NOT part of the Brainstorm software:
% 
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% THIS SOFTWARE IS PROVIDED "AS IS," AND WITHOUT ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DOES THE AUTHOR ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% =============================================================================@
%
% 
% Paul Kieffaber (2020) MODIFIED FROM PROCESS_BANDPASS.M OF THE BRAINSTORM
% SOFTWARE

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'Butterworth filter';
    sProcess.FileTag     = @GetFileTag;
    sProcess.Category    = 'Filter';
    sProcess.SubGroup    = {'CPL','Filters'};
    sProcess.Index       = 64;
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'data', 'results', 'raw', 'matrix'};
    sProcess.OutputTypes = {'data', 'results', 'raw', 'matrix'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.processDim  = 1;   % Process channel by channel
    sProcess.Description = 'none';
    % Definition of the options
    % === Sensor types
    sProcess.options.sensortypes.Comment = 'Sensor types or names (empty=all): ';
    sProcess.options.sensortypes.Type    = 'text';
    sProcess.options.sensortypes.Value   = 'MEG, EEG';
    sProcess.options.sensortypes.InputTypes = {'data', 'raw'};
    % ==== Parameters 
    sProcess.options.label1.Comment = '<BR><U><B>Filtering parameters</B></U>:';
    sProcess.options.label1.Type    = 'label';
    % === Low bound
    sProcess.options.highpass.Comment = 'Lower cutoff frequency (0=disable):';
    sProcess.options.highpass.Type    = 'value';
    sProcess.options.highpass.Value   = {0,'Hz ',3};
    % === High bound
    sProcess.options.lowpass.Comment = 'Upper cutoff frequency (0=disable):';
    sProcess.options.lowpass.Type    = 'value';
    sProcess.options.lowpass.Value   = {40,'Hz ',3};
    % === Relax
    sProcess.options.attenuation.Comment = {'12dB/oct', '24dB/oct', '36dB/oct', '48db/oct', 'Stopband attenuation:'; ...
                                            'relaxed', 'default', 'strict', 'very strict',''};
    sProcess.options.attenuation.Type    = 'radio_linelabel';
    sProcess.options.attenuation.Value   = 'default';
    % === Display properties
    %sProcess.options.display.Comment = {'process_bandpass(''DisplaySpec'',iProcess,sfreq);', '<BR>', 'View filter response'};
    %sProcess.options.display.Type    = 'button';
    %sProcess.options.display.Value   = [];
end


%% ===== GET OPTIONS =====
function [HighPass, LowPass, Order] = GetOptions(sProcess)
    HighPass = sProcess.options.highpass.Value{1};
    LowPass  = sProcess.options.lowpass.Value{1};
    if isempty(HighPass) 
        HighPass = 0;
    end
    if isempty(LowPass) 
        LowPass = 0;
    end
    switch (sProcess.options.attenuation.Value)
        case 'relaxed'
            Order=2;
        case 'default'
            Order=4;
        case 'strict'
            Order=6;
        case 'very strict'
            Order=8;
        otherwise
            warning('Something is wrong with order selection, using 24db/oct');
            Order=4;
    end
end


%% ===== FORMAT COMMENT =====
function [Comment, fileTag] = FormatComment(sProcess)
    % Get options
    [HighPass, LowPass] = GetOptions(sProcess);
    % Format comment
    if ~isempty(HighPass) && ~isempty(LowPass)
        Comment = ['Band-pass ERPlab Butter:' num2str(HighPass) 'Hz-' num2str(LowPass) 'Hz'];
        fileTag = 'band';
    elseif ~isempty(HighPass)
        Comment = ['High-pass ERPlab Butter:' num2str(HighPass) 'Hz'];
        fileTag = 'high';
    elseif ~isempty(LowPass)
        Comment = ['Low-pass ERPlab Butter:' num2str(LowPass) 'Hz'];
        fileTag = 'low';
    else
        Comment = '';
    end
end


%% ===== GET FILE TAG =====
function fileTag = GetFileTag(sProcess)
    [Comment, fileTag] = FormatComment(sProcess);
end


%% ===== RUN =====
function sInput = Run(sProcess, sInput) %#ok<DEFNU>
    % Get options
    [HighPass, LowPass, Order] = GetOptions(sProcess);
    % Filter signals
    sfreq = 1 ./ (sInput.TimeVector(2) - sInput.TimeVector(1));
    [sInput.A, FiltSpec, Messages] = Compute(sInput.A, sfreq, HighPass, LowPass, Order);
    
    % Process warnings
    if ~isempty(Messages)
        bst_report('Warning', sProcess, sInput, Messages);
    end
    % File comment
    if ~isempty(HighPass) && ~isempty(LowPass)
        filterComment = ['bandButter(' num2str(HighPass) '-' num2str(LowPass) 'Hz)'];
    elseif ~isempty(HighPass)
        filterComment = ['highButter(' num2str(HighPass) 'Hz)'];
    elseif ~isempty(LowPass)
        filterComment = ['lowButter(', num2str(LowPass) 'Hz)'];
    else
        filterComment = '';
    end
    sInput.CommentTag = filterComment;
    % Do not keep the Std field in the output
    if isfield(sInput, 'Std') && ~isempty(sInput.Std)
        sInput.Std = [];
    end
end


%% ===== EXTERNAL CALL =====
% USAGE: [x, FiltSpec, Messages] = process_bandpass('Compute', x, sfreq, HighPass, LowPass, Method=[], isMirror=0, isRelax=0, TranBand=0.05)
%                              x = process_bandpass('Compute', x, sfreq, FiltSpec)             
function [x, FiltSpec, Messages] = Compute(x, sfreq, HighPass, LowPass, Order)
    FiltSpec='ERPlab IIR Butterworth';
% Filter is already computed
    if (nargin == 3)
        warning('Default options selected');
        FiltSpec = HighPass;
        Order=4;
    % Default filter options
    end
    Messages = [];
    if HighPass>0 && LowPass>0
        ftype='bandpass';
    elseif HighPass>0
        ftype='highpass';
    elseif LowPass>0
        ftype='lowpass';
    else
        warning('something is wrong');
    end
    EEG = pop_importdata('dataformat','array','nbchan',size(x,1),'data',x,'srate',sfreq,'pnts',size(x,2),'xmin',0);
    chanarray=[1:size(x,1)];%filter all channels
    fdesign='butter';
    cutoff=[HighPass LowPass];
    filterorder=Order;
    rdc='on';
    boundary='boundary';
    EEG  = pop_basicfilter( EEG,  chanarray , 'Boundary', 'boundary', 'Cutoff', cutoff, 'Design', 'butter', 'Filter', 'bandpass', 'Order',  Order );
    x=EEG.data;
end


%% ===== DISPLAY FILTER SPECS =====
function DisplaySpec(iProcess, sfreq) %#ok<DEFNU>
    % Get current process options
    global GlobalData;
    sProcess = GlobalData.Processes.Current(iProcess);

    % Get options
    [HighPass, LowPass, isMirror, isRelax, Method, TranBand] = GetOptions(sProcess);    
    % Compute filter specification
    if strcmpi(Method, 'bst-hfilter-2019') || strcmpi(Method, 'bst-hfilter-2016')
        [tmp, FiltSpec, Messages] = bst_bandpass_hfilter([], sfreq, HighPass, LowPass, isMirror, isRelax, [], TranBand, Method);
        if isempty(FiltSpec)
            bst_error(Messages, 'Filter response', 0);
        end
    else
        bst_error('The filter response cannot be displayed for this method.', 'Filter response', 0);
        return;
    end
    
    % Compute filter response
    if bst_get('UseSigProcToolbox')
        [Hf,Freqs] = freqz(FiltSpec.b, FiltSpec.a, 2^14, sfreq);
        [Ht,t] = impz(FiltSpec.b, FiltSpec.a, [], sfreq);
    else
        [Hf,Freqs] = oc_freqz(FiltSpec.b, FiltSpec.a, 2^14, sfreq);
        [Ht,t] = oc_impz(FiltSpec.b, FiltSpec.a, [], sfreq);
    end
    t = t - t(round(length(t)/2));

    
    % Configure 
    dF = Freqs(2) - Freqs(1);
    if isempty(LowPass) || (LowPass == 0)
        XFreqLim = [0, min(3*max(dF,HighPass), max(Freqs))] ;
    else
        XFreqLim = [0, min(max(5*LowPass, sfreq/8), max(Freqs))] ; 
    end

    % Filter description: Left panel
    strFilter1 = ['<HTML>Linear phase <B>FIR filter</B>' '<BR>'];
    if ~isempty(HighPass) && (HighPass > 0) && ~isempty(LowPass) && (LowPass > 0)
        strFilter1 = [strFilter1 'Band-pass: &nbsp;&nbsp;<B>' num2str(HighPass) '-' num2str(LowPass) ' Hz</B><BR>'];
        strFilter1 = [strFilter1 'Low transition: &nbsp;&nbsp;<B>' num2str(FiltSpec.fcuts(1)) '-' num2str(FiltSpec.fcuts(2)) ' Hz</B><BR>'];
        strFilter1 = [strFilter1 'High transition: &nbsp;&nbsp;<B>' num2str(FiltSpec.fcuts(3)) '-' num2str(FiltSpec.fcuts(4)) ' Hz</B><BR>'];
    elseif ~isempty(HighPass) && (HighPass > 0)
        strFilter1 = [strFilter1 'High-pass: &nbsp;&nbsp;<B>' num2str(HighPass) ' Hz</B><BR>'];
        strFilter1 = [strFilter1 'Transition: &nbsp;&nbsp;<B>' num2str(FiltSpec.fcuts(1)) '-' num2str(FiltSpec.fcuts(2)) ' Hz</B><BR>'];
    elseif ~isempty(LowPass) && (LowPass > 0)
        strFilter1 = [strFilter1 'Low-pass: &nbsp;&nbsp;<B>' num2str(LowPass) ' Hz</B><BR>'];
        strFilter1 = [strFilter1 'Transition: &nbsp;&nbsp;<B>' num2str(FiltSpec.fcuts(1)) '-' num2str(FiltSpec.fcuts(2)) ' Hz</B><BR>'];
    end
    if isRelax
        strFilter1 = [strFilter1 'Stopband attenuation: &nbsp;&nbsp;<B>40 dB</B><BR>'];
        strFilter1 = [strFilter1 'Passband ripple: &nbsp;&nbsp;<B>1%</B><BR>'] ; 
    else
        strFilter1 = [strFilter1 'Stopband attenuation: &nbsp;&nbsp;<B>60 dB</B><BR>'];
        strFilter1 = [strFilter1 'Passband ripple: &nbsp;&nbsp;<B>0.1%</B><BR>'] ; 
    end

    % Filter description: Right panel
    strFilter2 = '<HTML>';
    strFilter2 = [strFilter2 'Filter type: &nbsp;&nbsp;<B> Kaiser </B><BR>'];
    strFilter2 = [strFilter2 'Filter order: &nbsp;&nbsp;<B>' num2str(FiltSpec.order) '</B><BR>'];
    strFilter2 = [strFilter2 'Transient (full): &nbsp;&nbsp;<B>' num2str(FiltSpec.order / 2 / sfreq, '%1.3f') ' s</B><BR>'];
    strFilter2 = [strFilter2 'Transient (99% energy): &nbsp;&nbsp;<B>' num2str(FiltSpec.transient, '%1.3f') ' s</B><BR>'];
    strFilter2 = [strFilter2 'Sampling frequency: &nbsp;&nbsp;<B>', num2str(sfreq), ' Hz</B><BR>'];
    strFilter2 = [strFilter2 'Frequency resolution: &nbsp;&nbsp;<B>' num2str(dF, '%1.3f') ' Hz</B><BR>'];
    
    hFig = HFilterDisplay(Hf,Freqs,Ht,t,FiltSpec.transient,strFilter1,strFilter2,XFreqLim) ; 

end

function hFig = HFilterDisplay(Hf,Freqs,Ht,t,transient,strFilter1,strFilter2,XFreqLim)

% Progress bar
bst_progress('start', 'Filter specifications', 'Updating graphs...');

% Get existing specification figure
hFig = findobj(0, 'Type', 'Figure', 'Tag', 'FilterSpecs');
% If the figure doesn't exist yet: create it
if isempty(hFig)
    hFig = figure(...
        'MenuBar',     'none', ...
        ... 'Toolbar',     'none', ...
        'Toolbar',     'figure', ...
        'NumberTitle', 'off', ...
        'Name',        sprintf('Filter properties'), ...
        'Tag',         'FilterSpecs', ...
        'Units',       'Pixels');
    % Figure already exists: re-use it
else
    clf(hFig);
    figure(hFig);
end
% Disable the Java-related warnings after 2019b
if (bst_get('MatlabVersion') >= 907)
    warning('off', 'MATLAB:ui:javacomponent:FunctionToBeRemoved');
end

% Plot frequency response
hAxesFreqz = axes('Units', 'pixels', 'Parent', hFig, 'Tag', 'AxesFreqz');
Hf = 20.*log10(abs(Hf));
plot(hAxesFreqz, Freqs, Hf);
% Plot impulse response
hAxesImpz = axes('Units', 'pixels', 'Parent', hFig, 'Tag', 'AxesImpz');
plot(hAxesImpz, t, Ht);

% Add Axes limits
set(hAxesFreqz, 'XLim', XFreqLim);
set(hAxesFreqz, 'YLim', [min(Hf), max(Hf)] + (max(Hf)-min(Hf)) .* [-0.05,0.05]);
YLimImpz = [min(Ht), max(Ht)] + (max(Ht)-min(Ht)) .* [-0.05,0.05];
set(hAxesImpz, 'XLim', [min(t), max(t)], 'YLim', YLimImpz);

% Add grids
set([hAxesFreqz, hAxesImpz], 'XGrid', 'on', 'YGrid', 'on');
% Enable zooming by default
zoom(hFig, 'on');
    
% Add legends
title(hAxesFreqz, 'Frequency response');
xlabel(hAxesFreqz, 'Frequency (Hz)');
ylabel(hAxesFreqz, 'Magnitude (dB)');
title(hAxesImpz, 'Impulse response');
xlabel(hAxesImpz, 'Time (seconds)');
ylabel(hAxesImpz, 'Amplitude');

% Plot vertical lines to indicate effective transients (99% energy)
line(transient.*[1 1], YLimImpz, -0.1.*[1 1], ...
    'LineWidth', 1, ...
    'Color',     [.7 .7 .7], ...
    'Parent',    hAxesImpz);
line(transient.*[-1 -1], YLimImpz, -0.1.*[1 1], ...
    'LineWidth', 1, ...
    'Color',     [.7 .7 .7], ...
    'Parent',    hAxesImpz);
text(transient .* 1.1, YLimImpz(2), '99% energy', ...
    'Color',               [.7 .7 .7], ...
    'FontSize',            bst_get('FigFont'), ...
    'FontUnits',           'points', ...
    'VerticalAlignment',   'top', ...
    'HorizontalAlignment', 'left', ...
    'Parent',              hAxesImpz);

% Display left panel
[jLabel1, hLabel1] = javacomponent(javax.swing.JLabel(strFilter1), [0 0 1 1], hFig);
set(hLabel1, 'Units', 'pixels', 'BackgroundColor', get(hFig, 'Color'), 'Tag', 'Label1');
bgColor = get(hFig, 'Color');
jLabel1.setBackground(java.awt.Color(bgColor(1),bgColor(2),bgColor(3)));
jLabel1.setVerticalAlignment(javax.swing.JLabel.TOP);

% Display right panel
[jLabel2, hLabel2] = javacomponent(javax.swing.JLabel(strFilter2), [0 0 1 1], hFig);
set(hLabel2, 'Units', 'pixels', 'BackgroundColor', get(hFig, 'Color'), 'Tag', 'Label2');
bgColor = get(hFig, 'Color');
jLabel2.setBackground(java.awt.Color(bgColor(1),bgColor(2),bgColor(3)));
jLabel2.setVerticalAlignment(javax.swing.JLabel.TOP);

% Set resize function
set(hFig, bst_get('ResizeFunction'), @ResizeCallback);
% Force calling the resize function at least once
ResizeCallback(hFig);
bst_progress('stop');

% Resize function
    function ResizeCallback(hFig, ev)
        % Get figure position
        figpos = get(hFig, 'Position');
        textH = 110;        % Text Height
        marginL = 70;
        marginR = 30;
        marginT = 30;
        marginB = 50;
        axesH = round((figpos(4) - textH) ./ 2);
        % Position axes
        set(hAxesFreqz, 'Position', max(1, [marginL, textH + marginB + axesH, figpos(3) - marginL - marginR, axesH - marginB - marginT]));
        set(hAxesImpz,  'Position', max(1, [marginL, textH + marginB,         figpos(3) - marginL - marginR, axesH - marginB - marginT]));
        set(hLabel1,    'Position', max(1, [40,                  1,  round((figpos(3)-40)/2),  textH]));
        set(hLabel2,    'Position', max(1, [round(figpos(3)/2),  1,  round(figpos(3)/2),       textH]));
    end
end
