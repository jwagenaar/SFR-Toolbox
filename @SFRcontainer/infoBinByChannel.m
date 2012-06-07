function [sizeInfo format, requiredAttr, optionalAttr] = infoBinByChannel(obj)
  %SIZEBINBYCHANNEL returns the size of the data in the repos.
  %
  %   This method should return a 1x2 numeric vector where the first index is
  %   the number of channels and the second index is the number of values per
  %   channel.
  
  requiredAttr = {};
  optionalAttr = {'decimation'};
  
  % Find number of channels.
  nrChannels = length(obj.files);
  
  % Find number of samples.
  curRoot = obj.getrepos();
  curRoot = curRoot.(obj.rootId);
  format = obj.typeAttr.Format;
  filePath = fullfile(curRoot, obj.subPath, obj.files{1});
  assert(exist(filePath,'file')==2, 'SciFileRepos:sizeBinByChannel',...
    'File does not exist.');
  
  mmm = memmapfile(filePath,'Format',format,'Writable',false); 
  nrValues = size(mmm.Data,1);
  
  sizeInfo = [nrValues nrChannels];  
  
end