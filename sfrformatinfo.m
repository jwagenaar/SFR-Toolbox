function varargout = sfrformatinfo(formatName)
  %SFRFORMATINFO  Returns optional and required attributes for format.
  %   SFRFORMATINFO('formatName') displays the information in the command window.
  %
  %   OUT = SFRFORMATINFO('formatName') returns a structure with the required
  %   and optional attributes for the given format.
  %
  %   See also SFR
  
  % Copyright (c) 2012, J.B.Wagenaar
  % This source file is subject to version 3 of the GPL license, 
  % that is bundled with this package in the file LICENSE, and is 
  % available online at http://www.gnu.org/licenses/gpl.txt
  %
  % This source file can be linked to GPL-incompatible facilities, 
  % produced or made available by MathWorks, Inc.
  
  try
    
    out = SFRepos.getattrinfo(formatName);
    
    if nargout
      varargout{1} = out;
    else
      Link1 = sprintf('<a href="matlab:help(''info%s'')">%s</a>',...
        formatName,formatName);

      
      reqAttrStr = sprintf('''%s''. ',out.requiredAttr{:});
      reqAttrStr = reqAttrStr(1:(end-2));
      
      optAttrStr = sprintf('''%s''. ',out.optionalAttr{:});
      optAttrStr = optAttrStr(1:(end-2));      
      
      display(sprintf('\n  %s Info:\n',Link1))
      display(sprintf('    Required Attributed: %s',reqAttrStr));
      display(sprintf('    Optional Attributed: %s',optAttrStr));
      display(sprintf('\n'))
    end
    
  catch ME
    isSciFi = false;
    if strncmpi(ME.identifier, 'scifilerepos', 12) || isSciFi
      if ~strncmp(ME.message,'Problem in =',12)
        problemFunc = regexp(ME.stack(1).name,'\.','split');
        problemFunc = problemFunc{end};

        ME = MException(sprintf('SCIFileRepos:%s',problemFunc),...
          sprintf('Problem in ==> %s\n%s',problemFunc, ME.message));
      end
      isSciFi = true;
    end
    if isSciFi; throwAsCaller(ME); else rethrow(ME); end;
  end   
  
end