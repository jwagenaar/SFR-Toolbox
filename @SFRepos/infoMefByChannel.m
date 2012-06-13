function out = infoMefByChannel(obj, locPath, option)
  %MEFBYCHANNEL  Reads Mef file format with single file per channel.
  %
  %   The MEFBYCHANNEL file format handles mef files that
  %   have a single file for each of the channels.
  %
  %   Required attributes:
  %     none
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
  
  % Copyright (c) 2012, A.Pearce, J.B.Wagenaar 
  % This source file is subject to version 3 of the GPL license, 
  % that is bundled with this package in the file LICENSE, and is 
  % available online at http://www.gnu.org/licenses/gpl.txt
  %
  % This source file can be linked to GPL-incompatible facilities, 
  % produced or made available by MathWorks, Inc.
  %
  % Author: Allison Pearce, Litt Lab, June 2012
  %
  %
  % EXTERNAL FILE REQUIREMENTS (functions)
  % ReadMefHeaderAndIndexData.m
  % decomp_mef.mex

  
  % Required switch statement with required cases: 'attributes' and 'size'
  
  assert(nargin == 3, 'SciFileRepos:infoMethod', ...
    'Incorrect number of input arguments for infoMethod.');
  assert(exist('decomp_mef','file') == 3,'SciFileRepos:getMef',...
    'Cannot find the DECOMP_MEF mex file.');
  
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
      out.requiredAttr = {};
      out.optionalAttr = {}; % No optional attributes.

      % Find number of channels.
      nrChannels = length(obj.files);

      % Find number of samples.
      filePath = fullfile(locPath, obj.files{1});
      assert(exist(filePath,'file')==2, 'SciFileRepos:sizeBinByChannel',...
        'File does not exist.'); 

      mh = ReadMefHeaderAndIndexData(filePath);
      nrValues = mh.number_of_samples;

      out.size = [nrValues nrChannels];  
      out.format = 'int32';
         
      case 'info'
          filePath = fullfile(locPath, obj.files{1});
          assert(exist(filePath,'file')==2, 'SciFileRepos:sizeBinByChannel',...
              'File does not exist.');
          mh = ReadMefHeaderAndIndexData(filePath);
          out.recording_start_time = mh.recording_start_time; % times in us
          out.recording_end_time = mh.recording_end_time;
          out.sampling_frequency = mh.sampling_frequency;
          % can add any other data from a mef header
          
    otherwise
      error('SciFileRepos:getattr','Incorrect option: %s',option);
  end

  
end