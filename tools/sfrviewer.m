function h = sfrviewer(obj, varargin)
    %SFRVIEWER  GUI which displays raw data and events.
    %    SFRVIEWER(OBJ, RANGE, INDECES) createsda  sdfa GUI which shows the
    %    electrodes INDECES over the range RANGE=[first_index last=_index]
    %    for RawData object OBJ.
    %
    %    SFRVIEWER(..., ANNOTATIONS) includes annotations in the viewer. The
    %    ANNOTATIONS can be a vector of structs, generated by the
    %    ANNOTATIONSTRUCT method. Each element of the annotationstruct-array,
    %    will represent an independent layer of annotations.
    %    
    %    SFRVIEWER(..., 'sf', SAMPLINGRATE) displays the X-axis in real time,
    %    rather than index numbers.
    %
    %    SFRVIEWER(...) Additional inputs to the SFRVIEWER are passed in as
    %    arguments to the getdata method of the SFR object. 
    %
    %    See also: annotationstruct SFRepos
    
    panelColor = get(0,'DefaultUicontrolBackgroundColor');
    scrSize = (get(0,'ScreenSize')./72)./2.54;
    
    assert(nargin > 2, 'Insufficient number of input arguments.');

    sampleFreq = 1;
    xTitle = 'SampleNr';
    annStruct = [];
    
    % If more than standard number of input argument, then check inputs. This
    % fails if the user wants to pass 'sf' to the getData method or if the user
    % wants to pass an annotation structure to the getdata method. This should
    % never really happen.
    getDataAttr  = {};
    if nargin > 3
      curix = 3;
      getDataAttrI = 1;
      while curix <= length(varargin)
        % Check for annotations:
        if isstruct(varargin{curix})
          expectedNames = {'name'; 'type'; 'chvec'; 'startvec'; ...
            'stopvec'; 'valuevec'};
          if all(strcmp(expectedNames,fieldnames(varargin{curix})))
            annStruct = varargin{curix};
            curix = curix + 1;
          else
            getDataAttr{getDataAttrI} = varargin{curix}; %#ok<AGROW>
            getDataAttrI = getDataAttrI+1;
            curix = curix + 1;
          end
        elseif ischar(varargin{curix}) && nargin > curix
          if strcmp(varargin{curix}, 'sf')
            sampleFreq = varargin{curix + 1};
            xTitle = 'Time (s)';
            curix = curix + 2;
          else
            getDataAttr{getDataAttrI} = varargin{curix}; %#ok<AGROW>
            getDataAttrI = getDataAttrI+1;
            curix = curix + 1;
          end
        else
          getDataAttr{getDataAttrI} = varargin{curix}; %#ok<AGROW>
          getDataAttrI = getDataAttrI+1;
          curix = curix + 1;
        end
        
      end
    end

    % Set up the figure and defaults
    uihandle = figure('Units','centimeters',...
      'Position',[scrSize(3)/1.25 scrSize(4)/4 30 20],...
      'Color',panelColor,...
      'Renderer','painters',...
      'HandleVisibility','callback',...
      'IntegerHandle','off',...
      'Toolbar','none',...
      'MenuBar','none',...
      'NumberTitle','off',...
      'Name','Workspace Plotter',...
      'ResizeFcn',@figResize);
    
    % Create the bottom uipanel
    topPanel = uipanel('BorderType','line',...
      'BackgroundColor',panelColor,...
      'Units','centimeters',...
      'Position',[1 1 11 1.2],...
      'Parent',uihandle,...
      'Clipping','on',...
      'Tag','topP',...
      'ResizeFcn',@topPanelResize);
    
    % Create the bottom uipanel
    bottomPanel = uipanel('BorderType','line',...
      'BackgroundColor',panelColor,...
      'Units','centimeters',...
      'Position',[1 1 11 1.2],...
      'Parent',uihandle,...
      'Clipping','on',...
      'Tag','botP',...
      'ResizeFcn',@botPanelResize);
    
    % Create the bottom uipanel
    bottomPanel2 = uipanel('BorderType','line',...
      'BackgroundColor',panelColor,...
      'Units','centimeters',...
      'Position',[1 1 11 1.2 ],...
      'Parent',uihandle,...
      'Clipping','on',...
      'Tag','botP2',...
      'ResizeFcn',@botPanelResize);
    
    % Create the right side panel
    centerPanel = uipanel('bordertype','line',...
      'BackgroundColor',panelColor,...
      'Units','centimeters',...
      'Position',[1/20 8 88 27],...
      'Parent',uihandle,...
      'Tag','cenP',...
      'ResizeFcn',@cenPanelResize);
    
    chanLabels = cell(length(varargin{2}),1);
    for i=1:length(chanLabels)
      chanLabels{i} = sprintf('Ch_%i',varargin{2}(i));
    end
    
    % Create the center panel
    a1 = axes(...
      'Units','centimeters',...
      'Position', [3 2 88 27],...
      'XLim',[0 1],'YLim',[0,1],...
      'Tag','plotWindow',...
      'Parent',centerPanel,...
      'YTickLabel',chanLabels,'YTickLabelMode','manual','YTick',1:length(varargin{2}));
    set(get(a1,'XLabel'),'String',xTitle,'FontSize',12);
    set(get(a1,'YLabel'),'String','Channel Number','FontSize',12);

    if isa(obj,'SFRepos')
      plotName = obj.subPath;
    else
      plotName = 'Data from Matlab Struct';
    end
    
    uicontrol(uihandle,'Style', 'text', 'Units','normalized', 'String', plotName,...
    'Position', [0 0 0.25 1], 'Parent', topPanel,'HorizontalAlignment','left',...
    'FontSize',12,'Tag','title');  


    uicontrol(uihandle,'Style', 'pushbutton', 'Units','centimeters', 'String', '<',...
    'Position', [0.1 0.1 2.4 1], 'Callback',@PushBackwards, 'Parent', bottomPanel);
    uicontrol(uihandle,'Style', 'pushbutton', 'Units','centimeters', 'String', '>',...
    'Position', [2.6 0.1 2.4 1], 'Callback',@PushForwards,'Parent',bottomPanel);

    uicontrol(uihandle,'Style', 'pushbutton', 'Units','centimeters', 'String', 'Ctr',...
    'Position', [6 0.1 2 1], 'Callback',@Center,'Parent',bottomPanel);
    uicontrol(uihandle,'Style', 'pushbutton', 'Units','centimeters','String', '-',...
    'Position', [8.1 0.1 2 1], 'Callback',@ZoomOutY,'Parent',bottomPanel);    
    uicontrol(uihandle,'Style', 'pushbutton', 'Units','centimeters', 'String', '+',...
    'Position', [10.2 0.1 2 1], 'Callback',@ZoomInY,'Parent',bottomPanel);

    uicontrol(uihandle,'Style', 'pushbutton', 'Units','centimeters', 'String', '><',...
    'Position', [12.3 0.1 2 1], 'Callback',@ZoomInT,'Parent',bottomPanel);
    uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters', 'String', '<>',...
    'Position', [14.4 0.1 2 1], 'Callback',@ZoomOutT,'Parent',bottomPanel);

    uicontrol(uihandle,'Style', 'pushbutton', 'Units','centimeters', 'String', '<-|',...
    'Position', [17.4 0.1 2 1], 'Callback',{@NextEvnt,false},'Parent',bottomPanel);
    evntSelect = uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters',...
    'Position', [19.5 0.1 3 1], 'Callback',@ToggleNEventButton,'Parent',bottomPanel,...
    'ForegroundColor', [0.4 0.4 0.4],'Tag','EvntSelect','userData',0);
    uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters', 'String', '|->',...
    'Position', [22.6 0.1 2 1], 'Callback',{@NextEvnt,true},'Parent',bottomPanel);

    uicontrol(uihandle,'Style', 'pushbutton','Units','centimeters', 'String', 'To PDF',...
    'Position', [24.6 0.1 2.4 1], 'Callback',@PrintPDF,'Parent',topPanel, 'Tag','pdfButton');


    if ~isempty(annStruct)
      evButtonHandles = zeros(length(annStruct),1);
      for iStruct = 1:length(annStruct)
          
        %Check issorted
        assert(issorted(annStruct(iStruct).startvec),...
          'The Annotation Structure Start property must be a sorted vector.');

        evButtonHandles(iStruct) = uicontrol(uihandle, ...
          'Style', 'pushbutton', ...
          'Units','centimeters', ...
          'String', annStruct(iStruct).name, ...
          'Position', [(0.1 + (iStruct-1)*2.4 + (iStruct-1)*0.1) 0.1 2.4 1], ...
          'Tag', annStruct(iStruct).name, ...
          'Callback',@toggleEventButton, ...
          'Parent',bottomPanel2, ...
          'userData',{0 annStruct(iStruct) iStruct});
      end
    else
      evButtonHandles = [];
    end
    
    set(evntSelect,'String','-');
    
	% Create Line handles
    lHandles = zeros(size(varargin{2},2),1);
    for i = 1: size(varargin{2},2)
      lHandles(i) = line([0 0], [0 0],'Parent',a1);
    end

    set(a1,'YLim',[0 length(lHandles)+1]);    
    
    setup = struct(...
      'cols',varargin{2}, ...
      'start', uint32(min(varargin{1})), ...
      'stop', uint32(max(varargin{1})), ...
      'startTime', min(varargin{1}),... %Exact startTime
      'sf', sampleFreq,...
      'decimation', [], ...
      'lhandles', lHandles, ...
      'objHandles',obj, ...
      'center', [], ...
      'compression',[], ...
      'eventButtons',evButtonHandles,...
      'electrodes', [],...
      'GetDataAttr',[],...
      'eventOffsetLine',[]);
    setup.GetDataAttr = getDataAttr;
    
    guidata(uihandle, setup);
    h = a1;
end

% METHODS FOR RESIZING GUI
function figResize(src,~)			
	fpos = get(src,'Position');
  children = get(src,'Children');
  topPanel = findobj(children,'Tag','topP');
  botPanel = findobj(children,'Tag','botP');
  botPanel2 = findobj(children,'Tag','botP2');
  centerPanel = findobj(children,'Tag','cenP');

  tpos = get(topPanel,'position');

  bpos2 = get(botPanel2,'position');
  set(botPanel2,'Position',...
      [0.2 0.2 fpos(3)-.4 bpos2(4)])
  bpos2 = get(botPanel2,'position');

  bpos = get(botPanel,'position');
  set(botPanel,'Position',...
      [0.2 bpos2(2)+bpos2(4)+0.1 fpos(3)-.4 bpos(4)])
  bpos = get(botPanel,'position');


  cwidth = max([0.2 fpos(3)-0.4]);
  cheigth = max([0.1 fpos(4) - bpos(4)- bpos2(4)- 0.8 - tpos(4)]);
  cbottom = bpos(2)+bpos(4)+0.2;

  set(centerPanel,'Position',...
      [0.2  cbottom cwidth cheigth]);

  set(topPanel,'Position',...
      [0.2 cheigth+cbottom+0.2 cwidth tpos(4) ]);

  A1 = findobj(centerPanel,'Tag','plotWindow');
  updateRaw(A1);
end

function topPanelResize(src, ~)		
    PDFbutton = findobj(src,'Tag','pdfButton');
    pos = get(src, 'Position');
    posb = get(PDFbutton, 'Position');
    set(PDFbutton,'Position', [(pos(1)+pos(3) -posb(3)  - 0.4) posb(2) posb(3) posb(4)]);

end

function botPanelResize(~, ~)		
    % Does nothing now
end

function cenPanelResize(src,~)		
    rpos = get(src,'Position');
    
    %resize listbox with properties
    listHandle = findobj(get(src,'Children'),'Tag','plotWindow');
    set(listHandle,'Position',[3 1.5 rpos(3)-3.5 rpos(4)-2]);
end

% GLOBAL UPDATE FUNCTIONS
function updateRaw(src, ~)			
	setup = guidata(src);

  CH = get(gcbf,'Children');
  CenP = findobj(CH,'Tag','cenP');
  axesHandle = findobj(CenP,'Tag','plotWindow');

  GetDataAttr = setup.GetDataAttr;
  
	pos = get(axesHandle, 'Position');
	width = ((pos(3)-pos(1))./2.54)*72; %change to pixels.
	
	dataLength = double(setup.stop - setup.start);
	setup.decimation = max([1 round((0.5*dataLength)/width)]); %2 datapoints per pixel
	
	% Get Data
  aux = setup.objHandles;
  data = aux.data(setup.start:setup.stop, setup.cols, GetDataAttr{:});
  
  % If the getdata method returns a structure, get the data property.
  if isstruct(data)
    data = double(data.data);
  else
    data = double(data);
  end
  time = double((setup.start:setup.stop))./setup.sf;
  	
  if isempty(setup.center)
      % Only during first call
      setup.center = mean(data);
      setup.compression = max(max(data) - mean(data));
  end

  if setup.decimation > 1
      data = data(1:setup.decimation:end,:);
      time = time(1:setup.decimation:end);
  end
  for i =1: length(setup.cols)
  aux = (data(:,i)'-setup.center(i))./setup.compression + i;
    set(setup.lhandles(i),'XData',time, 'YData',aux);
  end

	set(axesHandle,'XLim',[min(time) max(time)]);	
	
	guidata(src, setup);
end

function updateEvents(src)			
  % This function iterates over all eventButtons defined in the
  % eventButtons array in the guidata. It is easy to add new event
  % buttons to the gui just by placing them in this array and follow the
  % correct syntax requirements.

  setup = guidata(src);
  for i = 1: length(setup.eventButtons)

    % Only update when button is in 'on'-mode.
    ButtonUserData = get(setup.eventButtons(i),'userData');
    if ButtonUserData{1} 
      if ButtonUserData{3} 
        switch ButtonUserData{2}.type
          case 'DoubleEvent'
            DoubleEvent_update(setup.eventButtons(i));
          case 'SingleEvent'
            SingleEvent_update(setup.eventButtons(i));
          case 'SingleMarker'
            SingleMarker_update(setup.eventButtons(i));
          otherwise
            eval(sprintf('%s_update(src)',get(setup.eventButtons(i),'Tag')));
        end
      else
        eval(sprintf('%s_update(src)',get(setup.eventButtons(i),'Tag')));
      end
    end
  end
end

% METHODS FOR GUI BUTTON CALLBACKS
function ZoomInY(src, ~)            
    setup = guidata(src);
    
    oldCompress = setup.compression;
    setup.compression = oldCompress - 0.25*oldCompress;
    
    for i = 1: length(setup.lhandles)
        aux = get(setup.lhandles(i),'YData');
        aux = aux - i;
        aux = aux * (oldCompress./setup.compression);
        set(setup.lhandles(i),'YData', aux +i);    
    end
    
    guidata(src, setup)
end

function ZoomOutY(src, ~)           
    setup = guidata(src);
    
    oldCompress = setup.compression;
    setup.compression = oldCompress + 0.25*oldCompress;
    
    for i = 1: length(setup.lhandles)
        aux = get(setup.lhandles(i),'YData');
        aux = aux - i;
        aux = aux * (oldCompress./setup.compression);
        set(setup.lhandles(i),'YData', aux +i);    
    end
    
    guidata(src, setup)
end

function ZoomInT(src, ~)            
    set(src, 'Enable','off');
    drawnow update
    setup = guidata(src);
    
    lData = setup.stop - setup.start + 1;
    newLength = round(lData * 0.9);
    
    setup.start = setup.start;
    setup.stop = setup.start + newLength;

    guidata(src, setup);
    
    updateRaw(src);
    updateEvents(src);
    set(src, 'Enable','on');
end

function ZoomOutT(src, ~)           

    set(src, 'Enable','off');
    drawnow update
    setup = guidata(src);
    
    lData = setup.stop - setup.start +1;
    newLength = round(lData * 1.1);
    
    setup.start = setup.start;
    setup.stop = setup.start + newLength;

    guidata(src, setup);
    
    updateRaw(src);
    updateEvents(src);
    set(src, 'Enable','on');
end

function Center(src, ~)             
    setup = guidata(src);

    for i = 1: length(setup.lhandles)
        aux = get(setup.lhandles(i),'YData') - i;
        aux = aux * setup.compression;
        aux = aux + setup.center(i);
        newMean =aux(1);
        setup.center(i) = newMean;
        set(setup.lhandles(i),'YData',(aux - newMean)./setup.compression+i);
    end

    guidata(src,setup);
    updateEvents(src);
end

function PushForwards(src, ~)       
    set(src, 'Enable','off');
    drawnow update
    setup = guidata(src);
    
    if ~isempty(setup.eventOffsetLine)
        delete(setup.eventOffsetLine);
        setup.eventOffsetLine = [];
    end
    
    ldata = setup.stop - setup.start +1;
    stripPoint = round(ldata*0.75);
    newLength = ldata - stripPoint;
    
    setup.start = setup.start + newLength;
    setup.startTime = double(setup.start)./setup.sf;
    setup.stop  = setup.stop + newLength;
    
    guidata(src, setup);
    updateRaw(src);
    updateEvents(src);
    set(src, 'Enable','on');   
end

function PushBackwards(src, ~)      
  try
    set(src, 'Enable','off');
    drawnow update
    setup = guidata(src);

    if ~isempty(setup.eventOffsetLine)
        delete(setup.eventOffsetLine);
        setup.eventOffsetLine = [];
    end

    ldata = setup.stop - setup.start +1;
    stripPoint = round(ldata*0.25);
    newLength = stripPoint;

    setup.start = setup.start-newLength;
    setup.startTime = double(setup.start)./setup.sf;
    setup.stop  = setup.stop-newLength;

    guidata(src, setup);
    updateRaw(src);
    updateEvents(src);
    set(src, 'Enable','on');  

  catch ME %#ok<NASGU>
    set(src, 'Enable','on');
  end
end

function ToggleNEventButton(src,~)  
        
    setup = guidata(src);
    names = get(setup.eventButtons,'String');
    
    props = get(setup.eventButtons,'UserData');
    
    if size(props,1) == 1
      active = props{1};
      if active
        names  = {names};
      else
        names  = {};
      end
    else
      active = cellfun(@(x) x{1},props) >0;
      names = names(active);
    end
    
    if isempty(names)
        set(src,'String','-','UserData',0);
    else
        index = get(src, 'UserData') + 1;
        if index > length(names); index=1;end
        set(src, 'String', names{index}, 'UserData', index);
    end
        
end

function NextEvnt(src, ~, direction)
    
    setup = guidata(src);
    displOffsetFrac = 1/20; %offset as percentage of screen size.
    displOffset = round(displOffsetFrac * (setup.stop-setup.start));
    
    try
        set(src, 'Enable','off');
        drawnow update
        
        names = get(setup.eventButtons,'String');
        
        BotPanel = get(src,'Parent');
        TogleEvntButton = findobj(BotPanel,'Tag','EvntSelect');
        Str = get(TogleEvntButton, 'String');
        
        NextEvnt = [];
        
        whichButt = find(strcmp(Str,names),1);
        curButton = setup.eventButtons(whichButt);
        
        %Xlim is threshold in time for next event
        Xlim = setup.startTime + double(displOffset) ./ setup.sf;

          
          usrData = get(curButton,'userData');
          
          if direction

              NextRes = usrData{2}.startvec(find(usrData{2}.startvec > Xlim,1));
              if ~isempty(NextRes)
                  NextEvnt = min([NextEvnt NextRes]);
              end
          else

              prevRes = usrData{2}.startvec(find(usrData{2}.startvec < Xlim,1,'last'));
              if ~isempty(prevRes)
                  NextEvnt = max([NextEvnt prevRes ]);
              end
          end

        if ~isnan(NextEvnt)
            l = setup.stop-setup.start;
            
            setup.startTime = NextEvnt - double(displOffset) ./ setup.sf;
            setup.start = uint32(setup.startTime*setup.sf);

            setup.stop = setup.start + l;
            guidata(src, setup);

            updateRaw(src)
            updateEvents(src);
        end
        
        setup = guidata(src);
        if ~isempty(setup.eventOffsetLine)
            delete(setup.eventOffsetLine);
            setup.eventOffsetLine = [];
        end
    
        CH = get(gcbf,'Children');
        CenP = findobj(CH,'Tag','cenP');
        axesHandle = findobj(CenP,'Tag','plotWindow');
        
        if ~isempty(NextEvnt)
        
            h = line([NextEvnt NextEvnt], [0 (length(setup.lhandles)+1)], 'Parent',axesHandle, 'Color','black','LineStyle','--');
            setup.eventOffsetLine = h;
        end
        guidata(src, setup);

        set(src,'Enable','on');
    catch ME  %#ok<NASGU>
        set(src,'Enable','on');
    end
end

function PrintPDF(~,~)              
  % Generate new figure and copy the axes. The print figure to pdf and
  % delete the figure...

  curFig = gcbf;
  cenP = findobj(get(curFig,'Children'),'Tag','cenP');
  A = findobj(get(cenP,'Children'),'Tag','plotWindow');

  topP = findobj(get(curFig,'Children'),'Tag','topP');
  T = findobj(get(topP,'Children'),'Tag','title');
  ttl = get(T,'String');

  [FileName,PathName,~] = uiputfile({'*.pdf'},'Select PDF FileName','RawViewFig.pdf');

  if ~isempty(FileName)
    aux = get(A,'Position');

    NF = figure('PaperUnits','centimeters','PaperSize',[aux(3)+4 aux(4)+4],...
        'PaperPositionMode','manual',...
        'PaperPosition',[0 0  aux(3)+5 aux(4)+5],...
        'renderer','painters',...
        'Visible','off');

    h = copyobj(A, NF);
    set(h,'Box','on');
    set(h,'Position',[2,2,aux(3),aux(4)]);
    title(h,ttl,'Interpreter','none','HorizontalAlignment','center','FontSize',12);
    print(NF,'-dpdf',fullfile(PathName,FileName));
    delete(NF);
  end
end

function toggleEventButton(src,~)   

  % 4 States: Off - Event Time - Event Time/value - Event Value
  setup = guidata(src);
  UD = get(src,'userData');
  newVal ={mod(UD{1}+1,4) UD{2} UD{3}};
  switch newVal{1}
    case 0 % off
      Bcolor = [0 0 0 ];
    case 1 % event times
      Bcolor = [0 0.5 0];
    case 2 % event times/value
      Bcolor = [0.5 0 0];
    case 3 % event values
      Bcolor = [0 0 0.5];
  end

  set(src,'userData', newVal,'ForegroundColor', Bcolor);
  if newVal{1}
    updateEvents(src);
  else
    try
      lineName = sprintf('%s_lines',get(src,'Tag'));
      aux = setup.(lineName);
      delete(aux);
      setup = rmfield(setup, lineName);
    catch %#ok<CTCH>
    end
    try
      textName = sprintf('%s_text',get(src,'Tag'));
      aux = setup.(textName);
      delete(aux);
      setup = rmfield(setup, textName);
    catch %#ok<CTCH>
    end

    guidata(src,setup);
  end
end

% METHODS FOR EVENT BUTTON CALLBACKS
function DoubleEvent_update(src, varargin)             
    
  setup = guidata(src);

  %Get eventButtonName
  eventButtonName = get(src,'String');

  if ~isfield(setup, [eventButtonName '_lines'])
    setup.([eventButtonName '_lines']) = zeros(length(setup.lhandles),1);
    setup.([eventButtonName '_text']) = [];
    for iEvnt=1: length(setup.lhandles)
      setup.([eventButtonName '_lines'])(2*(iEvnt-1)+1) = line('Color','g','XData',[],'YData',[],'LineWidth',2);
      setup.([eventButtonName '_lines'])(2*(iEvnt-1)+2) = line('Color','r','XData',[],'YData',[],'LineWidth',2);
    end
  else
    aux = setup.([eventButtonName '_text']);
    if ~isempty(aux)
      delete(aux);
    end
    setup.([eventButtonName '_text']) = [];
  end

  % Update the events in the current window
  usrData = get(src, 'userData');
  eventStr = usrData{2};
    visMode = usrData{1};
  
  % Update the events in the current window
  xdat =  get(setup.lhandles(1),'XData')./setup.sf;
  inclAll = eventStr.startvec > xdat(1) & eventStr.startvec < xdat(end);
  tIdx = 1;
  for i = 1: length(setup.lhandles)
    incl = inclAll & eventStr.chvec == setup.cols(i);
    switch visMode
      case 1
        [xvals, yvals, ~] = getRasterXY(eventStr.startvec(incl), i, 0.5);
        set(setup.([eventButtonName '_lines'])(2*(i-1)+1),'XData',xvals,'YData',yvals);

        [xvals, yvals, ~] = getRasterXY(eventStr.stopvec(incl), i, 0.5);
        set(setup.([eventButtonName '_lines'])(2*(i-1)+2),'XData',xvals,'YData',yvals);
      case 2
        [xvals, yvals, ~] = getRasterXY(eventStr.startvec(incl), i, 0.5);
        set(setup.([eventButtonName '_lines'])(2*(i-1)+1),'XData',xvals,'YData',yvals);

        [xvals, yvals, ~] = getRasterXY(eventStr.stopvec(incl), i, 0.5);
        set(setup.([eventButtonName '_lines'])(2*(i-1)+2),'XData',xvals,'YData',yvals);
        
        inclI = find(incl);
        startVI = eventStr.startvec(incl);
        for j = 1:sum(incl)
          newTextObj = text(startVI(j), i+0.4, ...
            num2str(eventStr.valuevec(inclI(j))));
          setup.([eventButtonName '_text'])(tIdx) = newTextObj;
          tIdx = tIdx + 1;
        end
      case 3
        set(setup.([eventButtonName '_lines'])(2*(i-1)+1), 'YData',[], 'XData', [] );
        set(setup.([eventButtonName '_lines'])(2*(i-1)+2), 'YData',[], 'XData', [] );
        
        inclI = find(incl);
        startVI = eventStr.startvec(incl);
        for j = 1:sum(incl)
          newTextObj = text(startVI(j), i+0.4, ...
            num2str(eventStr.valuevec(inclI(j))));
          setup.([eventButtonName '_text'])(tIdx) = newTextObj;
          tIdx = tIdx + 1;
        end
    end
  end

  guidata(src,setup);

end

function SingleEvent_update(src, varargin)             
  setup = guidata(src);

  %Get eventButtonName
  eventButtonName = get(src,'String');

  if ~isfield(setup, [eventButtonName '_lines'])
    setup.([eventButtonName '_lines'])  = zeros(length(setup.lhandles),1);
    setup.([eventButtonName '_text']) = [];
    for iEvnt=1: length(setup.lhandles)
      setup.([eventButtonName '_lines'])(iEvnt) = line('Color','k','XData',[],'YData',[],'LineWidth',2);
    end
  else
    
    aux = setup.([eventButtonName '_text']);
    if ~isempty(aux)
      delete(aux);
    end
    setup.([eventButtonName '_text']) = [];
  end

  usrData = get(src, 'userData');
  eventStr = usrData{2};
  visMode = usrData{1};
  
  % Update the events in the current window
  xdat =  get(setup.lhandles(1),'XData')./setup.sf;
  inclAll = eventStr.startvec > xdat(1) & eventStr.startvec < xdat(end);
  tIdx = 1;
  for i = 1: length(setup.lhandles)
    incl = inclAll & eventStr.chvec == setup.cols(i);
    switch visMode
      case 1
        [xvals, yvals, ~] = getRasterXY(eventStr.startvec(incl), i, 0.5);
        set(setup.([eventButtonName '_lines'])(i),'XData',xvals,'YData',yvals);
      case 2
        [xvals, yvals, ~] = getRasterXY(eventStr.startvec(incl), i, 0.5);
        set(setup.([eventButtonName '_lines'])(i),'XData',xvals,'YData',yvals);
        
        inclI = find(incl);
        startVI = eventStr.startvec(incl);
        for j = 1:sum(incl)
          newTextObj = text(startVI(j), i+0.4, ...
            num2str(eventStr.valuevec(inclI(j))));
          setup.([eventButtonName '_text'])(tIdx) = newTextObj;
          tIdx = tIdx + 1;
        end
      case 3
        set(setup.([eventButtonName '_lines'])(i), 'YData',[], 'XData', [] );
        
        inclI = find(incl);
        startVI = eventStr.startvec(incl);
        for j = 1:sum(incl)
          newTextObj = text(startVI(j), i+0.4, ...
            num2str(eventStr.valuevec(inclI(j))));
          setup.([eventButtonName '_text'])(tIdx) = newTextObj;
          tIdx = tIdx + 1;
        end
    end
  end

  guidata(src,setup);

end

function SingleMarker_update(src,varargin)            

    setup = guidata(src);
    
    %Get eventButtonName
    eventButtonName = get(src,'String');
    ButtonData = get(src,'userData');
    
    if ~isfield(setup, [eventButtonName '_handles'])
        obj = subsref(setup.objHandles,substruct('.','parent','.','an','()', ButtonData(3)));
        obj = subsref(obj, substruct('.',obj.linkProps{1}));
        
        setup.([eventButtonName '_handles'])(length(setup.lhandles),1) = eval(class(obj));
        
        A = subsref(setup.objHandles, substruct('.','array'));
        SA = subsref(obj, substruct('.','array'));
        SA = [SA{:}];
        
        ObjInArray = SA == A;
        ObjInArray = obj(ObjInArray);
        
        % Iterate over objects and get spikeData
        for iEvnt=1: length(setup.lhandles)

            Object = ObjInArray( [ObjInArray.electrode] == setup.electrodes(iEvnt));
            if ~isempty(Object)
                setup.([eventButtonName '_handles'])(iEvnt) = Object;
            else
                delete(setup.([eventButtonName '_handles'])(iEvnt));
            end
            setup.([eventButtonName '_text']) = [];
        end
        
    end
    
    if ~isempty(setup.([eventButtonName '_text']));
        aux = setup.([eventButtonName '_text'])
        delete(aux);
    end
    
    % Update the events in the current window
    ix = 1;
    for i = 1: length(setup.lhandles)
        xdat =  get(setup.lhandles(i),'XData')./setup.sf;
        if isvalid(setup.([eventButtonName '_handles'])(i))
            
            [~, events, eventNames] = getEvents(setup.([eventButtonName '_handles'])(i), [xdat(1) xdat(end)]);
            
            eventIndex = find(strcmp(eventButtonName, eventNames),1);
            
            curEvents = double(events{eventIndex});
            
            for ii = 1: size(curEvents,1)
                setup.([eventButtonName '_text'])(ix) = text(curEvents(ii,1),i+0.4, num2str(curEvents(ii,2)));
                ix=ix+1;
            end
                        
        end
    end
    if length(setup.([eventButtonName '_text']))>=ix
        setup.([eventButtonName '_text'])(ix:end) = [];
    end
    
    guidata(src, setup);

end

% GENERATING RASTER OBJECT METHOD
function [xvals,yvals,yCenter] = getRasterXY(ts,Offset,Spacing,LineLength,Start)
  %getRasterXY  get x & y values for quick raster plotting
  %   [XVALS,YVALS,YCENTER] = getRasterXY(TS,OFFSET,SPACING,LINE_LENGTH,START)
  %   uses the function YCENTER = OFFSET + SPACING*(START-1) to determine the
  %   height at which the raster line will be centered.  From their YVALS extend 
  %   from YCENTER - LINE_LENGTH/2 to YCENTER + LINE_LENGTH/2.  This format allows
  %   one to specify an intended starting OFFSET, and the START input can be used
  %   in a loop to iterate through different TS values.  TS is a vector of time events.
  %
  %   [...] = getRasterXY(TS,YCENTER,LINE_LENGTH) uses the specified YCENTER
  %   instead of that calculated by SPACING & START
  %
  if nargin == 3
      yCenter = Offset;
      LineLength = Spacing;
  elseif nargin == 5
      yCenter = Offset + Spacing*(Start-1);
  else
      error('Incorrect # of inputs')
  end

  l = length(ts);
  nans = NaN*ones(l,1);

  xvals = zeros(3*l,1);
  xvals(1:3:(3*l)) = ts;
  xvals(2:3:(3*l)) = ts;
  xvals(3:3:(3*l)) = nans;

  yvals = zeros(3*l,1);
  yvals(1:3:(3*l)) = zeros(l,1) + yCenter - (LineLength/2);
  yvals(2:3:(3*l)) = zeros(l,1) + yCenter + (LineLength/2);
  yvals(3:3:(3*l)) = nans;
end