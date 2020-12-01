{pasComTCP: TCP/IP driver for the pasCom framework using Unix sockets
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

unit pasComTCP;

{$mode objfpc}{$H+}

{$IFDEF DEBUG}
{$DEFINE DGB_WRITE}
{$ENDIF}

interface

uses
  Classes, SysUtils, pasCom, fpAsync, fpSock;

type
  TTCPClientComStreamUnix = class(TAbstractComStream)
  private
    fTCP:TTCPClient;
    fHost:string;
    fPort:word;
    fEvent:TEventLoop;

    procedure InternalConnect;
    procedure InternalDisconnect;
  public
    constructor Create; overload;

    {Create a TCP client communication stream directly connecting to the given host and port}
    constructor Create(aHost:String; aPort:word); overload;
    destructor Destroy; override;

    {Connect to the given host or address. Both are separated using a ':',
    resulting to "<host>:<port>".}
    procedure ConnectTo(resource:string); override;

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
    property Host:String read fHost;
    property Port:word read fPort;
  end;

resourcestring
  StrComTCP_EInvalidConnection = 'Cannot connect to the resource "%s", it''s not well formatted to host:port!';
  StrComTCP_ENoConnection = 'Cannot communicate with the TCP resource, it is not connected!';
  StrComTCP_ECannotCom = 'Cannot communicate with the TCP resource. Exception: %s (%s)';
  StrComTCP_ETimeout = 'Connection timed out!';

implementation

uses DateUtils;

procedure TTCPClientComStreamUnix.InternalConnect;
begin       
{$IFDEF DGB_WRITE}
  Writeln('TTCPClientComStreamUnix.InternalConnect: Host="',fHost,'; Port="',fPort,'"');
{$ENDIF}
  if Assigned(fTCP) then InternalDisconnect;
  fTCP:=TTCPClient.Create(nil);
  fTCP.Host:=fHost;
  fTCP.Port:=fPort;
  fEvent:=TEventLoop.Create;
  fTCP.EventLoop:=fEvent;
  fEvent.Run;
  fTCP.Active:=true;
end;

procedure TTCPClientComStreamUnix.InternalDisconnect;
begin
{$IFDEF DGB_WRITE}
  Writeln('TTCPClientComStreamUnix.InternalDisconnect()');
{$ENDIF}
  if Assigned(fTCP) then begin
    if fTCP.Active then
      fTCP.Active:=false;
    FreeAndNil(fTCP);
    FreeAndNil(fEvent);
  end;
end;

constructor TTCPClientComStreamUnix.Create;
begin
  inherited Create;
  fHost:='';
  fPort:=0;
  fTCP:=nil;
  fEvent:=nil;
end;

{Create a TCP client communication stream directly connecting to the given host and port}
constructor TTCPClientComStreamUnix.Create(aHost:String; aPort:word);
begin
  inherited Create;
  fHost:=aHost;
  fPort:=aPort;
  fTCP:=nil; 
  fEvent:=nil;
  InternalConnect;
end;

destructor TTCPClientComStreamUnix.Destroy;
begin
  InternalDisconnect;
  fHost:='';
  fPort:=0;
  inherited Destroy;
end;

{Connect to the given host or address. Both are separated using a ':',
resulting to "<host>:<port>".}
procedure TTCPClientComStreamUnix.ConnectTo(resource:string);
var
  arr:TStringArray;
  newPort: integer;
  newHost: string;
begin   
{$IFDEF DGB_WRITE}
  Writeln('TTCPClientComStreamUnix.ConnectTo("', resource, '")');
{$ENDIF}
  arr:=resource.Split([':']);
  if Length(arr)<>2 then
    raise EComInvalidResource.CreateFmt(StrComTCP_EInvalidConnection, [resource]);

{$IFDEF DGB_WRITE}
  Writeln('TTCPClientComStreamUnix.ConnectTo: [0]="',arr[0],'; [1]="',arr[1],'"');
{$ENDIF}

  newPort:=StrToIntDef(arr[1], -1);
  newHost:=arr[0];
  if (newPort < 0) or (newPort > High(word)) or (Length(newHost) = 0) then
    raise EComInvalidResource.CreateFmt(StrComTCP_EInvalidConnection, [resource]);

  fPort:=newPort;
  fHost:=newHost;

  InternalConnect;
end;

{Disconnect and close the commection}
procedure TTCPClientComStreamUnix.Disconnect;
begin
  InternalDisconnect;
end;

{Write data to the resource, blocking
When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.}
function TTCPClientComStreamUnix.Write(const Buffer; Count: Longint): Longint;
begin
  if not Assigned(fTCP) then
    raise EComLost.Create(StrComTCP_ENoConnection);

  if not fTCP.Active then
    raise EComLost.Create(StrComTCP_ENoConnection);

  try
    result:=fTCP.Stream.Write(Buffer, Count);
  except
    on e:Exception do begin
      raise EComLost.CreateFmt(StrComTCP_ECannotCom, [e.Message, e.ClassName]);
    end;
  end;
end;

{Read data from the resource, blocking. Returns the actual number of bytes read
When a timeout occurs between receiving bytes, an exception is raised if RaiseTimeout is set to true.}
function TTCPClientComStreamUnix.Read(var Buffer; Count: Longint): Longint;
var
  startTime:TDateTime;
  hasTimeout:boolean;
begin
  if not Assigned(fTCP) then
    raise EComLost.Create(StrComTCP_ENoConnection);

  if not fTCP.Active then
    raise EComLost.Create(StrComTCP_ENoConnection);

  startTime:=Now;
  repeat
    try
      result:=fTCP.Stream.Read(Buffer, Count);

      //Check timeout
      hasTimeout := MilliSecondsBetween(Now, startTime) > Timeout;

      if (not hasTimeout) and (result = 0) then Sleep(5); //just enough to let the scheduler jump to another thread. Typical granualty is >10ms anyway..
    except
      on e:Exception do
        raise EComLost.CreateFmt(StrComTCP_ECannotCom, [e.Message, e.ClassName]);
    end;
  until (result<>0) or hasTimeout;

  if hasTimeout and RaiseTimeout and (Timeout <> 0) then
    raise EComTimeout.Create(StrComTCP_ETimeout);
end;          

{Return the resource type identifier associated with this class. Examples could be "tcp" or
"serial".}
class function TTCPClientComStreamUnix.GetComResourceType:string;
begin
  result:='tcp';
end;

{Creates a new object of the type of this class. Usefull if accessing the classes using
their string type identifiers.}
class function TTCPClientComStreamUnix.CreateNew:TAbstractComStream;
begin
  result:=TTCPClientComStreamUnix.Create;
end;

initialization
  //Register existance of the "typ" resource type
  ComResourceTypes.Add(TTCPClientComStreamUnix);
end.

