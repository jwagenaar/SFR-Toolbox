function data = getBinByChannel(obj, channels, indeces)
      
  
  % Check attributes
  fNames = fieldnames(obj.typeAttr);
  assert(strcmp(fNames,'Format'), ...
    'TypeAttr property must contain a field for ''Format'' for this type'); 

  format = obj.typeAttr.Format;
  
  data = zeros(length(indeces),length(channels),format);

  curRoot = obj.getrepos();
  curRoot = curRoot.(obj.rootId);
  
  for iChan = 1: length(channels)
    path = fullfile(curRoot, obj.subPath, obj.files{iChan});
    
    % See if the memmapfile is already cached.
    if ~isempty(obj.userData)
      cachedMaps = [obj.userData.chanIdx];
      index = find(cachedMaps==channels(iChan),1);
      if ~isempty(index)
        mmm = obj.userData(index).chanMaps;
      else
        mmm = memmapfile(path,'Format',format,'Writable',false); 
        
        obj.userData(end+1).chanIdx = channels(iChan);
        obj.userData(end).chanMaps = mmm;
      end
    else
      mmm = memmapfile(path,'Format',format,'Writable',false);
      mStruct = struct('chanIdx', channels(iChan), 'chanMaps',[]);
      mStruct.chanMaps = mmm;
      obj.userData = mStruct;
    end
        
    % Get the data.
    data(:,iChan) = swapbytes(mmm.data(indeces));
  end

end