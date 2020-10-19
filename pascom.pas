{pasCom: main unit for the pasCom framework
This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the Free Software
Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA}

unit pasCom;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl;

type
  {Exception raised when a timeout occures. Can typcially be deactivated in the communication settings}
  EComTimeout = Exception;
  {Exception raised when a communication channel was lost, i.e. the USB disconnected or the network conection
  closed by the peer}
  EComLost = Exception;
  {Exception raised when an invalid resource is given}
  EComInvalidResource = Exception;
  {Exception raised if parameters in a resource are invalid}
  EComInvalidResourceParams = Exception;

const
  TimeoutInfinite = High(cardinal);

type
  TAbstractComStream = class(TStream)
  private
    fGlobalTimeout:cardinal;
    fGlobalRaiseTimeout:boolean;
  public
    constructor Create;
    destructor Destroy; override;

    {Connect to the given resource. The format of the resource string is to be defined by siblings.
    This function must be implemented by siblings.}
    procedure ConnectTo(resource:string); virtual; abstract;

    {Issue a reconnect or connect to a resource created disconnected}
    procedure Connect; virtual; abstract;

    {Disconnect from the resource.
    This function must be implemented by siblings.}
    procedure Disconnect; virtual; abstract;

    {Write data to the resource, blocking
    When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.
    This function must be implemented by siblings.}
    function Write(const Buffer; Count: Longint): Longint; override;

    {Read data from the resource, blocking. Returns the actual number of bytes read
    When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.
    This function must be implemented by siblings.

    To avoid loops using Read() to swallow all available CPU resources when using timeouts,
    Read should wait for atleast on byte to be available by other means than trying.}
    function Read(var Buffer; Count: Longint): Longint; override;

    {Write string data to the resource. Optionally appends a linefeed or arbritrary string as termination (Default: LF).
    When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.g}
    procedure WriteString(const Data:string; const linefeed:string=#13); virtual;

    {Read string data from the resource. Terminates when the given number of bytes has been read or
    the termination string has been received. Termination is turned off by setting term to an empty string.
    Returns the actual number of bytes read (including the termination).
    When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.

    The caller can pre-allocate a string in Dst with SetLength, the data will allways be written starting
    at position 1 and the string resized only if the initial length of Dst is smaller than the currently
    needed length and shorter than maxLen, of course. Any data present in the string after the newly received
    data is NOT cleared. You might use SetLength with the return value of this faction to clear any excess
    data if using preallocated strings.}
    function ReadString(var Dst:string; const maxLen:integer; const term:string=#13):integer; virtual;
  public
    {Global timeout (in ms) used by the connection for all operations. Default is 1s.
    Set to 0 to disable waiting (if possible for the specific resource), or to TimeoutInfinite to
    wait forever.}
    property Timeout:cardinal read fGlobalTimeout write fGlobalTimeout default 1000;
    {Set to true to raise an exception when a timeout occurs. Otherwise, the timeout is simply ignored, default is false.}
    property RaiseTimeout:boolean read fGlobalRaiseTimeout write fGlobalRaiseTimeout default false;
  public
    {Return the resource type identifier associated with this class. Examples could be "tcp" or
    "serial".}
    class function GetComResourceType:string; virtual; abstract;

    {Creates a new object of the type of this class. Usefull if accessing the classes using
    their string type identifiers.}
    class function CreateNew:TAbstractComStream; virtual; abstract;
  end;

{Class type for PasCom streams of various types}
  TComStreamType = class of TAbstractComStream;

{List Type holding information about various com stream classes}
  TComStreamTypeList = specialize TFPGList<TComStreamType>;

{Parses a resource string and returns it's type specifier string. Examples:
"tcp:localhost:1234" will return "tcp" and "serial:COM1" will return "serial".
If no or an invalid resource type is given, the return value is an empty string.}
function GetComResourceTypeFromResource(resource:string):string;

{Parse a resource string or resource type string and return the class of
TComStreamType that might be used to initialize a ComStream for that resource.
Ca be supplied either with a type name (e.g. "tcp") or with a resource including
the type name, e.g. "serial:/dev/ttyUSB0". If nothing is found, the return value
is nil.}
function GetComResourceTypeClass(comTypeOrResource:string):TComStreamType;

{Check for a resource type identifier in the given resource string and return the
identifier as well as the resource without it.}
function StripComResourceTypeFromResource(resource:string; out strippedResource:string):string;

var
  {List of valid type specifiers, i.e. valid communication backends. Com streams
  can add their type to this list to be registered for functions like
  @GetComResourceTypeClass().}
  ComResourceTypes : TComStreamTypeList;

implementation

uses DateUtils;

constructor TAbstractComStream.Create;
begin
  inherited;
end;

destructor TAbstractComStream.Destroy;
begin
  inherited;
end;


{Write data to the resource, blocking
When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.
This function must be implemented by siblings.}
function TAbstractComStream.Write(const Buffer; Count: Longint): Longint;
begin
  inherited;
end;

{Read data from the resource, blocking. Returns the actual number of bytes read
When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.
This function must be implemented by siblings.}
function TAbstractComStream.Read(var Buffer; Count: Longint): Longint;
begin   
  inherited;
end;

{Write string data to the resource. Optionally appends a linefeed or arbritrary string as termination (Default: LF).
When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.g}
procedure TAbstractComStream.WriteString(const Data:string; const linefeed:string=#13);
begin
  if Length(Data)>0 then Write(Data[1], Length(Data));
  if Length(linefeed)>0 then Write(linefeed[1], Length(linefeed));
end;

{Read string data from the resource. Terminates when the given number of bytes has been read or
the termination string has been received. Termination is turned off by setting term to an empty string.
Returns the actual number of bytes read (including the termination).
When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.}
function TAbstractComStream.ReadString(var Dst:string; const maxLen:integer; const term:string=#13):integer;
var
  start:TDateTime;
  c:char;
  duration:int64;
  strLen:integer;
  hasTimeout:boolean;
  cLen:integer;
  termReached:boolean;
begin
  //Defaults:
  result:=0;
  hasTimeout:=false;
  duration:=0;
  termReached:=false;
  //IF the caller allocated the string with some minimal size, don't overwrite this...
  strLen:=Length(Dst);
  //Read bytes into the buffer until the stop conditions are met.
  //Check timeout on each iterition not to take too long.
  start:=Now;
  try
    repeat
      //1st timeout MUST be handeled by the Read() function for ReadByte to actually timeout.
      //If there is an exception raised, this will ultimately fail here, but it might be desired anyway...
      cLen:=Read(c, 1);

      //Check timeout for the entire string.
      duration:=MilliSecondsBetween(Now, start);
      if fGlobalTimeout=TimeoutInfinite then
        hasTimeout:=false
      else
        hasTimeout:=duration > fGlobalTimeout;

      //Add to the buffer if one byte has been received and no timeout occured meanwhile
      if (cLen = 1) and (not hasTimeout) then begin
        //Advance pos and check if the Dst string is still long enought (if the caller
        //has allocated a buffer by SetLength e.g.. If not, resize the string by simple concatenation)
        Inc(result);
        if result>strLen then
          Dst:=Dst+c
        else
          Dst[result]:=c;    

        //Check if the termination string was found.
        if term.Length=1 then
          if Dst[result] = term then termReached:=true
        else if term.Length > 1 then begin
          //Check if the characters at the end of the
          //current buffer position (end of Dst or at Dst[result]) matches
          //the termination string:
          if Dst.IndexOf(term, result-term.Length, term.Length) = result-term.Length then
            termReached:=true;
        end;
      end;

      //Nothing read? Throttle the loop a little. Don't do that if fGlobalTimeout is set to
      //0, in that case, the user is to blame...
      if (cLen=0) and (fGlobalTimeout<>0) then
        Sleep(5); //5 ms is typically lower than the minimal granualty of any task scheduler, but it let's the CPU switch to annother thread...
    until hasTimeout or (result = maxLen) or termReached;
  finally
  end;
end;

{******************************************************************************}

{Parses a resource string and returns it's type specifier string. Examples:
"tcp:localhost:1234" will return "tcp" and "serial:COM1" will return "serial".
If no or an invalid resource type is given, the return value is an empty string.}
function GetComResourceTypeFromResource(resource:string):string;
var
  typeStr:string;
  typeClass:TComStreamType;
  pos:integer;
begin
  //Check if a colon exists
  pos:=resource.IndexOf(':');
  if pos >= 0 then begin
    //Extract first part of the resource
    typeStr:=resource.Substring(0, pos);
    for typeClass in ComResourceTypes do
      if typeClass.GetComResourceType.CompareTo(typeStr) = 0 then begin
        result:=typeClass.GetComResourceType;
        break;
      end;
  end
  else
    result:='';
end;

{Parse a resource string or resource type string and return the class of
TComStreamType that might be used to initialize a ComStream for that resource.
Ca be supplied either with a type name (e.g. "tcp") or with a resource including
the type name, e.g. "serial:/dev/ttyUSB0". If nothing is found, the return value
is nil.}
function GetComResourceTypeClass(comTypeOrResource:string):TComStreamType;
var
  typeStr:string;
  typeClass:TComStreamType;
  pos:integer;
begin
  //Check if a colon exists
  pos:=comTypeOrResource.IndexOf(':');
  if pos >= 0 then
    //Extract first part of the resource
    typeStr:=comTypeOrResource.Substring(0, pos)
  else
    typeStr:=comTypeOrResource;

  //Something left?
  if typeStr.Length = 0 then result:=nil
  else begin
    for typeClass in ComResourceTypes do begin
      if typeClass.GetComResourceType.CompareTo(typeStr) = 0 then begin
        result:=typeClass;
        break;
      end;
    end;
  end;
end;

{Check for a resource type identifier in the given resource string and return the
identifier as well as the resource without it.}
function StripComResourceTypeFromResource(resource:string; out strippedResource:string):string;
begin
  result:=GetComResourceTypeFromResource(resource);
  if result<>'' then
    strippedResource:=resource.Substring(result.Length+1)
  else
    strippedResource:=resource;
end;

initialization
  ComResourceTypes:=TComStreamTypeList.Create;
finalization
  ComResourceTypes.Free;
end.

