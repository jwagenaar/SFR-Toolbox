classdef SFRepos < dynamicprops
  %SFREPOS  Scientific File Repository container
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
  %   See also: ADDATTR GETDATA GETATTR CLEANUP

  
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
    typeAttr      % Attributes for type, depending on type definition.
    data          % Points to the data.
    attr          % Points to the attributes.
  end

  properties (Transient, Hidden)
    userData    = {}  % Can be used by getMethod to store stuff in object.
    fetchCache  = []  % Holds data if the getMethod can utilize this.
  end

  properties (Access = private, Hidden)
    attrList      % Pointers to the dynamic attribute list.
    dataFcn       % Function handle for getting data.
    attrFcn       % Function handle for getting attributes.
    infoFcn       % Function handle for getting size of data.
    dataInfo      % 1x2 vector of data size [nrValues nrChannels]
    reqAttr       % Cell array with required Attributes 
    optAttr       % Cell array with optional Attributes.
  end
  
  methods
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

        obj.typeId  = type;
        obj.rootId  = rootID;
        obj.subPath = subPath;
        obj.files   = files;

        % Set functionHandles
        obj.dataFcn = str2func(sprintf('get%s',type));
        obj.attrFcn = str2func(sprintf('attr%s',type));
        obj.infoFcn = str2func(sprintf('info%s',type));

        % Get File-Format information
        attributes = formatinfo(obj, 'attributes');
        obj.reqAttr = attributes.requiredAttr;
        obj.optAttr = attributes.optionalAttr;
        
        checkReqAttr = false(length(obj.reqAttr),1);
        if nargin > 4
          assert(iscell(typeAttr) && isvector(typeAttr), ...
            'SCIFileRepos:SFRepos',...
            'TYPEATTR input has to be a vector of cells.')
          assert(mod(length(typeAttr),2)==0, ...
            'SCIFileRepos:SFRepos',...
            'TYPEATTR should have an even number of cells.');

          names = typeAttr(1:2:(end-1));
          assert(all(cellfun('isclass', names, 'char')), ...
            'SCIFileRepos:SFRepos',...
            'TYPEATTR names should be strings.')
          
          for i = 1:length(names)
            chIndex = find(strcmp(names{i},obj.reqAttr),1);
            if ~isempty(chIndex)
              checkReqAttr(chIndex) = true;
            else
              assert(any(strcmp(names{i}, obj.optAttr)),...'
                'SCIFileRepos:SFRepos',...
                ['Provided TYPE-Attributes are not optional or required for '...
                'this file-format.']);
            end
          end
          
          values = typeAttr(2:2:end);
          for i = 1: length(names)
            obj.typeAttr.(names{i}) = values{i};
          end
        end
        
        assert(all(checkReqAttr),'SCIFileRepos:SFRepos', ...
          'Not all required attributes are set for this file-format');
        
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
        
        % Add size info to data prop.
        sz = formatinfo(obj, 'size');        
        sizestr = [num2str(sz.size(1)) sprintf('x%d',sz.size(2:end))];
        obj.data = sprintf('[%s %s]',sizestr, sz.format);
        obj.dataInfo = sz;

        
      catch ME
        [err, isScifi] = SFRepos.sfrcheckerror(ME, false);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;

      end
      
      
    end

    function varargout = subsref(obj, s)
      
      try
        if strcmp(s(1).subs,'data')
          switch length(s)
            case 1
              chIndeces = 1:obj.dataInfo.size(2);
              valueIndeces = 1:obj.dataInfo.size(1);
              out = getdata(obj, chIndeces, valueIndeces);
            case 2
              assert(strcmp(s(2).type,'()'),'SciFileRepos:subsref', ...
                ['Cannot use any other indexing than ''()'' in the data '...
                'property of an SFRepos.']);

              chIndeces = s(2).subs{1};
              valueIndeces = s(2).subs{2};
              if ischar(chIndeces)
                if strcmp(chIndeces,':')
                  chIndeces = 1:obj.dataInfo.size(2);
                else
                  error('SciFileRepos:subsref', ...
                    'Incorrect indexing of the data property.')
                end
              end
              if ischar(valueIndeces)
                if strcmp(valueIndeces,':')
                  valueIndeces = 1:obj.dataInfo.size(1);
                else
                  error('SciFileRepos:subsref', ...
                    'Incorrect indexing of the data property.')
                end
              end

              out = getdata(obj, chIndeces, valueIndeces);
            otherwise
              error('SciFileRepos:subsref', ...
                ['Cannot subindex more than one level in the data property '...
                'of an SFRepos.']);
          end

        elseif strcmp(s(1).subs, 'attr')
          out = getattr(obj);
        else
          out = builtin('subsref', obj, s);
        end
        
        % Format varargout such that it corresponds with the nargout value.
        if nargout <= 1
          varargout = {out};% Nargout equals 1 --> return single cell. 
        else
          varargout = out;  % Nargout does not equal 1 --> return cell array. 
        end
        
      catch ME
        [err, isScifi] = SFRepos.sfrcheckerror(ME, false);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;

      end
      
    end
    
    function obj = addattr(obj, varargin)
      %ADDATTR  Adds an attribute to HDSFILEREPOS
      %   OBJ = ADDATTR(OBJ, 'name', Value, ...) adds one or more attributes to
      %   the object. These attributes should be used for meta-data that is
      %   unavailable in the files but that are required to correctly interpret
      %   the data.
      %
      %   For example: 
      %     OBJ = ADDATTR(OBJ, 'SampleFreq', 2713)
      %     OBJ = ADDATTR(OBJ, 'SampleFreq', 2713, 'chNames', {'ch1' 'ch2'})
      %
      %   See also: GETATTR
      
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
    
    function out = formatinfo(obj, option)
      
      try
        curRoot = obj.getrepos();
        curRoot = curRoot.(obj.rootId);
        filePath = fullfile(curRoot, obj.subPath);
        
        out = obj.infoFcn(obj, filePath, option);
      catch ME
        isSciFi = false;
        if strcmp(ME.identifier, 'MATLAB:UndefinedFunction');
          isSciFi = true;
        end
        
        [err, isScifi] = SFRepos.sfrcheckerror(ME, isSciFi);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;

      end
      
    end
    
    function data = getdata(obj, channels, indeces, varargin)
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
      %   See also: GETATTR
      
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
               
        curRoot = obj.getrepos();
        curRoot = curRoot.(obj.rootId);
        filePath = fullfile(curRoot, obj.subPath);
        
        data = obj.dataFcn(obj, channels, indeces, filePath, getAttr);
      catch ME
        isScifi = false;
        if strcmp(ME.identifier, 'MATLAB:UndefinedFunction');
          isScifi = true;
        end
        
        [err, isScifi] = SFRepos.sfrcheckerror(ME, isScifi);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;


      end
    end
    
    function attr = getattr(obj)
      %GETATTR  Returns attributes associated with data files
      %   ATTR = GETATTR(OBJ) returns a structure with attributes associated
      %   with OBJ. These attributes can either be added to OBJ using the
      %   ADDATTR method, or are returned by the ATTR method that is associated
      %   with the type of data stored in this object.
      %
      %   The method consolidates the TYPEATTR property attributes and the
      %   object attributes and the attributes returned by the specific
      %   attribute method for the fileformat.
      %
      %   In case an attribute is defined in multiple places, the hierarchy of
      %   attributes equals: 1) Specific format function, 2) Added object
      %   attributes, and 3) Type Attributes.
      %
      %   See also: ADDATTR GETDATA
      
      try
        attr = struct();
        for iAttr = 1: length(obj.typeAttr)
          attr.(obj.typeAttr{iAttr}) = obj.(obj.typeAttr{iAttr});
        end   
        
        for iAttr = 1: length(obj.attrList)
          attr.(obj.attrList{iAttr}) = obj.(obj.attrList{iAttr});
        end    
        
        attr = obj.attrFcn(obj, attr);
      catch ME
        [err, isScifi] = SFRepos.sfrcheckerror(ME, false);
        if isScifi; throwAsCaller(err); else rethrow(ME); end;
      end
      
    end

    function cleanup(obj)
      %CLEANUP  removes data from transient properties
      %   CLEANUP(OBJ) removes data from transient properties to allow Matlab to
      %   perform garbage collection and make more memory available.
      %
      %   This means that the USERDATA and FETCHCACHE should only be used to
      %   store variable temporarily and no methods should ever rely on data
      %   being available in these properties. 
      %
      %   These properties are meant to store temporary variable to improve
      %   performance, such as memmapfiles and previously fetched data.
      
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
    
  end
    
  methods (Static)
    function out = getrepos(locId,  fileName)
      %GETREPOS  Returns structure with repos locations.
      %   OUT = GETREPOS() 
      %
      %   OUT = GETREPOS(LOCID)
      %
      %   OUT = GETREPOS(LOCID, FILENAME)
      
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
            if isempty(curPath)
              title = 'Select your HDSRepos XML Specification';
              [FileName, PathName] = uigetfile('*.xml', title, 'HDSRepos.xml');
              fileName = fullfile(PathName,FileName);
            else
              fileName = curPath;
            end

            if isempty(curLocId)
              fprintf(2,' -- -- Input Required -- --\n');
              locId = input('Specify the Location ID for the HDS Repos  : ','s');
            else
              locId = curLocId;
            end

          case 1
            if isempty(curPath)
              [FileName, PathName]    = uigetfile();
              fileName = fullfile(PathName,FileName);
            else
              fileName = curPath;
            end
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
  end
  
  methods (Static, Access=protected)
    
    function [ME simpleErr] = sfrcheckerror(ME, isSciFi)
      simpleErr = false;
      if strncmp(ME.identifier, 'SCIFileRepos', 12) || isSciFi
        if ~strncmp(ME.message,'Problem in =',12)
          problemFunc = regexp(ME.stack(1).name,'\.','split');
          problemFunc = problemFunc{end};
          
          ME = MException(sprintf('SCIFileRepos:%s',problemFunc),...
            sprintf('Problem in => %s\n%s',problemFunc, ME.message));
        end
        simpleErr = true;
      end
    end
    
    function out = loadReposStruct(locId, filename)
      % LOADREPOSSTRUCT  Loads the repos structure from XML
      %   This method is protected and is only accessed by GETREPOS.
      
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
          sprintf('Unable to find the provided location: %s',locId));

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