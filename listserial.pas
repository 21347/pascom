{listSerial: retreive a list of available serial ports
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

unit listserial;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fgl;

type
  TSerialPortEntry = class
    Name:string;           //COM-port, like /dev/ttyS0 or COM1
    DeviceName:string;     //Device name, equal in linux or e.g. \Device\USBSER000 in Windows
    FriendlyName:string;   //Description of the device
    Serial:string;         //Serial number, if available
  end;

  TSerialPortList = specialize TFPGObjectList<TSerialPortEntry>;

procedure GetSerialPorts(const toList:TStrings);

function GetSerialPortsEx:TSerialPortList;

implementation

{$IFDEF LINUX}
uses BaseUnix,unix,process;

type
  serial_struct = packed record
   aType, line: integer;
   port: cardinal;
   irq, flags, xmit_fifo_size, custom_divisor, baud_base: integer;
   close_delay: word;
   io_type: char;
   reserved_char: char;
   hub6:integer;
   closing_wait, closing_wait2: word;
   iomem_base:Pointer;
   iomem_reg_shift:word;
   port_high:integer;
   iomap_base:QWord;
 end;

const
  TIOCGSERIAL = $541E;

function _serial8250_check(devName:UnicodeString):boolean;
var
  handle:LongInt;
  ss:serial_struct;
begin
  handle:=fpopen(devName, O_RDWR or O_NOCTTY or O_NONBLOCK);
  if handle >= 0 then begin
    FillChar(ss, SizeOf(serial_struct), 0);
    if fpioctl(handle, TIOCGSERIAL, @ss)=0 then result:=(ss.aType<>0)
    else result:=false;
    fpclose(handle);
  end
  else result:=false;
end;

procedure GetSerialPorts(const toList:TStrings);
var
  sr:TUnicodeSearchRec;
  dev:UnicodeString;
begin
  if FindFirst('/sys/class/tty/*', faDirectory, sr) = 0 then begin
    repeat
      if (sr.Name<>'.') and (sr.Name<>'..') then begin
        dev:='/sys/class/tty/'+sr.Name;

        //Has a real driver associated with it?
        if DirectoryExists(dev+'/device/driver') then begin
          //Is it a serial8250 device?
          if DirectoryExists(dev+'/device/driver/serial8250') then begin
            //Need to check if the device is actually present in the system
            if _serial8250_check('/dev/'+sr.Name) then toList.Add(sr.Name);
          end
          else toList.Add('/dev/'+sr.Name);
        end;
      end;
    until FindNext(sr)<>0;
    FindClose(sr);
  end;
end;


function GetSerialPortsEx:TSerialPortList;
var
  ports:TStringList;
  aPortName,sysPortName,friendlyName:string;  
  aDevice:TSerialPortEntry;

  {Simple helper to read a file and cat the contents into the supplied string.
  Return false if the file was not found or could not be read.}
  function CatFile(fileName:string; out toString:string):boolean;
  var
    str:String;
  begin
    //Paths /sys/class/tty/ttyUSB3/device/../../product are beats to open,
    //symbolic links that have to be expanded before traveling back ../../
    //So: ask cat to do the magic...
    //Default: fail!
    result:=false;
    if not FileExists(fileName) then exit;

    result:=RunCommand('cat '+fileName, str);
    if result then toString:=Trim(str);
  end;

  {Simple helper to list all subdirectories in a directory and populate the list.
  If something goes wrong or the directory is empty, the result is false.}
  function ListAllSubdirs(inDir:string; const toList:TStrings):boolean;    
  var
    sr:TUnicodeSearchRec;
  begin
    result:=false;
    if FindFirst(ConcatPaths([inDir,'*']), faDirectory, sr) = 0 then begin
      repeat
        if (sr.Name<>'.') and (sr.Name<>'..') then begin
          toList.Add(sr.Name);
          result:=true;
        end;
      until FindNext(sr)<>0;  
      FindClose(sr);
    end;
  end;

  {The port in /sys/class/tty/ is link into /sys/devices/pci..., where the driver
  can add a product file. I found it to be in different locations, so try around...}
  function TryReadProductFile(portDir:string; out aName:string):boolean;
  begin
    result:=false;
    //Try 1st location first...
    if CatFile(ConcatPaths([portDir,'/device/../product']), aName) then
      result:=true
    else if CatFile(ConcatPaths([portDir,'/device/../../product']), aName) then
      result:=true;
  end;

  {The port in /sys/class/tty/ is link into /sys/devices/pci..., where the driver
  can add a serial file. I found it to be in different locations, so try around...}
  function TryReadSerialFile(portDir:string; out aSerial:string):boolean;
  begin
    result:=false;
    //Try 1st location first...
    if CatFile(ConcatPaths([portDir,'/device/../serial']), aSerial) then
      result:=true
    else if CatFile(ConcatPaths([portDir,'/device/../../serial']), aSerial) then
      result:=true;
  end;

  {Extract fallback-device type from the driver-name in the path. Has been seen in two
  different locations based on kernel etc.}
  function TryExtractDriverFromPath(portDir:string; out theName:string):boolean;
  var
    sl:TStringList;
    aName:String;
  begin
    result:=false;
    theName:='';
    sl:=TStringList.Create;
    try
      aName:='';
      if ListAllSubdirs(ConcatPaths([portDir, '/driver/module/drivers']), sl) then
        aName:=sl[0]
      else if ListAllSubdirs(ConcatPaths([portDir, '/device/driver/module/drivers']), sl) then
        aName:=sl[0];

      //Found something?
      if aName<>'' then begin
        theName:='Plugin Serial Port ('+aName.Substring(aName.IndexOf(':')+1)+')';
        result:=true;
      end;
    finally
      sl.Free;
    end;
  end;

begin
  result:=TSerialPortList.Create(true);

  //Start by enumerating the ports the normal way...
  ports:=TStringList.Create;
  try
    GetSerialPorts(ports);

    //Iterate over all ports and try to get additional information
    //Sources: https://github.com/Fazecast/jSerialComm, ls /sys/*
    for aPortName in ports do begin
      aDevice:=TSerialPortEntry.Create;
      result.Add(aDevice);
      aDevice.Serial:='';

      aDevice.Name:=aPortName;

      //Remove /dev/ from the name and construct the /sys/... name
      sysPortName:='/sys/class/tty/'+aPortName.Substring(5);
      aDevice.DeviceName:=sysPortName;

      //See if we can get a product name from the driver in /sys/device/...stuff.../product
      if not TryReadProductFile(sysPortName, aDevice.FriendlyName) then begin
        //Ok, need to look somewhere else.
        if not TryExtractDriverFromPath(sysPortName, aDevice.FriendlyName) then begin
          //According to the sources, this is as much as can be done.
          //Thus: look at the name...
          if sysPortName.Contains('AMA') then
            aDevice.FriendlyName:='Physical Port '+aPortName.Substring(8)
          else if sysPortName.Contains('rfcom') then
            aDevice.FriendlyName:='Bluetooth Port '+aPortName.Substring(5);
        end;
      end
      else
        //If we could read a product file, maybe the serial number is also there?
        TryReadSerialFile(sysPortName, aDevice.Serial);
    end;
  finally
    ports.Free;
  end;
end;

{$ENDIF}

{$IFDEF WINDOWS}
uses MinimalSetupApi, Windows, Registry;
 
procedure GetSerialPorts(const toList:TStrings);
var
  reg:TRegistry;
  vals:TStringList;
  value:string;
begin
  reg:=TRegistry.Create;
  try
    reg.RootKey:=HKEY_LOCAL_MACHINE;
    if reg.OpenKeyReadOnly('HARDWARE\DEVICEMAP\SERIALCOMM') then begin
      vals:=TStringList.Create;
      try
        reg.GetValueNames(vals);
        for value in vals do begin
          toList.Add(reg.ReadString(value));
        end;
      finally
        reg.CloseKey;
        vals.Free;
      end;
    end;
  finally
    reg.Free;
  end;
end;

const
  GUID_DEVCLASS_PORTS : TGUID = '{4d36e978-e325-11ce-bfc1-08002be10318}';

function GetSerialPortsEx:TSerialPortList;
var
  hDeviceInfo:HDEVINFO;
  aList:TSerialPortList;
  aDevice:TSerialPortEntry;
  enumIndex:DWORD;       
  lastError:DWORD;
  devInfoData:TSPDevInfoData;
  continueEnum, haveData:boolean;

  procedure Fallback;
  var     
    reg:TRegistry;
    vals:TStringList;  
    value:string;
  begin
    reg:=TRegistry.Create;
    try
      reg.RootKey:=HKEY_LOCAL_MACHINE;
      if reg.OpenKeyReadOnly('HARDWARE\DEVICEMAP\SERIALCOMM') then begin
        vals:=TStringList.Create;
        try
          reg.GetValueNames(vals);
          for value in vals do begin
            //Store found devices with a first set of information...
            aDevice:=TSerialPortEntry.Create;
            aDevice.Name:=String.Copy(reg.ReadString(value));
            aDevice.DeviceName:=String.Copy(value);
            aDevice.FriendlyName:='';
            aDevice.Serial:='';
            aList.Add(aDevice);
          end;
        finally
          vals.Free;
          reg.CloseKey;
        end;
      end;
    finally
      reg.Free;
    end;
  end;

  {Helper function to translate a device roperty into a string}
  function GetDevicePropertyString(propertyCode:DWORD):string;
  var
    reqSize,regType:DWORD;
    byteBuffer:PByte;
    linePtr:PChar;
    i:integer;
  begin     
    //This first call will fail (result=false, GetLastError=ERROR_INSUFFICIENT_BUFFER),
    //but still return valid data in reqSize. Well..
    reqSize:=0;
    regType:=0;
    result:='';
    SetupDiGetDeviceRegistryProperty(hDeviceInfo, devInfoData,
        propertyCode, nil, nil, 0, @reqSize);
    if reqSize<>0 then begin
      byteBuffer:=GetMem(reqsize);
      try
        if SetupDiGetDeviceRegistryProperty(hDeviceInfo, devInfoData,
             propertyCode, @regType, byteBuffer, reqSize, nil) then begin
          //Further work is dependent on regType:
          case regType of
            REG_DWORD:
              result:=IntToStr(PDWORD(byteBuffer)^);
            REG_QWORD:
              result:=IntToStr(PQWORD(byteBuffer)^);
            REG_EXPAND_SZ,
            REG_SZ:
              result:=PChar(byteBuffer);
            REG_MULTI_SZ:
              //Multiple null terminated strings terminated with a double null...
              begin
                linePtr:=PChar(byteBuffer);
                while StrLen(linePtr)>0 do begin
                  result:=result+linePtr+'; ';
                  Inc(linePtr, StrLen(linePtr)+1);
                end;
                if result.Length>0 then result:=result.Remove(result.Length-2);
              end
            else {REG_BINARY etc.}
              for i:=0 to reqSize-1 do
                result:=result+IntToHex(byteBuffer[i], 2);
          end;
        end
        else
          lastError:=GetLastError();
      finally
        FreeMem(byteBuffer);
      end;
    end
    else
      lastError:=GetLastError();
  end;

  {Helper Function to read a device' registry key}
  function GetDevicePropertyFromRegistry(keyName:PChar):string;
  var
    deviceKey:HKEY;
    keyType:DWORD;
    datasize:DWORD;
    data:PChar;
  begin
    result:='';
    deviceKey:=SetupDiOpenDevRegKey(hDeviceInfo, devInfoData, DICS_FLAG_GLOBAL, 0, DIREG_DEV, KEY_QUERY_VALUE);
    if deviceKey<>INVALID_HANDLE_VALUE then begin
      try
        dataSize:=0;
        keyType:=0;
        if RegQueryValueEx(deviceKey, keyName, nil, @keyType, nil, @dataSize) = ERROR_SUCCESS then begin
          data:=GetMem(dataSize);
          try
            if RegQueryValueEx(deviceKey, keyName, nil, @keyType, PByte(data), @dataSize) = ERROR_SUCCESS then
              result:=data;
          finally
            FreeMem(data);
          end;
        end;
      finally
        RegCloseKey(deviceKey);
      end;
    end;
  end;

begin
  aList:=TSerialPortList.Create(true);

  //Create a setupAPI object to hold information about all comports
  hDeviceInfo:=SetupDiGetClassDevs(@GUID_DEVCLASS_PORTS, nil, 0, DIGCF_PRESENT);
  if hDeviceInfo<>INVALID_HANDLE_VALUE then begin
    //Iterate through all devices
    enumIndex:=0;
    FillChar(devInfoData, SizeOf(TSPDevInfoData), 0);
    devInfoData.cbSize:=SizeOf(TSPDevInfoData);
    repeat
      //https://docs.microsoft.com/de-de/windows/win32/api/setupapi/nf-setupapi-setupdienumdeviceinfo
      //MSDN states to call GetLastError first to check if it's really the
      //last device or some other error. This, however, has to occure before any other Windows-API call, so...
      haveData:=SetupDiEnumDeviceInfo(hDeviceInfo, enumIndex, devInfoData);
      lastError:=GetLastError();
      continueEnum:=lastError <> ERROR_NO_MORE_ITEMS;

      //If SetupDiEnumDeviceInfo returned true, we can expect ot have some valid data
      if haveData then begin
        //The usage now is: for each set of information required, call
        //SetupDiGetDeviceRegistryProperty twice: first to get the buffer size required,
        //2nd to copy the data over..

        //-Prepare object to store information
        aDevice:=TSerialPortEntry.Create;

        //-HardwareID
        aDevice.DeviceName:=GetDevicePropertyString(SPDRP_HARDWAREID);
        aDevice.Name:=GetDevicePropertyFromRegistry('PortName');

        //-Friendly Name
        aDevice.FriendlyName:=GetDevicePropertyString(SPDRP_FRIENDLYNAME);

        //Add to the list...
        aList.Add(aDevice);
      end;

      //Increment and reset...
      Inc(enumIndex);
      FillChar(devInfoData, SizeOf(TSPDevInfoData), 0);
      devInfoData.cbSize:=SizeOf(TSPDevInfoData);
    until not continueEnum;
  end
  else Fallback;

  //Whether or not we could add additional information: report back what we have...
  result:=aList;
end;

{$ENDIF}
end.

