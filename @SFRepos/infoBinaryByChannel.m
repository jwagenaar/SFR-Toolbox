function out = infoBinaryByChannel(obj, locPath, option)
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
  %
  %   The 'init' option is called by the constructor method of the SFREPOS
  %   class and should return a structure with the properties: 'requiredAttr',
  %   'optionalAttr', 'size' and 'format'.
  %
  %   The 'info' option is called when the user accesses the 'attr' property of
  %   the object and should return any other information that is available in
  %   the files associated with this object.
  %
  %   NOTE: You do not have to include the 'size' and 'format' attributes in the
  %   structure that is returned by the 'info' option. These attributes are
  %   automatically added by the toolbox.
  
  % Required switch statement with required cases: 'attributes' and 'size'
  
  assert(nargin == 3, 'SciFileRepos:infoMethod', ...
    'Incorrect number of input arguments for infoMethod.');
  
  requiredAttr = {'Format' 'SwapBytes'};
  optionalAttr = {};
  
  switch option
    case 'init'

      % Required output structure for case 'init'.
      out = struct(...
        'requiredAttr', [], ...
        'optionalAttr', [], ...
        'size', [], ...
        'format', [] ...
        );

      % Set required and optional attributes.
      out.requiredAttr = requiredAttr;
      out.optionalAttr = optionalAttr; % No optional attributes.

      % Find number of channels.
      nrChannels = length(obj.files);

      % Find number of samples.
      format = obj.typeAttr.Format;
      filePath = fullfile(locPath, obj.files{1});

      assert(exist(filePath,'file')==2, 'SciFileRepos:sizeBinByChannel',...
        'File does not exist.');

      mmm = memmapfile(filePath,'Format',format,'Writable',false); 
      nrValues = size(mmm.Data,1);

      out.size = [nrValues nrChannels];  
      out.format = obj.typeAttr.Format;      
    case 'info'
      out = []; %no additional attributes for this file type.
    case 'attr'
      out = struct(...
        'reqAttr', [], ...
        'optAttr', []);
      out.reqAttr = requiredAttr;
      out.optAttr = optionalAttr;
      
    otherwise
      error('SciFileRepos:getattr','Incorrect option: %s',option);
  end
  
end