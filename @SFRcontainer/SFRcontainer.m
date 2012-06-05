classdef SFRcontainer < dynamicprops
  %SFRCONTAINER  Scientific File Repository container
  %   This class is used to package a set of files and provide standardized
  %   syntax for accessing data from these files. The contents of an object of
  %   this class defines the file-type, the file location and other attributes
  %   associated with a set of data-files.
  %
  %   SFRCONTAINER(TYPE, ROOTID, SUBPATH, FILES)
  %
  %   SFRCONTAINER(TYPE, ROOTID, SUBPATH, FILES, TYPEATTR)
  %
  %   SFRCONTAINER(TYPE, ROOTID, SUBPATH, FILES, TYPEATTR, DATAATTR)

  
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