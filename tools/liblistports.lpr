library liblistports;

{$mode objfpc}{$H+}

uses
  Classes,
  listserial;

const
  COL_NAME = 0;
  COL_DEVICE = 1;
  COL_FRIENDLYNAME = 2;
  COL_SERIAL = 3;
  COL_MAX = COL_SERIAL;
  COL_MIN = COL_NAME;

const
  ERR_INVALID_LIST = -1;
  ERR_INVALID_COLUMN = -2;
  ERR_INDEX_OUT_OF_BOUNDS = -3;
  ERR_INVALID_PARAMETERS = -4;
  ERR_BUFFER_TO_SMALL = -5;
  ERR_OTHER = -6;

function ListPorts:PtrUInt; stdcall;
var
  list:TSerialPortList;
begin
  list:=GetSerialPortsEx;
  result:=PtrUInt(list);
end;

procedure FreePortList(const list:PtrUInt); stdcall;
begin
  if list<>0 then
    TSerialPortList(list).Free;
end;

function GetNumberOfPorts(const list:PtrUInt):integer; stdcall;
begin
  if list<>0 then
    result:=TSerialPortList(list).Count
  else
    result:=ERR_INVALID_LIST;
end;

function GetListEntryA(const list:PtrUInt; column, entry:integer; buf:PChar; bufLen:integer; required:PInteger):integer; stdcall;
var
  str:string;
  aList:TSerialPortList;
begin
  result:=ERR_OTHER;
  if list<>0 then begin
    aList:=TSerialPortList(list);
    if (entry >= 0) and (entry < aList.Count) then begin
      if (column >= COL_MIN) and (column <= COL_MAX) then begin
        case column of
          COL_NAME:         str:=aList[entry].Name;
          COL_DEVICE:       str:=aList[entry].DeviceName;
          COL_FRIENDLYNAME: str:=aList[entry].FriendlyName;
          COL_SERIAL:       str:=aList[entry].Serial;
        end;

        if required<>nil then
          required^:=Length(str);
        if bufLen < Length(str) then
          result:=ERR_BUFFER_TO_SMALL
        else begin
          Move(str[1], buf^, Length(str));
          result:=Length(str);
        end;
      end
      else
        result:=ERR_INVALID_COLUMN;
    end
    else
      result:=ERR_INDEX_OUT_OF_BOUNDS;
  end
  else
    result:=ERR_INVALID_LIST;
end;

function GetListEntryW(const list:PtrUInt; column, entry:integer; buf:PWideChar; bufLen:integer; required:PInteger):integer; stdcall;
var
  str:WideString;
  aList:TSerialPortList;
begin
  result:=ERR_OTHER;
  if list<>0 then begin
    aList:=TSerialPortList(list);
    if (entry >= 0) and (entry < aList.Count) then begin
      if (column >= COL_MIN) and (column <= COL_MAX) then begin
        case column of
          COL_NAME:         str:=aList[entry].Name;
          COL_DEVICE:       str:=aList[entry].DeviceName;
          COL_FRIENDLYNAME: str:=aList[entry].FriendlyName;
          COL_SERIAL:       str:=aList[entry].Serial;
        end;

        if required<>nil then
          required^:=Length(str);
        if bufLen < Length(str) then
          result:=ERR_BUFFER_TO_SMALL
        else begin
          Move(str[1], buf^, Length(str)*2);
          result:=Length(str);
        end;
      end
      else
        result:=ERR_INVALID_COLUMN;
    end
    else
      result:=ERR_INDEX_OUT_OF_BOUNDS;
  end
  else
    result:=ERR_INVALID_LIST;
end;

exports
  ListPorts,
  FreePortList,
  GetNumberOfPorts,
  GetListEntryA,
  GetListEntryW;

begin
end.

