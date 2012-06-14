function data = getMefByChannel( obj, channels, indeces, filePath, ~)
  %GETMEFBYCHANNEL See infoBinaryByChannel

  % EXTERNAL FILE REQUIREMENTS (functions)
  % decomp_mef.mex

  % Copyright (c) 2012, A.Pearce, J.B.Wagenaar 
  % This source file is subject to version 3 of the GPL license, 
  % that is bundled with this package in the file LICENSE, and is 
  % available online at http://www.gnu.org/licenses/gpl.txt
  %
  % This source file can be linked to GPL-incompatible facilities, 
  % produced or made available by MathWorks, Inc.
  
  % Author: Allison Pearce, Litt Lab, June 2012

  assert(exist('decomp_mef','file') == 3,'SciFileRepos:getMef',...
    'Cannot find the DECOMP_MEF mex file.');
  
  assert(issorted(indeces), 'SciFileRepos:getMEF',...
    'The GETMEF method only supports sorted continuous indeces.');
  lIndeces = length(indeces);
  assert(lIndeces == (indeces(lIndeces)-indeces(1)+1), 'SciFileRepos:getMEF',...
    'The GETMEF method only supports sorted continuous indeces.');
  
  getIndexArray = true;
  if ~isempty(obj.userData);
    getIndexArray = false;
  end
  
  data = zeros(length(indeces), length(channels));
  for iChan = 1:length(channels)
    % Get information from mef header and index
    fileName      = fullfile(filePath, obj.files{channels(iChan)});
    
    if getIndexArray
      
      try
      % Start Timer for showing progress for reading header.
      % Init Timer
      display('Indexing MEF file.');
      progress_timer = timer;
      set(progress_timer, 'ExecutionMode', 'FixedRate');
      set(progress_timer, 'BusyMode','queue');
      set(progress_timer, 'Period', 1);
      set(progress_timer, 'StartDelay',1);
      set(progress_timer, 'TimerFcn', @(x,y)fprintf('.'));
      start(progress_timer);
      
%       [data(:, iChan) obj.userData] = ...
%         decomp_mef(fileName, indeces(1), indeces(lIndeces), '');
      data(:,iChan) = decomp_mef(fileName, indeces(1), indeces(lIndeces), '');
      stop(progress_timer);
     
      delete(progress_timer);
      fprintf('\nFile Indexing complete.');
      getIndexArray = false;
      catch ME
        delete(progress_timer);
        rethrow(ME);
      end
      
    else
      data(:,iChan) = decomp_mef(fileName, indeces(1), indeces(lIndeces), '');  
    end
  end


end

