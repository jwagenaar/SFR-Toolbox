function data = getNicoletEEG(obj, channels, indeces, locPath, options)
  %NICOLETEEG  See INFONICOLETEEG for information.

  % Copyright (c) 2012, A. Nijsure, J.B.Wagenaar
  % This source file is subject to version 3 of the GPL license, 
  % that is bundled with this package in the file LICENSE, and is 
  % available online at http://www.gnu.org/licenses/gpl.txt
  %
  % This source file can be linked to GPL-incompatible facilities, 
  % produced or made available by MathWorks, Inc.
  
  format = obj.dataInfo.format;
  
  % Table of samples per file per channel from all files for a session.
  % Check if samples per file is known.
  if isempty(obj.userData)
    obj.userData = struct('smplPerFile', zeros(length(obj.files),1), ...
      'mapObjects',[]);
    
    % For loop to add samples from each file.   
    for i = 1:length(obj.files)      
      f_name = fullfile(locPath, obj.files{i});

      assert(exist(f_name, 'file') == 2, ...
        'SciFileRepos:infoNicoletEEG', 'File not found'); 

      fid=fopen(f_name);
      fseek(fid,0,1);
      total_bytes=ftell(fid);
      fclose(fid);
      samples = total_bytes/2;
      obj.userData.smplPerFile(i) = samples/obj.dataInfo.size(2);     
    end
  end
  
  SampPerFile = obj.userData.smplPerFile;
  firstIndexPerFile = [0; cumsum(SampPerFile)] +1;
  
  % Sort the indeces if necessary.
  doSort = false;
  if ~issorted(indeces)
    doSort = true;
    [indeces sortedIndex] = sort(indeces);
  end
  
  nrChannels  = obj.dataInfo.size(2);
  curIndex    = 1;
  curFile     = 1;
  lIndeces    = length(indeces);
  data = zeros(lIndeces, length(channels), format);
  
  while curIndex <= length(indeces)
    newInd = indeces(curIndex : lIndeces);
    newFileIndex = find(newInd >= firstIndexPerFile(curFile + 1), 1);
    if ~isempty(newFileIndex)
      newInd = indeces(curIndex: curIndex + newFileIndex - 2);
    end
    
    if ~isempty(newInd)
      fileName = fullfile(locPath, obj.files{curFile});

      % Check if mmm is cached in object.
      mapObjects = obj.userData.mapObjects;
      if ~isempty(mapObjects)
        mappedFiles = [mapObjects.fileID];
        mapIdx = find(curFile == mappedFiles,1);
        if ~isempty(mapIdx)
          mmm = mapObjects(mapIdx).map;
        else
          mmm = memmapfile(fileName, ...
          'Format', {format double([nrChannels SampPerFile(curFile)]) ,'x'}, ...
          'Writable', false);

          lMapObjs = length(obj.userData.mapObjects);
          obj.userData.mapObjects(lMapObjs + 1) = struct( ...
            'fileID', curFile, 'map', []);
          obj.userData.mapObjects(lMapObjs + 1).map = mmm;
        end      
      else
        mmm = memmapfile(fileName, ...
          'Format',{format double([nrChannels SampPerFile(curFile)]) ,'x'}, ...
          'Writable', false);      
        obj.userData.mapObjects = struct('fileID', curFile, 'map', []);
        obj.userData.mapObjects.map = mmm;
      end

      fileIndeces = newInd - firstIndexPerFile(curFile) + 1;
      
      % ReUnSort the indeces.
      if ~doSort
        dataIndeces = curIndex : curIndex + length(newInd) - 1;
      else
        aux = curIndex : curIndex + length(newInd) - 1;
        dataIndeces = sortedIndex(aux);
      end
        
      % Get data from current file.
      data(dataIndeces, :) = mmm.Data.x(channels, fileIndeces)';
      curIndex = curIndex + length(newInd);
    end
    curFile = curFile+1;
  end
  
end

