{pasComSerial: serial port driver for the pasCom framework
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

unit pasComSerial;

{$mode objfpc}{$H+}

{$IFDEF DEBUG}
{$IFDEF UNIX}
{$DEFINE DGB_WRITE}
{$ENDIF}
{$ENDIF}

interface

uses
  Classes, SysUtils, pasCom, MySerial;

{Serial port specific exceptions}
type
  {Raised if the settings programmed to the serial port were not accepted by te hardware.}
  EComSerialSettingsError = Exception;


type
  TSerialClientComStream = class(TAbstractComStream)
  private
    fPortName:string;
    fPort:TSerialHandle;
    fPortBaud:integer;
    fPortBytes:integer;
    fPortParity:TParityType;
    fPortStop:TStopBits;
    fPortFlags:TSerialFlags;

    procedure InternalConnect;
    procedure InternalDisconnect;
  public
    constructor Create; overload;

    {Create a Serial client communication stream directly connecting to the given port and parameters}
    constructor Create(aPortName:String; aBaudRate:integer; aPortBytes:integer;
      aPortParity:TParityType; aPortStop:TStopBits; aPortFlag:TSerialFlags; createDisconnected:boolean=true); overload;
    destructor Destroy; override;

    {Connect to the given port. Paramters like baudrate etc. can be separated with a colon,
    in key=value style, e.g. "/dev/ttyS0:baud=9600:stop=1.5".}
    procedure ConnectTo(resource:string); override; overload;

    procedure ConnectTo(aPortName:String; aBaudRate:integer; aPortBytes:integer;
      aPortParity:TParityType; aPortStop:TStopBits; aPortFlag:TSerialFlags); overload;

    {Issue a reconnect or connect to a resource created disconnected}
    procedure Connect; override;

    {Disconnect and close the commection}
    procedure Disconnect; override;

    {Write data to the resource, blocking
    When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.}
    function Write(const Buffer; Count: Longint): Longint; override;

    {Read data from the resource, blocking. Returns the actual number of bytes read
    When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.}
    function Read(var Buffer; Count: Longint): Longint; override;

    {Return the resource type identifier associated with this class. Examples could be "tcp" or
    "serial".}
    class function GetComResourceType:string; override; 

    {Creates a new object of the type of this class. Usefull if accessing the classes using
    their string type identifiers.}
    class function CreateNew:TAbstractComStream; override;
  public
    property PortName:String read fPortName;
    property PortBaud:integer read fPortBaud; 
    property PortParity:TParityType read fPortParity;
    property PortStop:TStopBits read fPortStop;
    property PortFlags:TSerialFlags read fPortFlags;
  end;

resourcestring
  StrComSer_EInvalidConnection = 'Cannot connect to the serial port "%s", it''s not well formatted!';
  StrComSer_EInvalidParameter = 'Cannot apply parameter "%s", it''s not well formatted!';
  StrComSer_ENoConnection = 'Cannot communicate with the serial port, it is not connected!';
  StrComSer_ECannotCom = 'Cannot communicate with the serial port. Exception: %s (%s)';
  StrComSer_ETimeout = 'Connection to "%s" timed out!';
  StrComSer_EInvalidPort = 'Cannot connect to the port "%s", maybe it does not exist.';
  StrComSer_ESettingsNotAccepted = 'The serial port "%s" did not accept the configuration it was programmed with!';

implementation

uses DateUtils;

procedure TSerialClientComStream.InternalConnect;
var
  state:TSerialState;
  progBytes:integer;
  progError:boolean;
begin
{$IFDEF DGB_WRITE}
  Writeln('TSerialClientComStream.InternalConnect: Port="',fPortName,'; Baud="',fPortBaud,'"');
{$ENDIF}
  if fPort<>0 then InternalDisconnect;

  fPort:=SerOpen(fPortName);
  if fPort>0 then begin
    SerSetParams(fPort, fPortBaud, fPortBytes, fPortParity, fPortStop, fPortFlags);

    //Check reading the port state to test it's existance.
    //TODO: check if given parameters match the programmed ones
    state:=SerSaveState(fPort);
    //For now, only check fPortBytes
 (*   {$IFDEF UNIX}
    progError:=false;

    progBytes:=5;
    if state.tios.c_cflag and CS6 <> 0 then
      progBytes:=6
    else if state.tios.c_cflag and CS7 <> 0 then
      progBytes:=7
    else if state.tios.c_cflag and CS7 <> 0 then
      progBytes:=8;
    if (fPortBytes <> progBytes) and
       //Check if more than 8 were expected
       not ((fPortBytes=9) and (progBytes=8)) then
         progError:=true;

    if progError then
      raise EComSerialSettingsError.CreateFmt(StrComSer_ESettingsNotAccepted, [fPortName]));
    {$ENDIF}   *)
  end
  else
    raise EComInvalidResource.CreateFmt(StrComSer_EInvalidPort, [fPortName]);
end;

procedure TSerialClientComStream.InternalDisconnect;
begin
{$IFDEF DGB_WRITE}
  Writeln('TSerialClientComStream.InternalDisconnect()');
{$ENDIF}
  if fPort<>0 then begin
    //TODO: It might be neccessary to break or reconfigure first to avoid the close timeout here
    try
      SerClose(fPort);
    finally    
      fPort:=0;
    end;
  end;
end;

constructor TSerialClientComStream.Create;
begin
  inherited Create;
  //Default values
  fPort:=0;
  fPortName:='';
  fPortBaud:=9600;
  fPortBytes:=8;
  fPortParity:=NoneParity;
  fPortStop:=SerialStop1;
  fPortFlags:=[];
end;

{Create a Serial client communication stream directly connecting to the given port and parameters}
constructor TSerialClientComStream.Create(aPortName:String; aBaudRate:integer; aPortBytes:integer;
  aPortParity:TParityType; aPortStop:TStopBits; aPortFlag:TSerialFlags; createDisconnected:boolean=true);
begin
  inherited Create;
  fPort:=0;
  fPortName:=aPortName;
  fPortBaud:=aBaudRate;
  fPortBytes:=aPortBytes;
  fPortParity:=aPortParity;
  fPortStop:=aPortStop;
  fPortFlags:=aPortFlag;
  if not createDisconnected then InternalConnect;
end;

destructor TSerialClientComStream.Destroy;
begin
  InternalDisconnect;
  fPort:=0;
  inherited Destroy;
end;

{Connect to the given port. Paramters like baudrate etc. can be separated with a colon,
in key=value style, e.g. "/dev/ttyS0;baud=9600;stop=1.5".}
procedure TSerialClientComStream.ConnectTo(resource:string);
var
  arr:TStringArray;
  resourceType, strippedResource: string;
  i:integer;

  {Helper to parse parameters}
  procedure ApplyParamFromStr(param:string);
  var
    key, value: string;
    pos:integer;
    valArr:TStringArray;
    intVal:integer;
  begin
    //Could use Split(), but this might be better:
    pos:=param.IndexOf('=');
    if pos > 0 then begin
      //If it's =0 then there's not key. So:
      key:=LowerCase(param.Substring(0, pos));
      value:=param.Substring(pos+1);

      //Parse
      case key of
        'baud':
          begin
            //Parse integer from value and apply to fPortBaud
            if not Integer.TryParse(value, intVal) then
              raise EComInvalidResourceParams.CreateFmt(StrComSer_EInvalidParameter, [param]);

            fPortBaud:=intVal;
          end;
        'bytes':
          begin
            //Parse integer from value and apply to fPortBytes
            if not Integer.TryParse(value, intVal) then
              raise EComInvalidResourceParams.CreateFmt(StrComSer_EInvalidParameter, [param]);

            fPortBytes:=intVal;
          end;
        else
          raise EComInvalidResourceParams.CreateFmt(StrComSer_EInvalidParameter, [param]);
      end;
    end
    else
      raise EComInvalidResourceParams.CreateFmt(StrComSer_EInvalidParameter, [param]);
  end;

begin
{$IFDEF DGB_WRITE}
  Writeln('TSerialClientComStream.ConnectTo("', resource, '")');
{$ENDIF}
  //Check if the resource still contains any resource type specifier, like serial:
  //or tcp. If not, infer it is serial...
  resourceType := StripComResourceTypeFromResource(resource, strippedResource);
  if (resourceType <> '') and (resourceType <> 'serial') then    
    raise EComInvalidResource.CreateFmt(StrComSer_EInvalidConnection, [resource]);

  //Check if we have any additional parameters coded into the resource string
  if strippedResource.IndexOf(';')>=0 then begin
    //Separate port name and parameters
    arr:=strippedResource.Split([';']);
    if Length(arr)<2 then
      //If there is a semicolon, it should atleast separate the port from the parameters...
      raise EComInvalidResource.CreateFmt(StrComSer_EInvalidConnection, [resource]);

    //1st parameter is the port name
    fPortName:=arr[0];

    //Parse and apply parameters
    for i:=1 to Length(arr)-1 do
      ApplyParamFromStr(arr[i]);
  end
  else
    fPortName:=strippedResource;

{$IFDEF DGB_WRITE}
  Writeln('TSerialClientComStream.ConnectTo: port="',fPortName,'", res="',strippedResource,'"');
{$ENDIF}

  InternalConnect;
end;

procedure TSerialClientComStream.ConnectTo(aPortName:String; aBaudRate:integer; aPortBytes:integer;
      aPortParity:TParityType; aPortStop:TStopBits; aPortFlag:TSerialFlags);
begin
{$IFDEF DGB_WRITE}
  Writeln('TSerialClientComStream.ConnectTo("', aPortName, '", ', aBaudRate, ', ', aPortBytes,
    ', ', Ord(aPortParity), ', ', Ord(aPortStop), ')');
{$ENDIF}
  //TODO: Check validity...
  fPortName:=aPortName;
  fPortBaud:=aBaudRate;
  fPortBytes:=aPortBytes;
  fPortParity:=aPortParity;
  fPortStop:=aPortStop;
  fPortFlags:=aPortFlag;

  InternalConnect;
end;

{Issue a reconnect or connect to a resource created disconnected}
procedure TSerialClientComStream.Connect;
begin
  InternalConnect;
end;

{Disconnect and close the commection}
procedure TSerialClientComStream.Disconnect;
begin
  InternalDisconnect;
end;

{Write data to the serial resource, blocking.
For writing, the Serial unit currently does not support timeouts, thus this
parameter is ignored.}
function TSerialClientComStream.Write(const Buffer; Count: Longint): Longint;
begin
  if fPort = 0 then
    raise EComLost.Create(StrComSer_ENoConnection);

  try
    result:=SerWrite(fPort, Buffer, Count);
  except
    on e:Exception do begin
      raise EComLost.CreateFmt(StrComSer_ECannotCom, [e.Message, e.ClassName]);
    end;
  end;
end;

{Read data from the resource, blocking. Returns the actual number of bytes read
When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.}
function TSerialClientComStream.Read(var Buffer; Count: Longint): Longint;
var
  bytesAvail:integer;
  bufPos:PByte;
begin
  if fPort = 0 then
    raise EComLost.Create(StrComSer_ENoConnection);

  //Different operation modes. Usually, a serial port reads the exact amount of
  //bytes waiting or less. If we attempt to read more, it will fail.
  //Thus, three cases:
  // - no timeout is set (Timeout = 0). In this case, we have to ask the port for
  //   the number of bytes available in the kernel buffer and read that amount or
  //   less, depending on Count.
  // - infinite timeout set. MySerial currently has no "INFINITE" option, but we can
  //   use max(LongInt) to get something close to infinity (~25 days).
  //   Additionally, wrap it into a loop to really eat time...
  // - timeout set. The timeout can be applied to the port directly and the function
  //   will block the calling thread until the number of bytes specified have been read.

  //Case one:
  if Timeout = 0 then begin
    if GetBytesWaiting(fPort, bytesAvail) then begin
      //Read that number of bytes, or less
      if bytesAvail > Count then
        bytesAvail:=Count;
      result:=SerRead(fPort, Buffer, bytesAvail);
    end
    else begin
      //Cannot ask the port for the number of bytes available.
      //Thus, try reading 1 byte as long as possible...
      result:=0;
      bufPos:=@Buffer;
      repeat
        bytesAvail:=SerRead(fPort, bufPos^, 1);
        Inc(result, bytesAvail);
        Inc(bufPos, bytesAvail);
      until (result = Count) or (bytesAvail = 0);
    end;
  end
  //Case two:
  else if Timeout = TimeoutInfinite then begin
    bufPos:=@Buffer;
    result:=0;
    repeat
      bytesAvail:=SerReadTimeout(fPort, bufPos^, Count - result, High(Longint));
      Inc(result, bytesAvail);
      Inc(bufPos, bytesAvail);
    until result = Count;
  end
  //Case three:
  else begin
    //Pass through timeout. If the returned number of bytes is not the number we
    //wanted, raise an exception if RaiseTimeout is true.
    result:=SerReadTimeout(fPort, Buffer, Count, Timeout);
    if (RaiseTimeout) and (result <> Count) then
      raise EComTimeout.CreateFmt(StrComSer_ETimeout, [fPortName]);
  end;
end;

{Return the resource type identifier associated with this class. Examples could be "tcp" or
"serial".}
class function TSerialClientComStream.GetComResourceType:string;
begin
  result:='serial';
end;       

{Creates a new object of the type of this class. Usefull if accessing the classes using
their string type identifiers.}
class function TSerialClientComStream.CreateNew:TAbstractComStream;
begin
  result:=TSerialClientComStream.Create;
end;

initialization
  //Register existance of the "serial" resource type
  ComResourceTypes.Add(TSerialClientComStream);
end.

