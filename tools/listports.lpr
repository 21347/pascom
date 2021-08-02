program listports;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, CustApp,
  listserial;

type

  { TListSerialApplication }

  TListSerialApplication = class(TCustomApplication)
  private
    fLongMode:boolean;

    procedure ListAndPrint;
  protected
    procedure DoRun; override;

    property LongMode:boolean read fLongMode write fLongMode;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ TListSerialApplication }


procedure TListSerialApplication.ListAndPrint;
var
  list:TSerialPortList;
  port:TSerialPortEntry;
begin
  list:=GetSerialPortsEx;
  for port in list do begin
    if LongMode then begin
      Write(port.Name, ' => Device: ', port.DeviceName, '; "', port.FriendlyName, '"');
      Writeln(' (Ser#: ', port.Serial, ')');
    end
    else
      Writeln(port.Name, ' = ', port.FriendlyName);
  end;
  list.Free;
end;

procedure TListSerialApplication.DoRun;
var
  ErrorMsg: String;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions('hl', 'help:long');
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;

  // parse parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;

  // Config
  LongMode:=HasOption('l', 'long');

  // List and print...
  ListAndPrint;

  // stop program loop
  Terminate;
end;

constructor TListSerialApplication.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TListSerialApplication.Destroy;
begin
  inherited Destroy;
end;

procedure TListSerialApplication.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ', ExeName, ' -h');
end;

var
  Application: TListSerialApplication;
begin
  Application:=TListSerialApplication.Create(nil);
  Application.Title:='PasCom list serial';
  Application.Run;
  Application.Free;
end.

