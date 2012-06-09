function out = infoBinaryByChannel(obj, filePath, option)
  %BINARYBYCHANNEL  Flat Binary file format with single file per channel.
  %
  %   The BINARYBYCHANNEL format handles flat binary files with no header that
  %   have a single file for each of the channels.
  %
  %   Required attributes:
  %     'Format':   This string indicates the class of the values in the file.
  %                 Set this to 'double', 'single', 'uint16' or any other
  %                 default type of data.
  %     'SwapBytes':This Boolean determines whether the bytes in the file should
  %                 be swapped. This is sometimes necessary depending on the
  %                 platform that was used to save the data.
  %   Optional attributes:
  %     none
  
  
  % Required switch statement with required cases: 'attributes' and 'size'
  switch option
    case 'attributes'
      % Required output structure for case 'attributes'.
      out = struct('requiredAttr',[],'optionalAttr',[]);
      
      out.requiredAttr = {'Format' 'SwapBytes'};
      out.optionalAttr = {}; % No optional attributes.
      
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