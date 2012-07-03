function out = infoTemplate(obj, locPath, option)
  %INFOTEMPLATE  Short one-sentence summary of file-type.
  %
  %   Additional information.
    
  assert(nargin == 3, 'SciFileRepos:infoMethod', ...
    'Incorrect number of input arguments for infoMethod.');
  
  switch option
    case 'init'
      % Required output structure for case 'init'.
      out = struct(...
        'requiredAttr', [], ...
        'optionalAttr', [], ...
        'size', [], ...
        'format', [] ...
        );

      % -- Set the contents of the out structure here --
      % ADD CONTENT
      
    case 'info'
      out = struct([]);       
      % -- Set the contents of the out structure here --
      % ADD CONTENT
      
    otherwise
      error('SciFileRepos:getattr','Incorrect option: %s', option);
  end
end