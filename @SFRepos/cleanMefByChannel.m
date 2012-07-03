function cleanMefByChannel(obj)
  % CLEANMEFBYCHANNEL  See infoMefByChannel
  
  
  % Delete the temporary files that contain the indexing information for the mef
  % files associated with this object.
  if ~isempty(obj.userData)
    for i = 1: length(obj.userData)
      if ~isempty(obj.userData(i).map)
        try
          delete(obj.userData(i).map.Filename);
        catch ME %#ok<NASGU>
          fprintf(2, 'Unable to delete temporary file: %s\n', ...
            obj.userData(i).map.Filename);
        end
      end
    end
  end
  
end