function data = getMefByChannel(obj, channels, indices, filePath, options)
  %GETMEFBYCHANNEL See infoBinaryByChannel

  
  % The 'discontVec' property contains one column for each edge of the
  % datasegments, starting with the firstValue of the returned vector, then
  % one column for each discontinuity and ending with the last data value.
  % A continuous dataset therefore has a 2x2 discontVec array containing
  % the first and last value of the returned vector/array.
  
  % In 'getByIndex' mode, the first index is based on the index in the MEF
  % file. Therefore, there will be no padding with NaN's at the beginning
  % of the returned vector. It is possible that the end of the returned
  % vector contains NaN's because the returned vector is trimmed to the
  % requested length.
    
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
  
  % MEF natively returns data as INT32, but only utilizes the first 24 bits of
  % data.
  

  % Check if file exists.
  assert(exist('decomp_mef','file') == 3,'SciFileRepos:getMef',...
    'Cannot find the DECOMP_MEF mex file.');
  
  if isinteger(indices)
    indices = double(indices);
  elseif ~isfloat(indices)
    assert(isa(indices(1),'double'),...
      'The MEF reader currently only support ''double'' precision inputs');
  end
  
  % Pointers to the header memmapfiles are located in the object. If they are
  % not present, create the memmapfile-pointer structure.
  if isempty(obj.userData);
    obj.userData = struct('map',cell(obj.dataInfo.size(2),1),...
      'discVec',[]); 
  end
  
  % Set default values
  getMethod = 'byIndex';
  skipCheck = false;
  skipData  = false;
  padNan    = false;
  priorNanVec = [];
  finalNanVec = [];
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
  
  % Check input argument and pre-alloc data matrix
  switch getMethod
    case 'byIndex'        
      % Check that the indices are a sorted vector with no missing indices. 
      assert(issorted(indices), 'SciFileRepos:getMEF',...
        'The GETMEF method only supports continuous sorted indices.');
      assert(length(indices) == (indices(end)-indices(1)+1), ...
        'SciFileRepos:getMEF',...
        'The GETMEF method only supports sorted continuous indices.');
        
      % Create RawData array.
      lIndeces = length(indices);
      rawData  = zeros(lIndeces, length(channels), 'int32');
    case 'byTime'
      assert(length(indices) == 2, ...
        'When ''IndexByTime'', indices should be [start stop].');
      assert(indices(2) > indices(1),...
        'When ''IndexByTime'', index(2) should be larger than index(1).');
      
      % Create RawData array.
      sf = subsref(obj,substruct('.','attr','.','samplingFrequency'));
      
      % Get the number of samples that you would expect based on the start
      % and end-time. 
      lIndeces = ceil((diff(indices)*sf)./1e6);
      rawData  = nan(lIndeces,length(channels), 'double');
      
    otherwise
      error('Incorrect getMethod for GETMEFBYCHANNEL function');
  end
  
  % Define Structure that is returned.
  data = struct(...
    'data',[], ...
    'isContinuous',1, ...
    'discontVec', [],...
    'startTime',nan);
  
  
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
      tempFileName = sprintf('tmpMEFheader_%s.bin', ...
        randChar(1 + round(61*rand(10,1))));

      tempFileName = fullfile(tempdir, tempFileName);
      fid = fopen(tempFileName, 'w');
      fwrite(fid, indexMap, 'uint64');
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
        firstIndex  = double(indices(1));
        firstIndex0 = firstIndex -1; 
        lastIndex   = double(indices(lIndeces));
        lastIndex0  = lastIndex -1;
        
        % Get Data if data is not skipped.
        if ~skipData
%           display(sprintf('start: %i  end: %i',firstIndex, lastIndex));

          rawData(1:lIndeces, iChan) = decomp_mef(fileName, firstIndex, ...
            lastIndex, '', indexArray.Data.x(:)); 
        end
        
        % Prepare continuity-check if not skipped.
        if ~skipCheck
          channelMap = obj.userData(channels(iChan)).map;

          % Get sampling frequency
          sf = subsref(obj,substruct('.','attr','.','samplingFrequency'));

          % Find First Index
          firstBiggerBlock  = find(channelMap.Data.x(3,:) > uint64(firstIndex0), 1);
          firstBiggerBlock0 = firstBiggerBlock -1;
          
          firstBlock  = firstBiggerBlock -1;
          lastBlock   = find(uint64(lastIndex0) >= channelMap.Data.x(3,:), 1,'last'); 
          
          timeDiff = 1e6*(firstIndex0 - channelMap.Data.x(3, firstBiggerBlock0))./sf; 
          timeDiff = double(timeDiff);
          
          startBlockTime = channelMap.Data.x(1, firstBiggerBlock0);
          firstBlockTime = channelMap.Data.x(1,1);
          data.startTime = round(startBlockTime + timeDiff - firstBlockTime);
          
          firstOffset = (timeDiff*(sf*1e-6));
          
          lastTimeDiff = 1e6*(lastIndex0 - channelMap.Data.x(3,lastBlock))./sf; 
          lastTimeDiff = double(ceil(lastTimeDiff));
          lastOffset  = floor(lastTimeDiff*(sf*1e-6));
        end
        
      case 'byBlock'
        error('Return by block is currently not implemented');
        
      case 'byTime'
        % Getting data by Time, indexes are assumed to be timestamps. The
        % timeindex can only have two values [startTime endTime].
        
        firstIndexTime  = double(indices(1));
        secondIndexTime = double(indices(2));
        channelMap = obj.userData(channels(iChan)).map;
        
        %Get sampling frequency
        sf = subsref(obj,substruct('.','attr','.','samplingFrequency'));
        
        % -- Find First Index
        iMap = double(channelMap.Data.x(1,:) - channelMap.Data.x(1,1));
        
        firstBiggerBlock = find(iMap > firstIndexTime, 1);
        firstBlock  = firstBiggerBlock - 1;
        lastBlock   = find(secondIndexTime >= iMap, 1, 'last'); 
        
        timeDif       = firstIndexTime - iMap(firstBlock);
        firstOffset   = timeDif*(sf*1e-6);
        firstIndex0   = double(channelMap.data.x(3, firstBlock)) + ...
                          round(firstOffset); 
        firstIndex    = firstIndex0 + 1;
        
        
        %Check that index is not in next block. This can be the case if there is
        %missing data.
        if firstIndex0 >= channelMap.data.x(3, firstBiggerBlock)
          firstIndex0 = double(channelMap.data.x(3, firstBiggerBlock));
          firstIndex  = firstIndex0 + 1; 
          firstBlock = firstBlock+1;
          
          % FirstOffset will be a negative number
          firstOffset = -((iMap(firstBiggerBlock) - firstIndexTime) * (sf*1e-6));
          
          % Create vector of Nans that should be added prior to data.
          priorNanVec = nan(round(abs(firstOffset)), 1);
        end
        
        data.startTime = round(iMap(firstBlock) + firstOffset/(sf*1e-6));
       
        timeDif2      = secondIndexTime - iMap(lastBlock);
        lastOffset    = timeDif2 * (sf*1e-6);
        lastIndex0    = double(channelMap.data.x(3,lastBlock)) + ...
                          round(lastOffset);
        lastIndex     = lastIndex0 +1;
        
        ll = channelMap.data.x(3, lastBlock + 1);
        if lastIndex0 >= ll
          % Do not get any indices that are past last block.
          lastIndex0 = double(ll - 1);
          lastIndex = lastIndex0 + 1;
          finalNanVec = nan( ll - lastIndex0,1);
        end
        
        %Check that Last index is not larger than vector
        if lastIndex > subsref(obj,substruct('.','attr','.','size','()',{1}));
         error('Index out of bounds');
        end
        
       % -- Get Data
        % DecompMEF is 1 based indexing.
        if firstIndex < lastIndex && ~skipData
%           display(sprintf('start: %i  end: %i',firstIndex, lastIndex));
          aux = decomp_mef(fileName, firstIndex, lastIndex, '', ...
            indexArray.Data.x(:)); 
        else 
          aux = [];
        end
                
        if padNan
          lData = length(priorNanVec)+size(aux,1) + length(finalNanVec);
          rawData(1:lData,iChan) = [priorNanVec; double(aux); finalNanVec];
        else
          lData = size(aux,1);
          rawData(1:lData,iChan) = aux;
        end
                
    end    
    % Prior defined: rawData, firstOffset, lastOffset,
    % 
    
    % Check continuity during first call. Assumes all channels are continuous
    % for a given time. Channels cannot be discontinuous in different times. 
    if ~skipCheck && iChan == 1
      
      % Make sure the first column in discVector corresponds with first sample
      % in returned result.
      FFB = indexArray.Data.x(1, 1); % Time of first index in file.
      FB  = indexArray.Data.x([1 3], firstBlock);
      offsetIndexTime = double(firstOffset./(sf*1e-6));
      startTime = double(FB(1) + offsetIndexTime - FFB);
      
      LB  = indexArray.Data.x([1 3], lastBlock);
      offsetLastIndexTime = uint64(lastOffset./(sf*1e-6));
      endTime = double(LB(1) + offsetLastIndexTime - FFB);

      % Get Discontinuity Vector, store in memory for future use. 
      if isempty(obj.userData(iChan).discVec)
        fid = fopen(fileName);
        fseek(fid,840,-1); 
        discOffset = fread(fid, 1, 'uint64');
        discNumber = fread(fid, 1, 'uint64');
        fseek(fid, discOffset,-1);
        discVec = fread(fid, discNumber, 'uint64');
        obj.userData(iChan).discVec = discVec;
        fclose(fid);  
      else
        discVec = obj.userData(iChan).discVec;
      end

      % If found discontinuities make discVector for results.
      isDisc = discVec > firstBlock  & discVec <= lastBlock;
      
      % Reference data with respect to beginning file. Time of first sample in
      % file is t = 0;
      discVector = [startTime ; 1]; 
      
      % The values in the DiscVec are 1-based. 
      if any (isDisc)
        data.isContinuous = false;
        discBlocks = discVec(isDisc);
        discVector(2,2:length(discBlocks)+1) = length(priorNanVec) +...
          double(indexArray.Data.x(3, discBlocks))- firstIndex0 + 1;
        discVector(1,2:length(discBlocks)+1)  = ...
          double(indexArray.Data.x(1, discBlocks) - FFB);
      end
      
      % Put last value as last column of discontvec
      discVector = [discVector [endTime ; (lastIndex- firstIndex +1)]]; %#ok<AGROW>
    end
    
      
  end
  
  % PADNAN pad discontinuities with NAN if requested. This automatically
  % casts the results as doubles (otherwise NAN is not NAN)
  if padNan && ~data.isContinuous
    
    % Find final length of data:
    di    = discVector;
    diSz  = size(di,2);
    sf    = subsref(obj,substruct('.','attr','.','samplingFrequency')); 

    % Find the total number of NaN's that need to be inserted.
    totalIndex = ceil( (di(1,diSz) - di(1,1)) * (sf*1e-6) );
    missingIdx = diSz +  totalIndex - ( di(2,diSz) - di(2,1) );
   
    % Pad data array with NaN's.
    newLindices  = size(rawData, 1);
    paddedNanVec = NaN(missingIdx, length(channels), 'double');
    rawData = [double(rawData) ; paddedNanVec];   

    % Move data and replace Nan. Skip last index in di
    for ii = 2:(diSz-1)
      totalBlockIndex = ceil((di(1,ii)-di(1,1)) * (sf*1e-6));
      missingBlockIdx = totalBlockIndex - (di(2,ii) - di(2,1));

      % Shift data and replace with NaN's
      rawData = shiftdata(rawData, di(2,ii), missingBlockIdx, newLindices);

      di(2,ii:diSz) = di(2,ii:diSz) + missingBlockIdx;
      newLindices   = newLindices  + missingBlockIdx;
    end
    
    % Truncate unwanted indices
    switch getMethod
      case 'byIndex'
      case 'byTime'
    end
    
    discVector = di;
  end
  

  
  data.data = rawData;
  data.discontVec = discVector;      
 
end

%Sub-routines
function data = shiftdata(data, index, shift, datalength)
    data(index + shift:datalength + shift,:) = ...
        data(index:datalength,:);
    data(index:index+shift-1,:) = NaN;
end
