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
  
  % MEF natively returns data as INT32, but only utilizes the first 24 bits of
  % data.
  

  % Check if file exists.
  assert(exist('decomp_mef','file') == 3,'SciFileRepos:getMef',...
    'Cannot find the DECOMP_MEF mex file.');
  
  assert(isa(indeces(1),'double'),...
    'The MEF reader currently only support ''double'' precision inputs');
  
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
      % Check that the indeces are a sorted vector with no missing indeces. 
      assert(issorted(indeces), 'SciFileRepos:getMEF',...
        'The GETMEF method only supports continuous sorted indeces.');
      assert(length(indeces) == (indeces(end)-indeces(1)+1), ...
        'SciFileRepos:getMEF',...
        'The GETMEF method only supports sorted continuous indeces.');
        
      % Create RawData array.
      lIndeces = length(indeces);
      rawData  = zeros(lIndeces, length(channels), 'int32');
    case 'byTime'
      assert(length(indeces) == 2, ...
        'When ''IndexByTime'', indeces should be [start stop].');
      assert(indeces(2) > indeces(1),...
        'When ''IndexByTime'', index(2) should be larger than index(1).');
      
      % Create RawData array.
      sf = subsref(obj,substruct('.','attr','.','samplingFrequency'));
      
      % Get the number of samples that you would expect based on the start
      % and end-time. Make sure that it is accurate for very large numbers.
      % The sampling frequency is estimated up to 4 digits accuracy.
      lIndeces = idivide(diff(indeces)*uint64(sf*10000), uint64(1e10), 'ceil');
      rawData  = zeros(lIndeces,length(channels), 'int32');
      
    otherwise
      error('Incorrect getMethod for GETMEFBYCHANNEL function');
  end
  
  % Define Structure that is returned.
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
        firstIndex  = double(indeces(1));
        firstIndex0 = firstIndex -1; 
        lastIndex   = double(indeces(lIndeces));
        lastIndex0  = lastIndex -1;
        
        
        if ~skipData
          rawData(1:lIndeces, iChan) = decomp_mef(fileName, firstIndex, ...
            lastIndex, '', indexArray.Data.x(:)); 
        end
        
        if ~skipCheck
          channelMap = obj.userData(channels(iChan)).map;
          iMap = double(channelMap.Data.x(3,:));

          %Get sampling frequency
          sf = subsref(obj,substruct('.','attr','.','samplingFrequency'));

          % -- Find First Index
          firstBiggerBlock = find(iMap > firstIndex0, 1);
          firstBiggerBlock0 = firstBiggerBlock -1;
          
          firstBlock = firstBiggerBlock -1;
          firstBlock0 = firstBlock - 1;
          lastBlock  = find(lastIndex0 >= iMap, 1,'last'); 
          lastBlock0 = lastBlock -1;
          
          timeDiff = 1e6*(firstIndex0 - iMap(firstBiggerBlock0))./sf; 
          timeDiff = uint64(ceil(timeDiff));
          
          startBlockTime = channelMap.Data.x(1,firstBiggerBlock0);
          firstBlockTime = channelMap.Data.x(1,1);
          data.startTime = startBlockTime + timeDiff - firstBlockTime;
        end
        
      case 'byBlock'
        error('Return by block is currently not implemented');
        
      case 'byTime'
        % Getting data by Time, indexes are assumed to be timestamps. The
        % timeindex can only have two values [startTime endTime].
        
        firstIndexTime = double(indeces(1));
        secondIndexTime = double(indeces(2));
        
        channelMap = obj.userData(channels(iChan)).map;
        iMap = double(channelMap.Data.x(1,:) - channelMap.Data.x(1,1));
        
        %Get sampling frequency
        sf = subsref(obj,substruct('.','attr','.','samplingFrequency'));
        
        % -- Find First Index
        firstBiggerBlock = find(iMap > firstIndexTime, 1);
        firstBlock = firstBiggerBlock -1;
        firstBlock0 = firstBlock - 1;
        lastBlock  = find(secondIndexTime >= iMap, 1,'last'); 
        lastBlock0 = lastBlock -1;
        
        timeDif = firstIndexTime - iMap(firstBlock);
        sampleOffset = floor(timeDif*(sf*1e-6));
        firstIndex0 = double(channelMap.data.x(3, firstBlock)) + sampleOffset;     
        firstIndex = firstIndex0 +1;
        
        
        %Check that index is not in next block. This can be the case if there is
        %missing data.
        if firstIndex >= channelMap.data.x(3, firstBiggerBlock)
          firstIndex = double(channelMap.data.x(3, firstBiggerBlock));
          sampleOffset = 0;
        end
        
        data.startTime = iMap(1,firstBlock) + sampleOffset/(sf*1e-6);
        
        
        timeDif2 = secondIndexTime - iMap(1, lastBlock);
        sampleOffset2 = ceil(timeDif2*(sf*1e-6));
        lastIndex0 = double(channelMap.data.x(3,lastBlock)) + sampleOffset2;
        lastIndex = lastIndex0 +1;
        
        %Check that Last index is not larger than vector
        if lastIndex > subsref(obj,substruct('.','attr','.','size','()',{1}));
         error('Index out of bounds');
        end
        
       % -- Get Data
        if ~skipData
          aux = decomp_mef(fileName, firstIndex, lastIndex, '', ...
            indexArray.Data.x(:)); 
          rawData(1:size(aux,1),iChan) = aux;
        end
        
    end
    
    % Check continuity during first call. Assumes all channels are continuous
    % for a given time. Channels cannot be discontinuous in different times. 
    
    if ~skipCheck && iChan == 1
      
      % Make sure the first column in discVector corresponds with first sample
      % in returned result.
      FFB = indexArray.Data.x(1, 1); % Time of first index in file.
      FB  = indexArray.Data.x([1 3], firstBlock);
      offsetIndex = firstIndex0-double(FB(2));
      offsetIndexTime = uint64(offsetIndex./(sf*1e-6));
      startTime = double(FB(1) + offsetIndexTime - FFB);

      % Get Discontinuity Vector, store in memory for future use. 
      if isempty(obj.userData(iChan).discVec)
        fid = fopen(fileName);
        fseek(fid,840,-1); 
        discOffset = fread(fid, 1, 'uint64');
        discNumber = fread(fid, 1, 'uint64');
        fseek(fid, discOffset,-1);
        discVec0 = fread(fid, discNumber, 'uint64');
        obj.userData(iChan).discVec = discVec0;
        fclose(fid);  
      else
        discVec0 = obj.userData(iChan).discVec;
      end

      % If found discontinuities make discVector for results.
      isDisc = discVec0 > firstBlock0  & discVec0 <= lastBlock0;
      
      % Reference data with respect to beginning file. Time of first sample in
      % file is t=0;
      discVector = [startTime ;1]; 
      
      if any (isDisc)
        data.isContinuous = false;
        discBlocks0 = discVec0(isDisc);
        discVector(2,2:length(discBlocks0)+1) = ...
          double(indexArray.Data.x(3, discBlocks0+1)+1)- firstIndex0;
        discVector(1,2:length(discBlocks0)+1)  = ...
          double(indexArray.Data.x(1, discBlocks0+1) - FFB);
      end
    end
  end
  
  % PADNAN pad discontinuities with NAN if requested. This automatically
  % casts the results as Doubles (otherwise NAN is not NAN)
  if padNan && ~data.isContinuous
    data.isContinuous = true;
    
    % Find final length of data:
    di    = discVector;
    diSz  = size(di,2);
    sf    = subsref(obj,substruct('.','attr','.','samplingFrequency')); 

    % Find the total number of NaN's that need to be inserted.
    totalIndex = ceil( (di(1,diSz)-di(1,1))*(sf*1e-6) );
    missingIdx = diSz +  totalIndex - ( di(2,diSz) - di(2,1) );

    %Limit Maximum padding
    if missingIdx > diSz*1e5;
      missingIdx = diSz*1e5;
    end
    
    % Pad data array
    newLindeces = size(rawData,1);
    rawData = [double(rawData) ;NaN(missingIdx,length(channels),'double')];    

    % Move data and replace Nan.
    for ii = 2:diSz
      totalBlockIndex = ceil((di(1,ii)-di(1,1)) * (sf*1e-6));
      missingBlockIdx = totalBlockIndex - (di(2,ii) - di(2,1));
      
      if missingBlockIdx > 1e5
        fprintf(2, 'Maximum padding for block: %03.0f',ii+1);
        missingBlockIdx = 1e5;
      end

      % Shift data and replace with NaN's
      rawData = shiftdata(rawData, di(2,ii), missingBlockIdx, newLindeces);

      di(2,ii:diSz) = di(2,ii:diSz) + missingBlockIdx;
      newLindeces   = newLindeces + missingBlockIdx;
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
