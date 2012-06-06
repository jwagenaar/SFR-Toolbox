classdef SFRcontainer < dynamicprops
  %SFRCONTAINER  Scientific File Repository container
  %   This class is used to package a set of files and provide standardized
  %   syntax for accessing data from these files. The contents of an object of
  %   this class defines the file-type, the file location and other attributes
  %   associated with a set of data-files.
  %
  %   SFRCONTAINER(TYPE, ROOTID, SUBPATH, FILES) creates a SFRContainer object
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
  %   SFRCONTAINER(..., TYPEATTR) The TYPEATTR input can be added to specify
  %   attributes that are required by the method that loads the data from the
  %   referenced data files. TYPEATTR should be a 1D cell array with alternating
  %   'attributeName' and 'attributeValue'.
  %
  %     For example: TYPEATTR = {'dataClass' 'double'}
  %
  %   SFRCONTAINER(..., TYPEATTR, DATAATTR) The DATAATTR method can be used to
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
    typeAttr = {} % Attributes for type, depending on type definition.
  end

  properties (Transient, Hidden)
    userData    = {}  % Can be used by getMethod to store stuff in object
    fetchCache  = []  % Holds data if necessary.
  end

  properties (Access = private, Hidden)
    attrList      % Pointers to the dynamic attribute list.
    dataFcn       % Function handle for getting data.
    attrFcn       % Function handle for getting attributes.
  end
  
  methods
    function obj = SFRcontainer(type, rootID, subPath, files, ...
      typeAttr, dataAttr)
      
      % Allow constructor without elements.
      if nargin == 0; return; end
      
      % Otherwise, at least 4 inputs.
      error(nargchk(4, 6, nargin));
      
      % check inputs:
      assert(ischar(type), 'Incorrect input value for TYPE.');
      assert(ischar(rootID), 'Incorrect input value for ROOTID.');
      assert(ischar(subPath), 'Incorrect input value for SUBPATH.');
      assert(iscell(files),  'Incorrect input value for FILES.');
      
      assert(all(cellfun('isclass', files, 'char')), ...
        'Each cell in the FILES input should contain a string.')
      
      obj.typeId  = type;
      obj.rootId  = rootID;
      obj.subPath = subPath;
      obj.files   = files;
      
      % Set functionHandles
      obj.dataFcn = str2func(sprintf('get%s',type));
      obj.attrFcn = str2func(sprintf('attr%s',type));
      
      if nargin > 4
        assert(iscell(typeAttr) && isvector(typeAttr), ...
          'TYPEATTR input has to be a vector of cells.')
        assert(mod(length(typeAttr),2)==0, ...
          'TYPEATTR should have an even number of cells.');

        names = typeAttr(1:2:(end-1));
        assert(all(cellfun('isclass', names, 'char')), ...
        'TYPEATTR names should be strings.')
        
        values = typeAttr(2:2:end);
        for i = 1: length(names)
          obj.typeAttr.(names{i}) = values{i};
        end
      end
      
      if nargin == 6
        assert(iscell(dataAttr) && isvector(dataAttr), ...
          'DATAATTR input has to be a vector of cells.')
        assert(mod(length(dataAttr),2)==0, ...
          'DATAATTR should have an even number of cells.');

        names = dataAttr(1:2:(end-1));
        assert(all(cellfun('isclass', names, 'char')), ...
        'DATAATTR names should be strings.')
        
        obj = addattr(obj, dataAttr{:});
      
      end
    end

    function obj = addattr(obj, varargin)
      %ADDATTR  Adds an attribute to HDSFILEREPOS
      %   OBJ = ADDATTR(OBJ, 'name', Value, ...)
      
      assert(mod(length(varargin),2)==0, ...
        'Incorrect number input arguments.');
      names = varargin(1:2:(end-1));
      assert(all(cellfun('isclass', names, 'char')), ...
        'Attribute names should be strings.')
      
      values = varargin(2:2:end);
      for i = 1: length(names)
        if isempty(findprop(obj,names{i}))
          addprop(obj,names{i});
        end
        obj.(names{i}) = values{i};
        obj.attrList = {obj.attrList names{i}};
      end
    end
    
    function data = getdata(obj, channels, indeces)
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
      
      data = obj.dataFcn(obj,channels,indeces);
    end
    
    function attr = getAttr(obj)
      %GETATTR  Returns attributes associated with data files
      %   ATTR = GETATTR(OBJ) returns a structure with attributes associated
      %   with OBJ. These attributes can either be added to OBJ using the
      %   ADDATTR method, or are returned by the ATTR method that is associated
      %   with the type of data stored in this object.
      %
      %   see also: ADDATTR GETDATA
      
      attr = struct();
      for iAttr = 1: length(obj.attrList)
        attr.(obj.attrList(iAttr)) = obj.(obj.attrList(iAttr));
      end     
      attr = obj.attrFcn(obj, attr);
 
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
      try
        aux = dbstack;

        assert(length(aux)>1, 'ADDPROP:DirectAcces',...
          ['Please use the ADDATTR method to add attributes (properties) '...
          'to the object.']);
        assert(strcmp(aux(2).name,'SFRcontainer.addattr'),'ADDPROP:DirectAcces',...
          ['Please use the ADDATTR method to add attributes (properties) '...
          'to the object.']); 

        addprop@dynamicprops(obj, propName);
      catch ME
        throwAsCaller(MException(ME.identifier,...
          ['SFRCONTAINER.ADDPROP: ' ME.message]));
      end
    end
    
  end
    
  methods (Static)
    
    function out = getrepos(locId,  fileName)
      
      persistent curLocId rootStruct curPath
      
      if isempty(curLocId)
        curLocId = '';
        rootStruct = '';
        curPath = '';
      end
      
      switch nargin
        case 0
          if isempty(curPath)
            title = 'Select your HDSRepos XML Specification';
            [FileName, PathName]    = uigetfile('*.xml', title, 'HDSRepos.xml');
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
        rootStruct = SFRcontainer.loadReposStruct(locId, fileName);
        curPath = fileName;
        curLocId = locId;
        out = rootStruct;
      end
      
    end
    
    function out = loadReposStruct(locId, filename)
      docNode= xmlread(filename);
      
      % Get all locations from file
      locationObjs = docNode.getElementsByTagName('LOC');
      locLength = locationObjs.getLength;
      locs = cell(locLength,1);
      for i = 1:locLength
        locs{i} = char(locationObjs.item(i-1).getAttribute('id'));
      end
      
      % Find location
      matchIdx = find(strcmp(locId,locs),1);
      
      
      assert(~isempty(matchIdx), ...
        sprintf('Unable to find the provided location: %s',locId));
      
      % Create struct with reposLocs
      curLocObj  = locationObjs.item(matchIdx-1);
      allReposObjs = curLocObj.getElementsByTagName('REPOS');
      reposLength = allReposObjs.getLength;
      out = struct();
      for i = 1: reposLength
        n = strtrim(char(allReposObjs.item(i-1).getAttribute('id')));
        t = strtrim(char(allReposObjs.item(i-1).getTextContent));
        out.(n) = t;
      end
      
    end

  end
  
end