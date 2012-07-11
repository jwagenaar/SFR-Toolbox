function data = getMefByChannel(obj, channels, indeces, filePath, options)
  %GETMEFBYCHANNEL See infoBinaryByChannel

  
  % Optional arguments: 'forceContinuous' 'indexByBlock'
  
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
  
  % Check that the indeces are a sorted vector with no missing indeces. 
  assert(issorted(indeces), 'SciFileRepos:getMEF',...
    'The GETMEF method only supports continuous sorted indeces.');
  lIndeces = length(indeces);
  assert(lIndeces == (indeces(lIndeces)-indeces(1)+1), 'SciFileRepos:getMEF',...
    'The GETMEF method only supports sorted continuous indeces.');
  
  if isempty(obj.userData);
    obj.userData = struct('map',cell(obj.dataInfo.size(2),1)); 
  end
  
  %Set default values
  getMethod = 'byIndex';
  skipCheck = false;
  skipData = false;
  if ~isempty(options)
    optNames = fieldnames(options);
    for i = 1:length(optNames)
      switch optNames{i}
        case 'getByBlock'
          getMethod = 'byBlock';
        case 'getByIndex'
          getMethod = 'byIndex';
        case 'skipCheck'
          skipCheck = options.skipCheck;
        case 'skipData'
          skipData = options.skipData;
      end
    end
  end
  

  for iChan = 1:length(channels)
    
    fileName      = fullfile(filePath, obj.files{channels(iChan)});
    
    % Get information from mef header and index
    indexArray = obj.userData(channels(iChan)).map;

    if isempty(indexArray)

      % Start Timer for showing progress for reading header.
      fprintf('Indexing MEF file, channel %i... (only during first call)', ...
        channels(iChan));

      [~, indexMap] = decomp_mef(fileName, 1, 1, ''); %Get indexMap

      randChar = [char(48:57) char(65:90) char(97:122)];
      tempFileName = sprintf('tempMEFheader_%s.bin',randChar(1 + round(61*rand(10,1))));

      tempFileName = fullfile(tempdir, tempFileName);
      fid = fopen(tempFileName,'w');
      fwrite(fid, indexMap,'uint64');
      fclose(fid);

      obj.userData(channels(iChan)).map = memmapfile(tempFileName, ...
        'Format', {'uint64' [3 length(indexMap)/3] ,'x'});

      fprintf(' ...done.\n');  
      indexArray = obj.userData(channels(iChan)).map;
    end
      
    switch getMethod
      case 'byIndex'
        data = struct('data',[],...
          'isContinous',false, 'discontVec', []);
        if ~skipCheck
          % Check continuous
          firstBlock = find( (indeces(1)-1) < indexArray.Data.x(3,:),1) - 1;
          lastBlock  = find( (indeces(lIndeces)-1) < indexArray.Data.x(3,:),1) -1;

          data.firstBlock = firstBlock;
          data.lastBlock = lastBlock;

          % Iterate over included blocks and get 'continuous' flags.
          discVector = zeros(2, 10);
          discVector(:,1) = indexArray.Data.x([1 3],firstBlock);
          discVecIdx = 1;
          isCont = true;
          fid = fopen(fileName);
          bytesSkip = sum([4 4 8 4 4 6]);
          for iBlock = (firstBlock+1) : lastBlock
            skip = int64(indexArray.Data.x(2,iBlock) + bytesSkip);
            status = fseek(fid, skip, 'bof');
            if status < 0
              display(ferror(fid));
            end

            isCont = ~fread(fid,1,'uint8');
            if ~isCont
              discVecIdx = discVecIdx +1;
              discVector(:,discVecIdx)  = indexArray.Data.x(1:2,iBlock); 
            end
          end
          if discVecIdx
            data.discontVec = discVector(:,1:discVecIdx);          
          end
          
          if ~skipData
            data.data(:,iChan) = decomp_mef(fileName, indeces(1), ...
              indeces(lIndeces), '', indexArray.Data.x(:)); 
          end

          data.isContinous = isCont;
          
          fclose(fid);          
        end
      case 'byBlock'
        error('Return by block is currently not implemented');
        
     end
    
 

  end


end


