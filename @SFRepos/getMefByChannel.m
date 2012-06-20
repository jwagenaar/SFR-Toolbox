function data = getMefByChannel(obj, channels, indeces, filePath, ~)
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
  
  % During the first time that the decomp_mef function is called, it will index
  % the mef file and store the indexing array in the userData of the object.
  % This will significantly speedup further requests. 

  assert(exist('decomp_mef','file') == 3,'SciFileRepos:getMef',...
    'Cannot find the DECOMP_MEF mex file.');
  
  assert(issorted(indeces), 'SciFileRepos:getMEF',...
    'The GETMEF method only supports continuous sorted indeces.');
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
      
      % Start Timer for showing progress for reading header.
      fprintf('Indexing MEF file... (only during first call)');
      
%       [data(:, iChan) obj.userData] = ...
%         decomp_mef(fileName, indeces(1), indeces(lIndeces), '');
      data(:,iChan) = decomp_mef(fileName, indeces(1), indeces(lIndeces), '');
     
      fprintf(' ...done.\n');
      getIndexArray = false;

    else
      data(:,iChan) = decomp_mef(fileName, indeces(1), indeces(lIndeces), '');  
    end
  end


end


