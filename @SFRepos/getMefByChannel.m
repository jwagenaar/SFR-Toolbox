function data = getMefByChannel(obj, channels, indeces, filePath, options)
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
  
  % During the first time that the decomp_mef function is called, it will index
  % the mef file and store the indexing array in the userData of the object.
  % This will significantly speedup further requests. 

  assert(exist('decomp_mef','file') == 3,'SciFileRepos:getMef',...
    'Cannot find the DECOMP_MEF mex file.');
  

  
  if isempty(obj.userData);
    obj.userData = struct('map',cell(obj.dataInfo.size(2),1)); 
  end
  
  %Set default values
  getMethod = 'byIndex';
  skipCheck = false;
  skipData  = false;
  padNan    = false;
  if ~isempty(options)
    optNames = fieldnames(options);
    for i = 1:length(optNames)
      switch optNames{i}
        case 'getByTime'
          getMethod = 'byTime';
        case 'getByBlock'
          getMethod = 'byBlock';
        case 'getByIndex'
          getMethod = 'byIndex';
        case 'skipCheck'
          skipCheck = options.skipCheck;
          isCont = nan;
          discVecIdx = [];
        case 'skipData'
          skipData = options.skipData;
        case 'padNan'
          padNan = true;
      end
    end
  end
  % Check PADNAN requires ~skipCHECK && ~skipData
  if padNan
    assert(~skipCheck && ~skipData, ...
      'If PADNAN is used, SKIPCHECK AND SKIPDATA must be false')
  end
  
  
  % Check input argument
  lIndeces = length(indeces);
  switch getMethod
    case 'byIndex'        
      % Check that the indeces are a sorted vector with no missing indeces. 
      assert(issorted(indeces), 'SciFileRepos:getMEF',...
        'The GETMEF method only supports continuous sorted indeces.');
      assert(lIndeces == (indeces(lIndeces)-indeces(1)+1), 'SciFileRepos:getMEF',...
        'The GETMEF method only supports sorted continuous indeces.');
    case 'byTime'
      assert(length(indeces)==2, ...
        'When ''IndexByTime'', indeces should be [start stop].');
      assert(indeces(2) > indeces(1),...
        'When ''IndexByTime'', index(2) should be larger than index(1).');
    otherwise
  end
  
  data = struct(...
    'data',[], ...
    'isContinuous',1, ...
    'discontVec', [],...
    'startTime',0);
  
  
  % Iterate over each channel and read data. 
  for iChan = 1:length(channels)
    
    % Get fileName for channel.
    fileName      = fullfile(filePath, obj.files{channels(iChan)});
    
    % Get information from mef header and index
    indexArray = obj.userData(channels(iChan)).map;

    % If Map is not previously loaded, load map and store map in temporary
    % location. 
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
    
    
    % Get the values using the method determined by GETMETHOD variable.  
    switch getMethod
      case 'byIndex'
        % Set first, last-index for continuity check
        firstIndex = indeces(1);
        lastIndex = indeces(lIndeces);
        
        if ~skipData
          data.data(1:lIndeces, iChan) = decomp_mef(fileName, double(firstIndex), ...
            double(lastIndex), '', indexArray.Data.x(:)); 
        end
        
        channelMap = obj.userData(channels(iChan)).map;
        aux = channelMap.Data.x(3,:);
        
        %Get sampling frequency
        sf = subsref(obj,substruct('.','attr','.','samplingFrequency'));
        
       % -- Find First Index
       if ~skipCheck
        firstBiggerBlock = find(aux > firstIndex,1);
        timeDiff = uint64(1e6*double(firstIndex - (aux(firstBiggerBlock-1)+1))./sf); 
        
        startBlockTime = channelMap.Data.x(1,firstBiggerBlock-1);
        firstBlockTime =  channelMap.Data.x(1,1);
        data.startTime = startBlockTime + timeDiff - firstBlockTime;
       end
        
      case 'byBlock'
        error('Return by block is currently not implemented');
        
      case 'byTime'
        % Getting data by Time, indexes are assumed to be timestamps. The
        % timeindex can only have two values [startTime endTime].
        
        channelMap = obj.userData(channels(iChan)).map;
        aux = channelMap.Data.x(1,:);
        
        %Get sampling frequency
        sf = subsref(obj,substruct('.','attr','.','samplingFrequency'));
        
       % -- Find First Index
        firstBiggerBlock = find(aux > (aux(1) + uint64(indeces(1))),1);
        timeDif = aux(1) + uint64(indeces(1)) - aux(1,(firstBiggerBlock-1));
        sampleOffset = floor(double(timeDif)*(sf*1e-6));
        firstIndex = channelMap.data.x(3,(firstBiggerBlock-1)) + sampleOffset;
        
        %Check that index is not in next block. This can be the case if there is
        %missing data.
        if firstIndex >= channelMap.data.x(3,firstBiggerBlock)
          firstIndex = channelMap.data.x(3, firstBiggerBlock);
          sampleOffset = 0;
        end
        
        data.startTime = aux(1,firstBiggerBlock-1) + sampleOffset/(sf*1e-6) ...
                          - aux(1);
        
       % -- Find Last Index
        firstBiggerBlock2 = find(aux > (aux(1) + uint64(indeces(2))),1);
        if isempty(firstBiggerBlock2)
          firstBiggerBlock2 = length(aux)+1;
        end
        
        timeDif = aux(1) + uint64(indeces(2)) - aux(1,(firstBiggerBlock2-1));
        sampleOffset = ceil(double(timeDif)*(sf*1e-6));
        lastIndex = channelMap.data.x(3,(firstBiggerBlock2-1)) + sampleOffset;
        
        %Check that Last index is not larger than vector
        if lastIndex > subsref(obj,substruct('.','attr','.','size','()',{1}));
         error('Index out of bounds');
        end
        
       % -- Get Data
        if ~skipData
          data.data(:,iChan) = decomp_mef(fileName, double(firstIndex), ...
            double(lastIndex), '', indexArray.Data.x(:)); 
        end
        
    end
    
    % Check continuity during first call. Assumes all channels are continuous
    % for a given time. Channels cannot be discontinuous in different times. 
    if ~skipCheck && iChan == 1
      % Check continuous
      firstBlock = find( (firstIndex-1) < indexArray.Data.x(3,:),1) - 1;
      lastBlock  = find( (lastIndex-1) < indexArray.Data.x(3,:),1) -1;

      % Iterate over included blocks and get 'continuous' flags.
      discVector = zeros(2, 10);
      
      % Make sure the first column in discVector corresponds with first sample
      % in returned result.
      FB = indexArray.Data.x([1 3],firstBlock);
      
      startTime = ((firstIndex-1)-FB(2))*(sf*1e-6) + FB(1);
      discVector(:,1) = [startTime firstIndex-1];
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

        curIsCont = ~fread(fid,1,'uint8');
        isCont = isCont && curIsCont;
        if ~curIsCont
          discVecIdx = discVecIdx +1;
          discVector(1,discVecIdx)  = indexArray.Data.x(1, iBlock); 
          discVector(2,discVecIdx)  = indexArray.Data.x(3, iBlock) +1; 
        end
      end
      data.isContinuous =  isCont;
      fclose(fid);  
      
      discVector = discVector(:,1:discVecIdx);      
    end

  end
  
  % PADNAN pad discontinuities with NAN if requested.
  if padNan && ~data.isContinuous
    data.isContinuous = true;
    
    % Find final length of data:
    di    = discVector;
    diSz  = size(di,2);
    sf    = subsref(obj,substruct('.','attr','.','samplingFrequency')); 

    % Find the total number of NaN's that need to be inserted.
    missingIdx = ceil(diSz+((di(1,diSz)-di(1,1))*(sf*1e-6)) + (di(2,1)) - di(2,diSz));

    % Pad data array
    data.data = [data.data ;nan(missingIdx,length(channels))];    

    % Move data and replace Nan.
    newLindeces = lIndeces;
    for ii = 2:diSz
      missingIdx = ceil(((di(1,ii)-di(1,ii-1))*(sf*1e-6)) + (di(2,ii-1)) - di(2,ii));

      data.data(di(2,ii)+missingIdx:newLindeces+missingIdx,:) = ...
        data.data(di(2,ii):newLindeces,:);
      data.data(di(2,ii):di(2,ii)+missingIdx-1,:) = nan;

      di(2,ii:diSz) = di(2,ii:diSz) + missingIdx;
      newLindeces = newLindeces + missingIdx;
    end

    discVector = di;
  end
  
  % Add discont vector to output.
  if discVecIdx
    data.discontVec = discVector;      
  end 

  
end


