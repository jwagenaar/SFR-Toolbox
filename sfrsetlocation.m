function sfrsetlocation(varargin)
  %SFRSETLOCATION  Sets the environment for the SciFilesRepos class.
  %   SFRSETLOCATION(LOCID, FILENAME) sets the location of the user to LOCID (string)
  %   and loads the structures with repository roots from the file FILENAME
  %   (string).
  %
  %   SFRSETLOCATION(LOCID) will open a user interface where the user can select the
  %   XML file.
  %
  %   SFRSETLOCATION() will open a userinterface to select the XML file and request
  %   the location ID from the user in the command window.

  % Copyright (c) 2012, J.B.Wagenaar
  % This source file is subject to version 3 of the GPL license, 
  % that is bundled with this package in the file LICENSE, and is 
  % available online at http://www.gnu.org/licenses/gpl.txt
  %
  % This source file can be linked to GPL-incompatible facilities, 
  % produced or made available by MathWorks, Inc.
  
  try
    SFRcontainer.getrepos(varargin{:});
  catch ME
    if strncmp(ME.identifier, 'SCIFileRepos', 12)
      if ~strncmp(ME.message,'Problem in =',12)
        err = MException(ME.identifier,sprintf('Problem in => %s\n%s',...
          ME.stack(1).name,ME.message));
      else
        err = ME;
      end
      throwAsCaller(err);
    else
      rethrow(ME);
    end
  end
    
end