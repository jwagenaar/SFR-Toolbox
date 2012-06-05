classdef SCIFileRepos < dynamicprops

  properties (SetAccess = private)
    typeId   = '' % Type of the repository, restricted options
    typeAttr = {} % Attributes for type, depending on type definition.
    rootId   = '' % Root Identifier
    subPath  = '' % Location to files from root.
    files    = {} % FileNames Rows are channels, columns are blocks
  end

  properties (Transient, Hidden)
    userData    = {}  % Can be used by getMethod to store stuff in object
    fetchCache  = []  % Holds data if necessary.
  end

  properties (Hidden)
    attrList = []     % Pointers to the dynamic attribute list.
  end
  
  methods
    function obj = SCIFileRepos(rootID, subPath, files, type, varargin)
      
      if nargin == 0
        return
      end
      
      assert(any(strcmp(type,{'BinByChannel' 'mef' 'cheetah'})), ...
        'Uncompatible Type');
      obj.typeId = type;
      obj.rootId = rootID;
      obj.subPath = subPath;
      obj.files = files;
      
      if nargin > 3
        names = varargin(1:2:(end-1));
        values = varargin(2:2:end);
        for i = 1: length(names)
          obj.typeAttr.(names{i}) = values{i};
        end
      end
      
        
     
    end

    function obj = addattr(obj,varargin)
      %ADDATTR  Adds an attribute to HDSFILEREPOS
      %   OBJ = ADDATTR(OBJ, 'name', Value, ...)
      
      addprop(obj,varargin{1});
      obj.(varargin{1}) = varargin{2};
      obj.attrList = {obj.attrList varargin{1}};
    end
    function data = getData(obj, channels, indeces)
      switch obj.typeId
        case 'BinByChannel'
          data = getBinByChannel(obj, channels, indeces);
          
      end
    end
    
    function attr = getAttr(obj)
      
      attr = struct('chNames',[], 'sf' , obj.sf);
      attr.chNames = obj.chNames;
      switch obj.typeID
        case 'BinByChannel'
          attr = attrBinByChannel(obj, attr);
          
      end
    end
    
    data = getuintbinbychannel(obj, channels, indeces);
    
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
        rootStruct = HDSFileRepos.loadReposStruct(locId, fileName);
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