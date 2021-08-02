{This unit is based on the JEDI Code Library for the CfgMgr32 library,
to be obtained here: https://github.com/project-jedi/jvcl/blob/master/jvcl/run/CfgMgr32.pas}

unit MinimalWin32USB;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils;

type
  DEVINST = DWORD;

function CM_Get_Parent(var dnDevInstParent: DEVINST;
  dnDevInst: DEVINST; ulFlags: ULONG): DWORD; stdcall;

function CM_Get_Device_IDA(dnDevInst: DEVINST; Buffer: PAnsiChar;
  BufferLen: ULONG; ulFlags: ULONG): DWORD; stdcall;
function CM_Get_Device_IDW(dnDevInst: DEVINST; Buffer: PWideChar;
  BufferLen: ULONG; ulFlags: ULONG): DWORD; stdcall;
function CM_Get_Device_ID(dnDevInst: DEVINST; Buffer: PTSTR;
  BufferLen: ULONG; ulFlags: ULONG): DWORD; stdcall;

const
  GUID_DEVINTERFACE_USB_HUB : TGUID = '{f18a0e88-c30c-11d0-8815-00a0c906bed8}';

type
  _USB_DESCRIPTOR_REQUEST = packed record
    ConnectionIndex: ULONG;
    SetupPacket_bmRequest,
    SetupPacket_bRequest: UCHAR;
    SetupPacket_wValue,
    SetupPacket_wIndex,
    SetupPacket_wLength: USHORT;
    Data: array [0..0] of UCHAR;
  end;
  TUSBDescriptorRequest = _USB_DESCRIPTOR_REQUEST;
  PUSBDescriptorRequest = ^_USB_DESCRIPTOR_REQUEST;

  _USB_DEVICE_DESCRIPTOR = packed record
    bLength: UCHAR;
    bDescriptorType: UCHAR;
    bcdUSB: USHORT;
    bDeviceClass: UCHAR;
    bDeviceSubClass: UCHAR;
    bDeviceProtocol: UCHAR;
    bMaxPacketSize0: UCHAR;
    idVendor: USHORT;
    idProduct: USHORT;
    bcdDevice: USHORT;
    iManufacturer: UCHAR;
    iProduct: UCHAR;
    iSerialNumber: UCHAR;
    bNumConfigurations: UCHAR;
  end;
  PUSBDeviceDescriptor = ^_USB_DEVICE_DESCRIPTOR;
  TUSBDeviceDescriptor = _USB_DEVICE_DESCRIPTOR;      

const
  MAXIMUM_USB_STRING_LENGTH   = 255;

type
  _USB_STRING_DESCRIPTOR = packed record
    bLength: UCHAR;
    bDescriptorType: UCHAR;
    bString: array [0..MAXIMUM_USB_STRING_LENGTH-1] of WCHAR;
  end;
  PUSBStringDescriptor = ^_USB_STRING_DESCRIPTOR;
  TUSBStringDescriptor = _USB_STRING_DESCRIPTOR;

const
  USB_REQUEST_GET_STATUS          = $00;
  USB_REQUEST_CLEAR_FEATURE       = $01;
  USB_REQUEST_SET_FEATURE         = $03;
  USB_REQUEST_SET_ADDRESS         = $05;
  USB_REQUEST_GET_DESCRIPTOR      = $06;
  USB_REQUEST_SET_DESCRIPTOR      = $07;
  USB_REQUEST_GET_CONFIGURATION   = $08;
  USB_REQUEST_SET_CONFIGURATION   = $09;
  USB_REQUEST_GET_INTERFACE       = $0A;
  USB_REQUEST_SET_INTERFACE       = $0B;
  USB_REQUEST_SYNC_FRAME          = $0C;

const
  USB_DEVICE_DESCRIPTOR_TYPE         = $01;
  USB_CONFIGURATION_DESCRIPTOR_TYPE  = $02;
  USB_STRING_DESCRIPTOR_TYPE         = $03;
  USB_INTERFACE_DESCRIPTOR_TYPE      = $04;
  USB_ENDPOINT_DESCRIPTOR_TYPE       = $05;

const
  IOCTL_USB_GET_DESCRIPTOR_FROM_NODE_CONNECTION = $00220410;

function IssueDeviceIORequestForUSBDescriptor(hUsbHub:THandle;
  const usbPortNumber: word; out desc:TUSBDeviceDescriptor):boolean;

function IssueDeviceIORequestForUSBStringDescriptor(hUsbHub:THandle;
  const usbPortNumber: word; const iIndex:UCHAR; out stringDesc:string):boolean;

//Stolen from ActiveX.pas
function StringFromGUID2(const rguid:TGUID; lpsz:PWideChar; cchMax:longint):longint; stdcall;

implementation

function CM_Get_Parent(var dnDevInstParent: DEVINST;
  dnDevInst: DEVINST; ulFlags: ULONG): DWORD; stdcall; external 'cfgmgr32.dll';

function CM_Get_Device_IDA(dnDevInst: DEVINST; Buffer: PAnsiChar;
  BufferLen: ULONG; ulFlags: ULONG): DWORD; stdcall; external 'cfgmgr32.dll';
function CM_Get_Device_IDW(dnDevInst: DEVINST; Buffer: PWideChar;
  BufferLen: ULONG; ulFlags: ULONG): DWORD; stdcall; external 'cfgmgr32.dll';
function CM_Get_Device_ID(dnDevInst: DEVINST; Buffer: PTSTR;
  BufferLen: ULONG; ulFlags: ULONG): DWORD; stdcall; external 'cfgmgr32.dll' name 'CM_Get_Device_IDA';


function IssueDeviceIORequestForUSBDescriptor(hUsbHub:THandle; const usbPortNumber: word; out desc:TUSBDeviceDescriptor):boolean;
var
  requestPacket: PUSBDescriptorRequest;
  deviceDescriptor: PUSBDeviceDescriptor;
  bufferSize: cardinal;
  bytesReturned: cardinal;
begin
  //Get Buffer for descriptor request
  bufferSize:=SizeOf(TUSBDescriptorRequest) + SizeOf(TUSBDeviceDescriptor);
  requestPacket:=GetMem(bufferSize);
  FillChar(requestPacket^, bufferSize, 0);
  deviceDescriptor:=PUSBDeviceDescriptor(@requestPacket^.Data);

  //fill information in packet
  requestPacket^.SetupPacket_bmRequest := $80;
  requestPacket^.SetupPacket_bRequest := USB_REQUEST_GET_DESCRIPTOR;
  requestPacket^.ConnectionIndex := usbPortNumber;
  requestPacket^.SetupPacket_wValue := (USB_DEVICE_DESCRIPTOR_TYPE shl 8) or 0 (*Since only 1 device descriptor => index : 0*);
  requestPacket^.SetupPacket_wLength := SizeOf(TUSBDeviceDescriptor);

  //Issue ioctl
  bytesReturned := 0;
  if DeviceIoControl(hUsbHub, IOCTL_USB_GET_DESCRIPTOR_FROM_NODE_CONNECTION,
                     requestPacket, bufferSize, requestPacket, bufferSize,
                     bytesReturned, nil) then begin
    //OK! We should have the descriptor in our buffer, copy it over!
    Move(deviceDescriptor^, desc, SizeOf(TUSBDeviceDescriptor));
    result:=true;
  end
  else
    result:=false;
end;

function IssueDeviceIORequestForUSBStringDescriptor(hUsbHub:THandle;
  const usbPortNumber: word; const iIndex:UCHAR; out stringDesc:string):boolean;
var
  requestPacket: PUSBDescriptorRequest;
  stringDescriptor: PUSBStringDescriptor;
  bufferSize: cardinal;
  bytesReturned: cardinal;
begin
  //Get Buffer for descriptor request. The maximum size is not MAXIMUM_USB_STRING_LENGTH + the
  //string descriptor request header, but MAXIMUM_USB_STRING_LENGTH in bytes (not
  //MAXIMUM_USB_STRING_LENGTH*SizeOf(WCHAR) either..
  bufferSize:=SizeOf(TUSBDescriptorRequest) + MAXIMUM_USB_STRING_LENGTH;
  requestPacket:=GetMem(bufferSize);
  try
    FillChar(requestPacket^, bufferSize, 0);
    stringDescriptor:=PUSBStringDescriptor(@requestPacket^.Data);

    //fill information in packet
    requestPacket^.SetupPacket_bmRequest := $80;
    requestPacket^.SetupPacket_bRequest := USB_REQUEST_GET_DESCRIPTOR;
    requestPacket^.ConnectionIndex := usbPortNumber;
    requestPacket^.SetupPacket_wValue := (USB_STRING_DESCRIPTOR_TYPE shl 8) or iIndex;
    requestPacket^.SetupPacket_wLength := MAXIMUM_USB_STRING_LENGTH;

    //Issue ioctl
    bytesReturned := 0;
    stringDesc:='';
    if DeviceIoControl(hUsbHub, IOCTL_USB_GET_DESCRIPTOR_FROM_NODE_CONNECTION,
                       requestPacket, bufferSize, requestPacket, bufferSize,
                       bytesReturned, nil) then begin
      //OK! We should have the descriptor in our buffer, check some things...
      if (stringDescriptor^.bLength > 0) and
         (stringDescriptor^.bDescriptorType = USB_STRING_DESCRIPTOR_TYPE) then begin
        //Copy the data over. It's Unicode WChar, convert that to FPCs strings
        stringDesc := WideCharToString(PWideChar(@stringDescriptor^.bString[0]));
        result:=true;
      end
      else
        result:=false;
    end
    else
      result:=false;
  finally
    FreeMem(requestPacket);
  end;
end;

function StringFromGUID2(const rguid:TGUID; lpsz:PWideChar; cchMax:longint):longint; stdcall; external  'ole32.dll' name 'StringFromGUID2';

end.

