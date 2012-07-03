classdef SFRepos < dynamicprops
  %SFREPOS  Scientific File Repository Container
  %   This class is used to package a set of files and provide standardized
  %   syntax for accessing data from these files. The contents of an object of
  %   this class defines the file-type, the file location and other attributes
  %   associated with a set of data-files.
  %
  %   SFREPOS(TYPE, ROOTID, SUBPATH, FILES) creates a SFRepos object
  %   that handles files of a specific TYPE. 
  %     
  %     TYPE is a string that identifies the type and should match available
  %     specific GET- and ATTR-methods (see below).
  %     
  %     ROOTID is a string that identifies the repository location. The ROOTID
  %     should be matched with one of the location tags in the location XML
  %     file.
  %
  %     SUBPATH is the location of the files with respect to the repository
  %     location that is specified in the XML-file under the tag ROOTID.
  %
  %     FILES is a 1D or 2D cell array of filenames of the raw data. There are 3
  %     scenarios that are possible:
  %       1) Separate by channel:  The cell array should be a 1D vector of
  %       cells. Each cell contains the filename associated with the channel
  %       index for that cell.
  %          
  %       2) Separate by block:  The cell array should be a 1D vector of
  %       cells. Each cell contains the filename associated with a block of
  %       data, where each block contains all channels during a subset of time.
  %
  %       3) Separate by channel and block:  The cell array should be a 2D array
  %       of cells. Each row contains filenames associated with data for a
  %       single channel and the columns are associated with a differnt block of
  %       data for that single channel.
  %
  %   SFREPOS(..., TYPEATTR) The TYPEATTR input can be added to specify
  %   attributes that are required by the method that loads the data from the
  %   referenced data files. TYPEATTR should be a 1D cell array with alternating
  %   'attributeName' and 'attributeValue'.
  %
  %     For example: TYPEATTR = {'dataClass' 'double'}
  %
  %   SFREPOS(..., TYPEATTR, DATAATTR) The DATAATTR method can be used to
  %   add properties and associated values to the current object. The DATAATTR
  %   input should be a 1D cell array with alternating 'attributeName' and
  %   'attributeValue'.
  %
  %   Some filetypes will contain meta-data information inside the file while
  %   other filetypes do not have this information embedded. In this case,
  %   meta-data assiated with the data in the files, such as channel names can
  %   be added directly to the object as an attribute. 
  %
  %     For example: DATAATTR = {'chNames' {'Ch1' 'Ch2' 'Ch3' 'Ch4'}}
  %
  %
  %   See also: ADDATTR GETDATA CLEANUP

  
  % Copyright (c) 2012, J.B.Wagenaar
  % This source file is subject to version 3 of the GPL license, 
  % that is bundled with this package in the file LICENSE, and is 
  % available online at http://www.gnu.org/licenses/gpl.txt
  %
  % This source file can be linked to GPL-incompatible facilities, 
  % produced or made available by MathWorks, Inc.
  
  properties (SetAccess = private)
    typeId   = '' % Type of the repository, restricted options
    rootId   = '' % Root Identifier
    subPath  = '' % Location to files from root.
    files    = {} % FileNames Rows are channels, columns are blocks
    typeAttr = {} % Attributes for type, depending on type definition.
    data          % Points to the data.
    attr          % Points to the attributes.
  end

  properties (Transient, Hidden)
    userData   = {}  % Can be used by getMethod to store stuff in object.
    fetchCache = []  % Holds data if the getMethod can utilize this.
    localPath  = ''  % Can be used to temporarily change the path.
  end

  properties (Access = private, Hidden)
    attrList   = {}   % Pointers to the dynamic attribute list.
    dataFcn           % Function handle for getting data.
    infoFcn           % Function handle for getting meta-info from data.
    cleanFcn          % Function handle for cleaning up data.
    dataInfo   = struct('size',[0 0], ...
      'format','double') % Information about the data format and size.
    reqAttr    = {}   % Cell array with required Attributes 
    optAttr    = {}   % Cell array with optional Attributes.
  end
  
  methods
    function delete(obj)
        %DELETE  Is called when object is deleted.
        %   This method will force the cleanup method before removing the
        %   object. This allows the user to define a specific cleanup method for
        %   the selected file-format. 
        %
        %   For example, if the GET and/or ATTR methods for a particular
        %   file-format use temporary files to cache some of the data, the
        %   cleanup method can be used to remove these temporary files. These
        %   files will also be removed when the object is deleted.
        
        cleanup(obj);
    end 
  end
  
  methods (Sealed)
    function obj = SFRepos(type, rootID, subPath, files, ...
      typeAttr, dataAttr)
      
      % Allow constructor without elements.
      if nargin == 0; return; end
      
      try
        % Otherwise, at least 4 inputs.
        error(nargchk(4, 6, nargin));

        % check inputs:
        assert(ischar(type), 'SCIFileRepos:SFRepos',...
          'Incorrect input value for TYPE.');
        assert(ischar(rootID), 'SCIFileRepos:SFRepos',...
          'Incorrect input value for ROOTID.');
        assert(ischar(subPath), 'SCIFileRepos:SFRepos',...
          'Incorrect input value for SUBPATH.');
        assert(iscell(files),  'SCIFileRepos:SFRepos',...
          'Incorrect input value for FILES.');

        assert(all(cellfun('isclass', files, 'char')), ...
          'SCIFileRepos:SFRepos',...
          'Each cell in the FILES input should contain a string.')

        obj.typeId   = type;
        obj.rootId   = rootID;
        obj.subPath  = subPath;
        obj.files    = files;
        obj.typeAttr = struct();

        % Set functionHandles
        obj.dataFcn = str2func(sprintf('get%s',type));
        obj.infoFcn = str2func(sprintf('info%s',type));
        obj.cleanFcn = str2func(sprintf('clean%s',type));

        if nargin > 4
          assert((iscell(typeAttr) && isvector(typeAttr)) || isempty(typeAttr), ...
            'SCIFileRepos:SFRepos',...
            'TYPEATTR input has to be a vector of cells.')
          assert(mod(length(typeAttr),2)==0, ...
            'SCIFileRepos:SFRepos',...
            'TYPEATTR should have an even number of cells.');

          names = typeAttr(1:2:(end-1));
          assert(all(cellfun('isclass', names, 'char')), ...
            'SCIFileRepos:SFRepos',...
            'TYPEATTR names should be strings.')
          
          values = typeAttr(2:2:end);
          for i = 1: length(names)
            obj.typeAttr.(names{i}) = values{i};
          end
        end
        
        % Get File-Format information
        aux = getinfo(obj, 'init');

          
          obj.reqAttr  = aux.requiredAttr;
        obj.optAttr  = aux.optionalAttr;
        obj.dataInfo = struct('format',aux.format, 'size',uint64(aux.size));
        
        % Check if loaded typeAttr are required or optional.
        checkReqAttr = false(length(obj.reqAttr),1);
        typeAttrNames = fieldnames(obj.typeAttr);
        for i = 1: length(typeAttrNames)
          chIndex = find(strcmp(typeAttrNames{i},obj.reqAttr),1);
          if ~isempty(chIndex)
            checkReqAttr(chIndex) = true;
          else
            assert(any(strcmp(typeAttrNames{i}, obj.optAttr)),...'
              'SCIFileRepos:SFRepos',...
              ['Provided TYPE-Attributes are not optional or required for '...
              'this file-format.']);
          end
        end
        
        assert(all(checkReqAttr),'SCIFileRepos:SFRepos', ...
          'Not all required attributes are set for this file-format.');
        
        if nargin == 6
          assert(iscell(dataAttr) && isvector(dataAttr), ...
            'SCIFileRepos:SFRepos',...
            'DATAATTR input has to be a vector of cells.')
          assert(mod(length(dataAttr),2)==0, ...
            'SCIFileRepos:SFRepos',...
            'DATAATTR should have an even number of cells.');

          names = dataAttr(1:2:(end-1));
          assert(all(cellfun('isclass', names, 'char')), ...
            'SCIFileRepos:SFRepos',...
            'DATAATTR names should be strings.')

          obj = addattr(obj, dataAttr{:});
        end
        
      catch ME
        [err, isScifi] = SFRepos.sfrcheckerror(ME, false);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;

      end
      
      
    end

    function varargout = subsref(obj, s)
      
      try
                
        % Check if array
        if any(strcmp(s(1).type,{'()' '{}'}))
          obj = builtin('subsref', obj, s(1));
          s(1) = [];
        end
        
        objLength = length(obj);
        
        if ~isempty(s)
          assert(strcmp(s(1).type, '.'), 'SciFileRepos:subsref', ...
            'Incorrect syntax for objects of type SFRepos.');

          if strcmp(s(1).subs,'data')
            
            % Get get channelIndeces and valueIndeces.
            switch length(s)
              case 1
                chIndeces = uint64(1) : uint64(obj.dataInfo.size(1));
                valueIndeces = uint64(1) : uint64(obj.dataInfo.size(2));
              case 2
                assert(strcmp(s(2).type,'()'),'SciFileRepos:subsref', ...
                  ['Cannot use any other indexing than ''()'' in the data '...
                  'property of an SFRepos.']);

                chIndeces = s(2).subs{2};
                valueIndeces = s(2).subs{1};
                if ischar(chIndeces)
                  if strcmp(chIndeces,':')
                    chIndeces = uint64(1) : uint64(obj.dataInfo.size(2));
                  else
                    error('SciFileRepos:subsref', ...
                      'Incorrect indexing of the data property.')
                  end
                end
                if ischar(valueIndeces)
                  if strcmp(valueIndeces,':')
                    valueIndeces = uint64(1) : uint64(obj.dataInfo.size(1));
                  else
                    error('SciFileRepos:subsref', ...
                      'Incorrect indexing of the data property.')
                  end
                end

                % Check precision of the indeces. This is way faster than
                % automatically change to uint64 even if it not necessary. This
                % should in reality never be an issue (maxValue approx > 1e14).
                if isa(valueIndeces, 'double') || isa(valueIndeces, 'single')
                  if eps(max(valueIndeces)) > 0.01
                    error('SciFileRepos:subsref', ...
                      [' Unable to use ''double/single'' precision for indeces ' ...
                      'of this magnitude.\n Please use ''uint64'' for '...
                      'the index values.']);
                  end
                end                
              otherwise
                error('SciFileRepos:subsref', ...
                  ['Cannot subindex more than one level in the data property '...
                  'of an SFRepos.']);
            end
            
            % Get the data.
            if objLength == 1
              obj = getdata(obj, valueIndeces, chIndeces);
            else
              out = cell(objLength,1);
              for iObj = 1: objLength
                out(iObj) = {getdata(obj(iObj), valueIndeces, chIndeces)};
              end
              obj = out;
            end

          elseif strcmp(s(1).subs, 'attr')
            if objLength == 1
              obj = getinfo(obj, 'info');
              
              % Get subsequent subsets (in case of structure);
              if length(s) > 1
                obj = builtin('subsref',obj, s(2:end));
              end
            else
              out = cell(objLength,1);
              for iObj = 1:objLength
                out(iObj) = {getinfo(obj(iObj), 'info')};
              end
              obj = out;
            end
          elseif length(s) == 1
            % Single substruct....
            try
              if objLength == 1
                obj = obj.(s.subs);
              else
                obj = {obj.(s.subs)};
              end
            catch ME %#ok<NASGU>
              % Could fail because trying to access dynamic property.
              try
                out = cell(objLength,1);
                for iObj = 1: objLength;
                  out(iObj) = {builtin('subsref', obj(iObj), s)};
                end
                obj = out;
              catch ME
                error('SciFileRepos:subsref', ...
                  ['Could not return values: Property does not exist or ' ...
                  'property is not added using ADDATTR in all objects.']);
              end
            end
          else
            % Multiple substruct....
            assert(objLength == 1, 'SciFileRepos:subsref', ...
              'Dot name reference on non-scalar structure.'); 
            obj = builtin('subsref', obj, s);
          end
        end
        
        % Format varargout such that it corresponds with the nargout value.
        if nargout <= 1
          varargout = {obj};% Nargout equals 1 --> return single cell. 
        else
          varargout = obj;  % Nargout does not equal 1 --> return cell array. 
        end
        
        assert(length(varargout) == nargout || nargout == 0, 'SciFileRepos:subsref', ...
          sprintf(' Not all output arguments are assigned during call.' ));
        
      catch ME
        [err, isScifi] = SFRepos.sfrcheckerror(ME, false);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;

      end
      
    end
    
    function obj = addattr(obj, varargin)
      %ADDATTR  Adds an attribute to the object.
      %   OBJ = ADDATTR(OBJ, 'name', Value, ...) adds one or more attributes to
      %   the object. These attributes should be used for meta-data that is
      %   unavailable in the files but that are required to correctly interpret
      %   the data.
      %
      %   For example: 
      %     OBJ = ADDATTR(OBJ, 'SampleFreq', 2713)
      %     OBJ = ADDATTR(OBJ, 'SampleFreq', 2713, 'chNames', {'ch1' 'ch2'})
      %
      %   See also: GETINFO
      
      try
        assert(mod(length(varargin),2)==0, 'SCIFileRepos:addattr',...
          'Incorrect number input arguments.');
        names = varargin(1:2:(end-1));
        assert(all(cellfun('isclass', names, 'char')), 'SCIFileRepos:addattr',...
          'Attribute names should be strings.')

        values = varargin(2:2:end);
        for i = 1: length(names)
          if isempty(findprop(obj,names{i}))
            addprop(obj,names{i});
          end
          obj.(names{i}) = values{i};
          obj.attrList{end+1} = names{i};
        end
      catch ME
        isSciFi = false;
        if strcmp(ME.identifier, 'MATLAB:UndefinedFunction');
          isSciFi = true;
        end
        
        [err, isScifi] = SFRepos.sfrcheckerror(ME, isSciFi);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;

      end
    end
    
    function info = getinfo(obj, option)
      %GETINFO  Returns meta-information about the data.
      %   INFO = GETINFO(OBJ, 'init') is called by the constructor of the SFRepos
      %   class. 
      %
      %   INFO = GETINFO(OBJ, 'info') is called when the user accesses the 'attr'
      %   property of the object.
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
      
      try
        curRoot = obj.reposlocation();
        
        fNames = fieldnames(curRoot);
        assert(any(strcmp(obj.rootId,fNames)), 'SciFileRepos:getinfo', ...
          sprintf(['Unable to find the location: "%s" in the location: "%s" '...
            'of the current location library.'],obj.rootId, curRoot.locID));
        curRoot = curRoot.(obj.rootId);
        filePath = fullfile(curRoot, obj.subPath);
        
        switch option
          case 'info'

            % Get attributes from files
            info = obj.infoFcn(obj, filePath, 'info');
            
            % Append size and format
            info.size = obj.dataInfo.size;
            info.format = obj.dataInfo.format;
            
            % Append attributes in object.
            attrNms = fieldnames(info);
            for iAttr = 1: length(obj.attrList)
              if ~any(strcmpi(obj.attrList{iAttr}, attrNms))
                info.(obj.attrList{iAttr}) = obj.(obj.attrList{iAttr});
              end
            end 
            
            % Append type attributes.
            attrNms = fieldnames(info);
            typeNms = fieldnames(obj.typeAttr);
            for iAttr = 1: length(typeNms)
              if ~any(strcmpi(typeNms{iAttr}, attrNms))
                info.(typeNms{iAttr}) = obj.typeAttr.(typeNms{iAttr});
              end
            end 
            
          case 'init'
            info = obj.infoFcn(obj, filePath,'init');
        end
          
      catch ME
        isSciFi = false;
        if strcmp(ME.identifier, 'MATLAB:UndefinedFunction');
          isSciFi = true;
        end
        
        [err, isScifi] = SFRepos.sfrcheckerror(ME, isSciFi);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;

      end
      
    end
    
    function data = getdata(obj, indeces, channels, varargin)
      %GETDATA  Returns data from repository.
      %   DATA = GETDATA(OBJ, CHANNELS, INDECES) returns the data for the
      %   current object as a 2D array. CHANNELS is a vector of indeces that
      %   indicate the channels that should be returned. INDECES is a vector of
      %   numbers that indicate the indices that should be returned.
      %
      %   Note that the CHANNELS input is referenced in respect to the
      %   file-names of the FILES property. It is possible that index 1 does not
      %   point to channel 1, depending on how the files are arranged in the
      %   object.
      %
      %   For Example:
      %     DATA = GETDATA(OBJ, [1 3 5], 1:1000)
      %
      %   See also: GETINFO
      
      try
        
        % Look at supplied attributes.
        checkReqAttr = false(length(obj.reqAttr),1);
        getAttr = struct();
        curIdx = 1;
        if nargin > 3
          assert(mod(length(varargin),2)==0, 'SciFileRepos:getdata',...
            'Incorrect number of input arguments.');
          for i = 1:2:(length(varargin)-1)
            assert(ischar(varargin{i}),'SciFileRepos:getdata',...
              'Attribute name should be a string');
            
            isReq = find(strcmp(varargin{i},obj.reqAttr),1);
            if ~isempty(isReq)
              checkReqAttr(isReq) = true;
              isReq = true;
            else
              isReq = false;
            end
            
            if ~isReq
              assert(any(strcmp(varargin{i}, obj.optAttr)), ...
                'SciFileRepos:getdata',['Supplied attribute not required '...
                'or optional for this fileformat.']);
            end
            
            getAttr.(varargin{i}) =  varargin{i+1};
            curIdx = curIdx+2;
          end
        end
        
        % Check required attributes
        if ~all(checkReqAttr)
          missingAttr = obj.reqAttr(~checkReqAttr);
          
          for i = 1:length(missingAttr)
            try
              value = obj.typeAttr.(missingAttr{i});
              getAttr.(missingAttr{i}) =  value;
              curIdx = curIdx +2 ;
            catch ME
              error('SciFileRepos:getdata', ...
                ['Missing required attribute: %s\n Attributes for the '...
                '''get''-method should be supplied in the TYPEATTR property'...
                'of the object or as additional inputs to the GETDATA method']...
                , missingAttr{i})
            end
          end
        end
               
        % Check range inputs
        assert(min(channels) >= 1 && ...
        max(channels) <= obj.dataInfo.size(2) && ...
          min(indeces) >= 1 && max(indeces) <= obj.dataInfo.size(1),...
          'SciFileRepos:getdata','Index out of range.' );
        
        curRoot = obj.reposlocation();
        fNames = fieldnames(curRoot);
        assert(any(strcmp(obj.rootId,fNames)), 'SciFileRepos:getinfo', ...
          sprintf(['Unable to find the location: "%s" in the location: "%s" '...
            'of the current location library.'],obj.rootId, curRoot.locID));
        
        curRoot = curRoot.(obj.rootId);
        filePath = fullfile(curRoot, obj.subPath);
        
        data = obj.dataFcn(obj, channels, indeces, filePath, getAttr);
      catch ME
        isScifi = false;
        if any(strcmp(ME.identifier, {'MATLAB:UndefinedFunction' ...
            'MATLAB:memmapfile:inaccessibleFile'}));
          isScifi = true;
        end
        
        [err, isScifi] = SFRepos.sfrcheckerror(ME, isScifi);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;


      end
    end

    function cleanup(obj)
      %CLEANUP  Removes data from transient properties.
      %   CLEANUP(OBJ) removes data from transient properties to allow Matlab to
      %   perform garbage collection and make more memory available. It also
      %   runs the specific CLEAN-method for the associated file-format if it
      %   exists (this is an optional method). 
      %
      %   This means that the USERDATA and FETCHCACHE should only be used to
      %   store variable temporarily and no methods should ever rely on data
      %   being available in these properties. 
      %
      %   These properties are meant to store temporary variable to improve
      %   performance, such as memmapfiles and previously fetched data.
      
      % Try to run the specific CLEAN method. This is an optional method, so no
      % error when it does not exists.
      try
        obj.cleanFcn(obj);
      catch ME
        if any(strcmp(ME.identifier, {'MATLAB:noSuchMethodOrField' ...
            'MATLAB:UndefinedFunction'}))
          % Method does not exist, no problem because it is optional.
          return
        else
          rethrow(ME);
        end
      end
      
      obj.userData   = [];
      obj.fetchCache = [];
      
    end
    
    function obj = addprop(obj, propName)
      % ADDPROP  (Not available for class SFRepos).
      %   OBJ = ADDPROP(OBJ, PROPNAME) is used to add properties to an object
      %   but is not available to the user in this class. Use the ADDATTR method
      %   to add information to the object.
      %
      %   See also: ADDATTR
      
      % This method is used by ADDATTR but cannot be used by the user in any
      % other way because this would not add the added property to the attribute
      % list.
      
      try
        aux = dbstack;

        assert(length(aux)>1, 'SCIFileRepos:ADDPROP_DirectAcces',...
          ['Please use the ADDATTR method to add attributes (properties) '...
          'to the object.']);
        assert(strcmp(aux(2).name,'SFRepos.addattr'),...
          'SCIFileRepos:ADDPROP_DirectAcces',...
          ['Please use the ADDATTR method to add attributes (properties) '...
          'to the object.']); 

        addprop@dynamicprops(obj, propName);
      catch ME
        [err, isScifi] = SFRepos.sfrcheckerror(ME, false);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;

      end
    end
    
    function curPath = getpath(obj)
      %GETPATH  Returns the folder where the files are located.
      %   CURPATH = GETPATH(OBJ) return the folder where the files are located.
      %   Depending on whether the user has set the 'localSubPath' property, the
      %   default path or the local path will be returned.
      %
      %   Setting this method will bypass the 'rootID' and 'subPath' properties
      %   when the GETPATH method is used.
      %
      %   See also: SFREPOS SETLOCALPATH
      
      try
        if isempty(obj.localPath)
          curRoot = obj.reposlocation();
          curRoot = curRoot.(obj.rootId);
          curPath = fullfile(curRoot, obj.subPath);
        else
          curPath = obj.localPath;
        end
      catch ME
        [err, isScifi] = SFRepos.sfrcheckerror(ME, false);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;
      end
      
    end
    
    function obj = setlocalpath(obj, localPath)
      %SETLOCALPATH  Sets a temporary new location for the files.
      %   OBJ = SETLOCALPATH(OBJ, 'localPath') set a temporary new location for
      %   the files. The 'localPath' should be a string indicating the folder
      %   that the files are located.
      %
      %   This method can be used to teporarily point the object to a new folder
      %   in case you copied the objects. This can be useful if you want to make
      %   a temporary local copy of some data to increase the speed of your
      %   analysis. You don't have to recreate the SFREPOS object, just use this
      %   method to point to the new location.
      %
      %   This method will bypass the 'rootID' and 'subPath' properties.
      %
      %   NOTE: This property will not be saved with the object (is a Transient
      %   variable). You'll have to set this everytime the object is loaded.
      %
      %   See also: GETPATH
      
      try
        assert(nargin==2,'SCIFileRepos:setlocalPpath',...
          'Incorrect number of input arguments.');
        
        assert(ischar(localPath) && isvector(localPath), 'SCIFileRepos:setlocalPpath',...
          'LocalPath should be a string.');
        
        obj.localPath = localPath;
      catch ME
        [err, isScifi] = SFRepos.sfrcheckerror(ME, false);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;
      end
      
    end
    
    function m = methods(obj, arg)
      %METHODS  Shows all methods associated with the object.
      %   METHODS(OBJ) displays all methods of the object OBJ that
      %   are defined for the subclass OBJ. Methods belonging to the
      %   SFR Toolbox are not shown. Clicking on the methods link
      %   will display the full description on the method.
      %
      %   METHOD(OBJ,'-all') includes the SFR Toolbox methods and
      %   displays them as well as the class specific methods.

      SFRMethods = { 'SFRepos' 'addattr' 'setlocalpath' 'getpath' 'getdata' ...
        'getinfo' 'cleanup' 'reposlocation' 'methods' };
      SFRMethodStr = {...
        'Object constructor for the class.'...
        'Adds an attribute to the object.'...
        'Sets a temporary new location for the files.' ...
        'Returns the folder where the files are located.'...
        'Returns data from repository.'...
        'Returns attributes associated with data files.'...
        'Returns information about the fileformat.'...
        'Removes data from transient properties.'...
        'Returns structure with repos locations.'...
        'Returns the methods for objects of class SFRepos.'...
        };    

      blockmethods = {'addlistener' 'delete' 'disp' 'eq' 'ge' 'ne' 'gt'  ...
        'le' 'lt' 'notify' 'isvalid' 'findobj' 'findprop' 'copy' ...
        'addprop' 'subsref' ...
        };

      if nargin == 2
        assert(strcmp('-all',arg), 'METHODS: Incorrect input argument.');
        showALL = true;
      elseif nargin == 1
        showALL = false;
      else
        error('SFR:methods','METHODS: Incorrect number of input arguments.');
      end

      if nargout
        fncs = builtin('methods', obj);
        if showALL
          blockIdx = cellfun(@(x) any(strcmp(x, blockmethods)), fncs);
          fncs(blockIdx) = [];
        else
          blockIdx = cellfun(@(x) ~any(strcmp(x, SFRMethods)), fncs);
          fncs(blockIdx) = [];
        end
        m = fncs;
        return;  
      end

      Link1 = sprintf('<a href="matlab:help(''%s'')">%s</a>',class(obj),class(obj));

      %Display Methods
      display([sprintf('\n') Link1 sprintf(' methods:')]);

      %Display methods sorted by the length of the method name and
      %then alphabetically. 

      fprintf('\nSFR Methods:\n');
      for i = 1:length(SFRMethods)
        method = SFRMethods{i};
        link = sprintf('<a href="matlab:help(''%s>%s'')">%s</a>','SFRepos',method, method);
        pad = char(32*ones(1,(20-length(method))));
        disp([ ' ' link pad SFRMethodStr{i}]);
      end
      
      if showALL
        %Define indenting steps for unusual long method names.
        STEP_SIZES = [20 23 26 29 32 35 38 41 44 47 50];
        SAMPLES_TOO_CLOSE = 2;
      
        fncs = builtin('methods', obj);
        blockIdx = cellfun(@(x) any(strcmp(x, [SFRMethods blockmethods])), fncs);
        fncs(blockIdx) = [];
        
        % -- Get H1 lines  
        txts{1,length(fncs)} = [];
        for i=1:length(fncs)
          aux = help(sprintf('%s.%s',class(obj), fncs{i}));
          tmp = regexp(aux,'\n','split');
          tmp = regexp(tmp{1},'\s*[\w\d()\[\]\.]+\s+(.+)','tokens','once');
          if ~isempty(tmp)
            txts(i) = tmp;
          end
        end
        
        %The class specific methods
        [~,I] = sort(lower(fncs));
        fncs = fncs(I);
        txts = txts(I);
        
        L = cellfun('length', fncs);
        
        fprintf('\nOther Methods:\n');
        for iSize = 1:length(STEP_SIZES)
          if iSize == length(STEP_SIZES)
            iUse = 1:length(txts);
          else
            iUse = find(L <= STEP_SIZES(iSize) - SAMPLES_TOO_CLOSE);
          end
          txtsUse = txts(iUse);
          fncsUse = fncs(iUse);
          LUse    = L(iUse);
          txts(iUse) = [];
          fncs(iUse) = [];
          L(iUse)    = [];
          for i=1:length(txtsUse)
            link = sprintf('<a href="matlab:help(''%s>%s'')">%s</a>',...
              class(obj),fncsUse{i},fncsUse{i});
            pad = char(32*ones(1,(STEP_SIZES(iSize)-LUse(i))));
            disp([ ' ' link pad txtsUse{i}]);
          end
        end
      else
        Link2 = sprintf('<a href="matlab:methods(%s,''-all'')">show more.</a>',class(obj));
        fprintf(['\n + ' Link2 '\n\n']);
      end
    end

    function disp(obj)
      %DISP  Displays the object in the console.
      %   DISP(OBJ) displays the object in the console. This method formats the
      %   data in the object and displays the object including links to
      %   informative methods.

      % Check if matlab is running in terminal. If so, no links are used.
      if usejava('desktop')
        showLinks = true;
      else
        showLinks = false;
      end

      % Create links to methods
      
      Link0 = sprintf(': <a href="matlab:help(''info%s'')">%s</a>',...
        obj.typeId,obj.typeId);
      Link1 = sprintf('<a href="matlab:help(''%s'')">%s</a>',class(obj),class(obj));
      Link2 = sprintf('<a href="matlab:methods(%s)">Methods</a>',class(obj));
      
      try
        reposloc = SFRepos.reposlocation();
        Link3 = sprintf(['<a href="matlab:display(sprintf(''\\n  Location: %s\\n  Full Path: %s\\n''))"'...
          '>Location</a>'],reposloc.locID, getpath(obj));
      catch ME %#ok<NASGU>
        Link3 = sprintf(['<a href="matlab:display(sprintf(''\\n  Location: %s\\n  Full Path: %s\\n''))"'...
          '>Location</a>'],'Unknown', 'Unknown');
      end
      
      
      if length(obj) == 1 

        % Check if object is deleted.
        if isvalid(obj)

          fieldn  = fieldnames(obj);


          valTxts{1,length(fieldn)} = [];
          for i = 1:length(fieldn)
            curProp = obj.(fieldn{i});
            
            if any(strcmp(fieldn{i}, {'typeId' 'data' 'attr'}))
              % Do special stuff
              switch fieldn{i}
                case 'typeId'
                  valTxts{i} = Link0;
                case 'data'
                  info = obj.dataInfo;
                  valTxts{i} = sprintf(': [%ix%i %s]',info.size(1), ...
                    info.size(2),info.format);
                  
                case 'attr'
                  valTxts{i} = ': [1x1 struct]';
              end
              
              
            else
              if ischar(curProp)
                if length(curProp) < 50 && size(curProp,1)<=1
                  valTxts{i} = [': ''' curProp ''''];
                else
                  s = size(curProp);
                  valTxts{i} = sprintf(': [%ix%i char]',s(1), s(2));
                end
              elseif iscellstr(curProp)
                aux = cellfun(@(x) ['''' x '''  '], curProp, 'UniformOutput', false);
                if ~isempty(aux);aux(end) = strtrim(aux(end));end
                  valTxts{i} = [': {' [aux{:}] '}'];
                  if length(valTxts{i})>50
                    s = size(curProp);
                    sizestr = [num2str(s(1)) sprintf('x%d',s(2:end))];
                    valTxts{i} = sprintf(': {%s cell}',sizestr);
                  end
              elseif isnumeric(curProp)
                if length(curProp)==1
                  valTxts{i} = num2str(curProp,': %g');
                elseif length(curProp)<10 && ndims(curProp) == 2 && any(size(curProp) <= 1)
                  %Needs to be a row vector
                  if size(curProp,1) > 1
                    s = size(curProp);
                    sizestr = [num2str(s(1)) sprintf('x%d',s(2:end))];
                    valTxts{i} = sprintf(': [%s %s]',sizestr, class(curProp));
                  else
                    valTxts{i} = [': [' regexprep(num2str(curProp,'% g'),' +',' ') ']'];
                  end
                  if length(valTxts{i}) > 50
                    s = size(curProp);
                    sizestr = [num2str(s(1)) sprintf('x%d',s(2:end))];
                    valTxts{i} = sprintf(': [%s %s]',sizestr, class(curProp));
                  end
                else
                  s = size(curProp);
                  sizestr = [num2str(s(1)) sprintf('x%d',s(2:end))];
                  valTxts{i} = sprintf(': [%s %s]',sizestr,class(curProp));
                end
              elseif islogical(curProp)
                if curProp; valTxts{i} = ': True';else valTxts{i} = ': False';end
              else 
                s = size(curProp);
                sizestr = [num2str(s(1)) sprintf('x%d',s(2:end))];
                valTxts{i} = sprintf(': [%s %s]',sizestr, class(curProp));
              end
            end
           
          end

          sizeStr = [];
        else
          % Object is deleted, show deleted info and return from method.
          if showLinks
              display([ '  deleted '  Link1]);
              display([sprintf('\n  ') Link2 ', ' Link3 sprintf('\n')]);
          else
              display([ '  deleted '  class(obj)]);
          end
          return
        end

      else
        % Display array of objects.
        sizeStr = sprintf('%ix%i ',size(obj,1), size(obj,2));
        fieldn   = fieldnames(obj);
        valTxts{1,length(fieldn)} = [];
      end


      % --- Actual printing to display ---
      
      % Display top links
      maxPropNameLength = max(cellfun(@length, fieldn));
      if showLinks
        display([ '  ' sizeStr  Link1 ':'  sprintf('\n')]);
      else
        display([ '  ' sizeStr  class(obj) ':'  sprintf('\n')]);
      end

      % Display Properties
      for i=1:length(valTxts)
        pad = char(32*ones(1,(maxPropNameLength - length(fieldn{i})  +2)));
        disp([ ' ' pad ' '  fieldn{i} valTxts{i} ]);
      end

      % Display methods
      if showLinks
        display([sprintf('\n  ') Link2 ', ' Link3  sprintf('\n')]);
      end
      
      % --- ---


    end
    
  end
    
  methods (Static)
    function out = reposlocation(option, locId,  fileName)
      %REPOSLOCATION  Sets/gets the location structure for the file-repositories.
      %   OUT = REPOSLOCATION() Gets the repository locations for the current
      %   session. If the locations have not been loaded into memory yet, the
      %   method returns an error indicating to use the SFRSETLOCATION.
      %   
      %   OUT = REPOSLOCATION('get') Returns the same information as above.
      %
      %   OUT = REPOSLOCATION('set') Asks the user to provide the location of
      %   the user specific 'location.xml' file and the environment that the
      %   user is currently using. 
      %
      %   OUT = REPOSLOCATION('set', LOCID) Depending on whether the user has
      %   previously used this method to locate the XML file the user will or
      %   will not be prompted to locate the XML file. The environment for the
      %   current session will be set to LOCID.
      %
      %   OUT = REPOSLOCATION('set', LOCID, FILENAME) Loads the user-specific
      %   location XML file from FILENAME and sets the environment of the
      %   current session to LOCID.
      %
      %   See also: SFRSETLOCATION 
      
      persistent curLocId rootStruct curPath
      
      % Init persistent variables on first call.
      if isempty(curLocId)
        curLocId = '';
        rootStruct = '';
        curPath = '';
      end
      
      try
        switch nargin
          case 0
            assert(~isempty(curPath), 'SciFileRepos:setlocation',...
              ['Unable to load the location library whithout setting ' ...
              'the path to the XML file using SFRSETLOCATION.']);
            
            fileName = curPath;
            locId    = curLocId;
            
          case 1
            switch option
              case 'get'
                assert(~isempty(curPath), 'SciFileRepos:setlocation',...
                  ['Unable to load the location library whithout setting ' ...
                  'the path to the XML file using SFRSETLOCATION.']);

            
                fileName = curPath;
                locId    = curLocId;
              case 'set'
                title = 'Select your HDSRepos XML Specification';
                [FileName, PathName] = uigetfile('*.xml', title, 'HDSRepos.xml');
                assert(ischar(FileName),'SciFileRepos:reposlocation',...
                  'User cancelled loading the XML file.')
                fileName = fullfile(PathName,FileName);
                
                fprintf(2,' -- -- Input Required -- --\n');
                locId = input('Specify the location for the SFR toolbox  : ','s');
            end 

          case 2
            assert(strcmp(option,'set'), 'SciFileRepos:setlocation',...
              ['Using multiple input arguments is only allowed when '...
              'the first argument of the method is ''set''']);
            
            if isempty(curPath)
              [FileName, PathName]    = uigetfile();
              assert(ischar(FileName),'SciFileRepos:reposlocation',...
                'User cancelled loading the XML file.')
              fileName = fullfile(PathName,FileName);
            else
              fileName = curPath;
            end
            
          case 3
            assert(strcmp(option,'set'), 'SciFileRepos:setlocation',...
              ['Using multiple input arguments is only allowed when '...
              'the first argument of the method is ''set''']);
            
          otherwise
        end

        if strcmp(locId, curLocId) && strcmp(fileName, curPath)
          out = rootStruct;
          return
        else
          rootStruct = SFRepos.loadReposStruct(locId, fileName);
          curPath = fileName;
          
          curLocId = locId;
          out = rootStruct;
        end
      catch ME
        [err, isScifi] = SFRepos.sfrcheckerror(ME, false);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;
      end

    end
    
    function out = getattrinfo(formatName)
      %GETATTRINFO  Returns required and optional attributes.
      %   OUT = GETATTRINFO('formatName') returns the required and optional
      %   attributes for the specified 'formatName'.
      
      try
        infoFnc = str2func(sprintf('info%s',formatName));
        out = infoFnc(SFRepos, '', 'attributes');
      catch ME
        isScifi = false;
        if strcmp(ME.identifier, 'MATLAB:UndefinedFunction');
          isScifi = true;
        end
        
        [err, isScifi] = SFRepos.sfrcheckerror(ME, isScifi);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;
      end
      
    end
  end
  
  methods (Static, Access=protected)
    
    function [ME simpleErr] = sfrcheckerror(ME, isSciFi)
      simpleErr = false;
      if strncmpi(ME.identifier, 'scifilerepos', 12) || isSciFi
        if ~strncmp(ME.message,'Problem in =',12)
          problemFunc = regexp(ME.stack(1).name,'\.','split');
          problemFunc = problemFunc{end};
          
          ME = MException(sprintf('SCIFileRepos:%s',problemFunc),...
            sprintf('Problem in ==> %s\n%s',problemFunc, ME.message));
        end
        simpleErr = true;
      end
    end
    
    function out = loadReposStruct(locId, filename)
      % LOADREPOSSTRUCT  Loads the repos structure from XML
      %   This method is protected and is only accessed by reposlocation.
      
      try
        assert(exist(filename,'file')==2, 'SCIFileRepos:LoadRepos_File',...
          sprintf('The file ''%s'' does not exist.',filename));

        try
          docNode= xmlread(filename);

          % Get all locations from file
          locationObjs = docNode.getElementsByTagName('LOC');
          locLength = locationObjs.getLength;
          locs = cell(locLength,1);
          for i = 1:locLength
            locs{i} = char(locationObjs.item(i-1).getAttribute('id'));
          end
        catch ME
          throw(MException('SCIFileRepos:LoadRepos_fileError',...
            'Unable to read XML file.'));
        end

        % Find location
        matchIdx = find(strcmp(locId,locs),1);
        assert(~isempty(matchIdx), 'SCIFileRepos:LoadRepos_noLoc',...
          sprintf('Unable to find the requested location: %s', locId));

        % Create struct with reposLocs
        try
          curLocObj  = locationObjs.item(matchIdx-1);
          allReposObjs = curLocObj.getElementsByTagName('REPOS');
          reposLength = allReposObjs.getLength;
          out = struct();
          for i = 1: reposLength
            n = strtrim(char(allReposObjs.item(i-1).getAttribute('id')));
            t = strtrim(char(allReposObjs.item(i-1).getAttribute('path')));
            out.(n) = t;
            
          end
          out.locID = locId;
        catch ME
          throw(MException('SCIFileRepos:LoadRepos_fileError',...
            'Unable to read XML file.'));
        end  
      catch ME
        [err, isScifi] = SFRepos.sfrcheckerror(ME, false);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;
      end        
    end
  end
end