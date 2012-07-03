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
  
  if isempty(obj.userData);
    obj.userData = struct('map',cell(obj.dataInfo.size(2),1)); 
  end
  
  data = zeros(length(indeces), length(channels));
  for iChan = 1:length(channels)
    % Get information from mef header and index
    fileName      = fullfile(filePath, obj.files{channels(iChan)});
    
    indexArray = obj.userData(channels(iChan)).map;
    
    if isempty(indexArray)
      
      % Start Timer for showing progress for reading header.
      fprintf('Indexing MEF file, channel %i... (only during first call)', ...
        channels(iChan));
      
      [data(:, iChan) indexMap] = ...
        decomp_mef(fileName, indeces(1), indeces(lIndeces), '');
      %data(:,iChan) = decomp_mef(fileName, indeces(1), indeces(lIndeces), '');
     
      randChar = [char(48:57) char(65:90) char(97:122)];
      fileName = sprintf('tempMEFheader_%s.bin',randChar(1 + round(61*rand(10,1))));
      
      tempFileName = fullfile(tempdir, fileName);
      fid = fopen(tempFileName,'w');
      fwrite(fid, indexMap,'uint64');
      fclose(fid);
      
      obj.userData(channels(iChan)).map = memmapfile(tempFileName, ...
        'Format', 'uint64');
      
      fprintf(' ...done.\n');

    else
      data(:,iChan) = decomp_mef(fileName, indeces(1), indeces(lIndeces), ...
        '', indexArray.Data);  
    end
  end


end


