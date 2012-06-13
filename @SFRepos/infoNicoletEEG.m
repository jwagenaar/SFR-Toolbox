function out = infoNicoletEEG(obj, locPath, option)
  %NICOLETEEG  Reads files from the Nicolet .eeg fileformat.
  %
  %   The NicoletEEG format consists of one vector with channels in
  %   sequence, repeating for every individule sample. 
  %
  %   Required attributes:
  %     none
  %   Optional attributes:
  %     none
  
  % Copyright (c) 2012, A.Martin, J.B.Wagenaar 
  % This source file is subject to version 3 of the GPL license, 
  % that is bundled with this package in the file LICENSE, and is 
  % available online at http://www.gnu.org/licenses/gpl.txt
  %
  % This source file can be linked to GPL-incompatible facilities, 
  % produced or made available by MathWorks, Inc.
  
  % Required switch statement with required cases: 'attributes' and 'size'
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
      
      out.requiredAttr = {}; % No required attributes.
      out.optionalAttr = {}; % No optional attributes.
      
      f_name = fullfile(locPath, obj.files{1});
      eeg = f_name(end-2:end);
      if strcmp(eeg,'eeg') == 1
        f_name(end-2:end) = 'bni';        
      elseif strcmp(eeg,'eeg') == 0 
        f_name(end+1:end+4) = '.bni';        
      end
      
      % Open firest BNI file.
      fid = fopen(f_name);
      H = fread(fid);
      header = char(H');
      
      % Find Number of channels
      l = strfind(header, 'NchanFile =');
      nchan = str2double(header(l+11:l+14));
      fclose(fid);

      % For loop to add samples from each file for total samples    
      samples_per_chan = zeros(1,size(obj.files, 1));
      for i = 1:length(obj.files)
        f_name = fullfile(locPath, obj.files{i});
        
        assert(exist(f_name,'file') == 2, ...
          'SciFileRepos:infoNicoletEEG', 'File not found'); 
        
        fid=fopen(f_name);
        fseek(fid,0,1);
        total_bytes=ftell(fid);
        fclose(fid);
        samples=total_bytes/2;
        samples_per_chan(i)=samples/nchan;     
      end
      Total_samples = sum(samples_per_chan);
      
      out.size = [Total_samples, nchan];     
      out.format = 'int16';    

    case 'info'
      % Required output structure for case 'info'.
      out = struct();
        
      f_name = fullfile(locPath, obj.files{1});
      eeg = f_name(end-2:end);
      if strcmp(eeg,'eeg') == 1
        f_name(end-2:end) = 'bni';        
      elseif strcmp(eeg,'eeg') == 0 
        f_name(end+1:end+4) = '.bni';        
      end
      fid = fopen(f_name);

      expressn =  '(?<prop>\w+)\s+=\s+(?<value>[A-Za-z_0-9].*)';
      tline = fgetl(fid);
      while ischar(tline)
        names = regexp(tline, expressn, 'names');
        if ~isempty(names)
          switch names.prop
            case {'Filename' 'Date' 'Time' 'NextFile' 'referring_physician'}
              % do not add.
            case 'MontageRaw'
              % Create chNames cell array.
              out.chNames = regexp(names.value,',','split');
              if isempty(out.chNames{end})
                out.chNames(end) = [];
              end
               
            otherwise
              out.(names.prop) = names.value;
          end
        end
        tline = fgetl(fid);
      end
      
      fclose(fid);
      
    otherwise
      error('SciFileRepos:getattr','Incorrect option: %s',option);
  end
end