program listports;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  Classes, SysUtils, CustApp,
  listserial, fpjson, jsonparser;

type

  { TListSerialApplication }

  TListSerialApplication = class(TCustomApplication)
  private
    fLongMode:boolean;
    fRobotMode:boolean;

    procedure ListAndPrint;
  protected
    procedure DoRun; override;

    property LongMode:boolean read fLongMode write fLongMode;
    property RobotMode:boolean read fRobotMode write fRobotMode;
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
  jObject:TJSONObject;
  jArray:TJSONArray;
begin
  list:=GetSerialPortsEx;
  try
    if RobotMode then begin
      //Print JSON
      jArray:=TJSONArray.Create;
      try
        for port in list do begin
          jObject:=TJSONObject.Create;
          jObject.Add('Name', port.Name);
          jObject.Add('DeviceName', port.DeviceName);
          jObject.Add('FriendlyName', port.FriendlyName);
          jObject.Add('Serial', port.Serial);
          jArray.Add(jObject);
        end;
        Writeln(jArray.FormatJSON());
      finally
        jArray.Free;
      end;
    end
    else
      for port in list do begin
        if LongMode then begin
          Write(port.Name, ' => Device: ', port.DeviceName, '; "', port.FriendlyName, '"');
          Writeln(' (Ser#: ', port.Serial, ')');
        end
        else
          Writeln(port.Name, ' = ', port.FriendlyName);
      end;
  finally  
    list.Free;
  end;
end;

procedure TListSerialApplication.DoRun;
var
  ErrorMsg: String;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions('hlr', 'help long robot');
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
  RobotMode:=HasOption('r','robot');

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
  writeln('ListPorts (PasCom list serial)');
  writeln('Usage: ', ExeName, ' -h {-l/-r}');
  writeln;
  writeln(' -h, --help   : Print what your''e reading here');
  writeln(' -l, --long   : Long-Mode (print all I have)');
  writeln(' -r, --robot  : Make the list machine-readable (using json), imples --long.');
end;

var
  Application: TListSerialApplication;
begin
  Application:=TListSerialApplication.Create(nil);
  Application.Title:='PasCom list serial';
  Application.Run;
  Application.Free;
end.

