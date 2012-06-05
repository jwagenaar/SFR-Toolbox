function sfrsetroot(varargin)
  %SFRSETROOT  Sets the environment for the SciFilesRepos class.
  %   SFRROOT(LOCID, FILENAME) sets the location of the user to LOCID (string)
  %   and loads the structures with repository roots from the file FILENAME
  %   (string).
  %
  %   SFRSETROOT(LOCID) will open a user interface where the user can select the
  %   XML file.
  %
  %   SFRSETROOT() will open a userinterface to select the XML file and request
  %   the location ID from the user in the command window.

  % Copyright (c) 2012, J.B.Wagenaar
  % This source file is subject to version 3 of the GPL license, 
  % that is bundled with this package in the file LICENSE, and is 
  % available online at http://www.gnu.org/licenses/gpl.txt
  %
  % This source file can be linked to GPL-incompatible facilities, 
  % produced or made available by MathWorks, Inc.
  
  SCIFilesRepos.getrepos(varargin{:})

end