function out = annotationstruct(name, type, varargin)
  %ANNOTATIONSTRUCT  Create annotation structure for SFR toolbox.
  %   OUT = ANNOTATIONSTRUCT(NAME, 'SingleEvent', CHVEC, STARTVEC, VALUEVEC)
  %   returns a structure using the input arguments to the method.
  %  
  %   OUT = ANNOTATIONSTRUCT(NAME, 'DoubleEvent', CHVEC, STARTVEC, STOPVEC,
  %   VALUEVEC) returns a structure using the input arguments to the method.
  %
  %   OUT = ANNOTATIONSTRUCT(NAME, 'SingleMarker', STARTVEC, VALUEVEC) returns a
  %   structure using the input arguments to the method.
  %
  %   This method creates a standardized structure that is used by the
  %   SFR-Toolbox. There are three types of annotations:
  %
  %     1) SingleEvent :  events without a duration that occur on a specific
  %                       channel.
  %     2) DoubleEvent :  events with a duration that occur on a specific
  %                       channel.
  %     3) SingleMarker : events withoud a duration that are accross all
  %                       channels.
  
  assert(any(strcmp(type, {'SingleEvent' 'DoubleEvent' 'SingleMarker'})), ...
    ['The TYPE input has to be one of: ''SingleEvent'', ''DoubleEvent'' or '...
    '''SingleMarker''.']);
  assert(ischar(name),'NAME should be of class ''char''.');
  
  out = struct(...
    'name',name,...
    'type',type,...
    'chvec',[],...
    'startvec',[],...
    'stopvec',[],...
    'valuevec',[]);
  
  switch type
    case 'SingleEvent'
      assert(nargin == 5,'Incorrect number of input arguments.');
      chvec = varargin{1};
      startvec = varargin{2};
      valuevec = varargin{3};
      
      assert(length(chvec)==length(startvec) && length(chvec)==length(valuevec),...
        'Lengths of CHVEC, STARTVEC, and VALUEVEC must be the same.');
      
      out.chvec = chvec;
      out.startvec = startvec;
      out.valuevec = valuevec;
      
    case 'DoubleEvent'
      assert(nargin == 6,'Incorrect number of input arguments.');
      chvec = varargin{1};
      startvec = varargin{2};
      stopvec = varargin{3};
      valuevec = varargin{4};
      
      assert(length(chvec)==length(startvec) && ...
        length(chvec)==length(valuevec) && length(chvec)==length(stopvec),...
        'Lengths of CHVEC, STARTVEC, and VALUEVEC must be the same.');
      
      out.chvec = chvec;
      out.startvec = startvec;
      out.stopvec = stopvec;
      out.valuevec = valuevec;      
      
    case 'SingleMarker'
      assert(nargin == 4,'Incorrect number of input arguments.');
      startvec = varargin{1};
      valuevec = varargin{2};
      
      assert(length(chvec)==length(startvec) && length(chvec)==length(valuevec),...
        'Lengths of CHVEC, STARTVEC, and VALUEVEC must be the same.');
      
      out.startvec = startvec;
      out.valuevec = valuevec;
  end
  
end