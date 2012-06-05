function data = getBinByChannel(obj, channels, indeces)


  % Copyright (c) 2012, J.B.Wagenaar
  % This source file is subject to version 3 of the GPL license, 
  % that is bundled with this package in the file LICENSE, and is 
  % available online at http://www.gnu.org/licenses/gpl.txt
  %
  % This source file can be linked to GPL-incompatible facilities, 
  % produced or made available by MathWorks, Inc.
  
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