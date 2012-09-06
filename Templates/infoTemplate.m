function out = infoTemplate(obj, locPath, option)
  %INFOTEMPLATE  Short one-sentence summary of file-type.
  %
  %   Additional information.
  
  assert(nargin == 3, 'SciFileRepos:infoMethod', ...
    'Incorrect number of input arguments for infoMethod.');
  
  
  % -- Set the required and optional getOptions here --
  requiredAttr = {};
  optionalAttr = {};
  
  
  switch option
    case 'init'
      % -- -- Don't change this section -- -- 
      out = struct(...
        'requiredAttr', [], ...
        'optionalAttr', [], ...
        'size', [], ...
        'format', [] ...
        );

      out.requiredAttr = requiredAttr; 
      out.optionalAttr = optionalAttr; 
      % -- -- -- -- -- -- -- -- -- -- -- -- -

      % Set the contents of the out structure here --
      % ADD CONTENT
      
    case 'info'
      out = struct([]);       
      
      % -- Set the contents of the out structure here --
      % 
      % Here, you should include code that reads out the header information of
      % the raw data-files.
      %
      % ADD CONTENT
    
    case 'attr'
      % -- -- Don't change this section -- -- 
      % It is used to return the getOptions in various
      % internal SFR-methods.
      out = struct(...
        'reqAttr', [], ...
        'optAttr', []);
      out.reqAttr = requiredAttr;
      out.optAttr = optionalAttr;  
      % -- -- -- -- -- -- -- -- -- -- -- -- -
    otherwise
      error('SciFileRepos:getattr','Incorrect option: %s', option);
  end
end