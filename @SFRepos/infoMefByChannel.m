function out = infoMefByChannel(obj, locPath, option)
  %MEFBYCHANNEL  Reads Mef file format with single file per channel.
  %
  %   The MEFBYCHANNEL file format handles mef files that
  %   have a single file for each of the channels.
  %
  %   Required attributes:
  %     none
  %   Optional attributes:
  %     'getByTime'   Get data by time, time is set in INDECES as 
  %                   [startime endtime] in second offset from start.
  %
  %                   Example:
  %                     out = obj.data([1 10],1,'getByTime') 
  %
  %     'getByIndex'  Returns the requested indeces (Default behavior)
  %
  %     'getByBlock'  Currently not implemented.
  %
  %     'skipData'    Only returns the discontinuity matrix and no data for the
  %                   supplied indeces.
  %         
  %     'skipCheck'   Returns the data without checking whether it is continuous.
  %                   This will improve the response time.
  %
  %     'padNan'      Pads the data with Nan where it is discontinuous. This
  %                   automatically sets the 'isContinuous' flag to true.
  %       
  %                   Example:
  %                     out = obj.data([1 10000],1:4,'getByTime','padNan');
  %
  %   The data is returned as a structure instead of a matrix. The reason is
  %   that the returned indeces are not necessary continuous. The returned
  %   structure has a flag that indicates whether the returned results are
  %   continuous.
  %
  %   It also contains a 2xn matrix that contains the timestamp and the index
  %   number of where discontinuities are detected. Each column represents a
  %   continuous section. The first row contains the timestamp of the first
  %   value of the block and the second row contains the index of the first
  %   value of a block.
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
  %
  % EXTERNAL FILE REQUIREMENTS (functions)
  % ReadMefHeaderAndIndexData.m
  % decomp_mef.mex

  
  % Required switch statement with required cases: 'attributes' and 'size'
  
  assert(nargin == 3, 'SciFileRepos:infoMethod', ...
    'Incorrect number of input arguments for infoMethod.');
  assert(exist('decomp_mef','file') == 3,'SciFileRepos:getMef',...
    'Cannot find the DECOMP_MEF mex file.');
  
  requiredAttr = {};
  optionalAttr = {'getByBlock' 'skipData' ...
        'skipCheck' 'getByIndex' 'getByTime' 'padNan'}; 
  
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
      out.optionalAttr = optionalAttr; 

      % Find number of channels.
      nrChannels = length(obj.files);

      % Find number of samples.
      filePath = fullfile(locPath, obj.files{1});
      assert(exist(filePath,'file')==2, 'SciFileRepos:sizeBinByChannel',...
        sprintf('File does not exist:  %s',filePath)); 

      mh = read_mef2_header(filePath,'');
      nrValues = mh.number_of_samples;

      out.size = [nrValues nrChannels];  
      out.format = 'int32';         
    case 'info'
        filePath = fullfile(locPath, obj.files{1});
        assert(exist(filePath,'file')==2, 'SciFileRepos:sizeBinByChannel',...
            sprintf('File does not exist:  %s',filePath));

        mh = read_mef2_header(filePath,'');
        out.recording_start_time = mh.recording_start_time; % times in us
        out.recording_end_time = mh.recording_end_time;
        out.samplingFrequency = mh.sampling_frequency;
        out.numberOfBlocks = mh.number_of_index_entries;
        out.gain = mh.voltage_conversion_factor;

        % can add any other data from a mef header
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