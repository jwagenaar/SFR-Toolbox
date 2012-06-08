function out = infoBinByChannel(obj, filePath, option)
  %SIZEBINBYCHANNEL returns the size of the data in the repos.
  %
  %   This method should return a 1x2 numeric vector where the first index is
  %   the number of channels and the second index is the number of values per
  %   channel.
  
  % Required switch statement with required cases: 'attributes' and 'size'
  switch option
    case 'attributes'
      % Required output structure for case 'attributes'.
      out = struct('requiredAttr',[],'optionalAttr',[]);
      
      out.requiredAttr = {'Format'};
      out.optionalAttr = {'decimation'}; 
      
    case 'size'
      % Required output structure for case 'size'.
      out = struct('size',[],'format',[]);
      
      % Find number of channels.
      nrChannels = length(obj.files);

      % Find number of samples.
      format = obj.typeAttr.Format;
      fileName = fullfile(filePath, obj.files{1});
      
      assert(exist(fileName,'file')==2, 'SciFileRepos:sizeBinByChannel',...
        'File does not exist.');

      mmm = memmapfile(fileName,'Format',format,'Writable',false); 
      nrValues = size(mmm.Data,1);

      out.size = [nrValues nrChannels];  
      out.format = obj.typeAttr.Format;
    otherwise
      out = [];
  end
  
end