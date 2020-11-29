{ Unit for handling the serial interfaces for Linux and similar Unices.
  (c) 2000 Sebastian Guenther, sg@freepascal.org; modified MarkMLl 2012.
}

function SerOpen(const DeviceName: String): TSerialHandle;
begin
  Result := fpopen(DeviceName, O_RDWR or O_NOCTTY);
end;

procedure SerClose(Handle: TSerialHandle);
begin
  fpClose(Handle);
end;

procedure SerFlush(Handle: TSerialHandle); deprecated;
begin
  fpfsync(Handle);
end;

procedure SerSync(Handle: TSerialHandle);
begin
  fpfsync(Handle)
end;

procedure SerDrain(Handle: TSerialHandle);
begin
  tcdrain(Handle)
end;

procedure SerFlushInput(Handle: TSerialHandle);
begin
  tcflush(Handle, TCIFLUSH)
end;

procedure SerFlushOutput(Handle: TSerialHandle);
begin
  tcflush(Handle, TCOFLUSH)
end;

function SerRead(Handle: TSerialHandle; var Buffer; Count: LongInt): LongInt;
begin
  Result := fpRead(Handle, Buffer, Count);
end;

function SerWrite(Handle: TSerialHandle; Const Buffer; Count: LongInt): LongInt;
begin
  Result := fpWrite(Handle, Buffer, Count);
end;

procedure SerSetParams(Handle: TSerialHandle; BitsPerSec: LongInt;
  ByteSize: Integer; Parity: TParityType; StopBits: TStopBits;
  Flags: TSerialFlags);
var
  tios: termios;
begin
  FillChar(tios, SizeOf(tios), #0);

  case BitsPerSec of
    50: tios.c_cflag := B50;
    75: tios.c_cflag := B75;
    110: tios.c_cflag := B110;
    134: tios.c_cflag := B134;
    150: tios.c_cflag := B150;
    200: tios.c_cflag := B200;
    300: tios.c_cflag := B300;
    600: tios.c_cflag := B600;
    1200: tios.c_cflag := B1200;
    1800: tios.c_cflag := B1800;
    2400: tios.c_cflag := B2400;
    4800: tios.c_cflag := B4800;
    19200: tios.c_cflag := B19200;
    38400: tios.c_cflag := B38400;
    57600: tios.c_cflag := B57600;
    115200: tios.c_cflag := B115200;
    230400: tios.c_cflag := B230400;
{$ifndef BSD}
    460800: tios.c_cflag := B460800;
{$endif}
    500000: tios.c_cflag := B500000;
    921600: tios.c_cflag := B921600;
    1000000: tios.c_cflag := B1000000;
    1152000: tios.c_cflag := B1152000;
    1500000: tios.c_cflag := B1500000;
    2000000: tios.c_cflag := B2000000;
    2500000: tios.c_cflag := B2500000;
    3000000: tios.c_cflag := B3000000;
    3500000: tios.c_cflag := B3500000;
    4000000: tios.c_cflag := B4000000;
    else tios.c_cflag := B9600;
  end;
{$ifndef SOLARIS}
  tios.c_ispeed := tios.c_cflag;
  tios.c_ospeed := tios.c_ispeed;
{$endif}

  tios.c_cflag := tios.c_cflag or CREAD or CLOCAL;

  case ByteSize of
    5: tios.c_cflag := tios.c_cflag or CS5;
    6: tios.c_cflag := tios.c_cflag or CS6;
    7: tios.c_cflag := tios.c_cflag or CS7;
    else tios.c_cflag := tios.c_cflag or CS8;
  end;

  case Parity of
    OddParity: tios.c_cflag := tios.c_cflag or PARENB or PARODD;
    EvenParity: tios.c_cflag := tios.c_cflag or PARENB;
  end;

  //Set the 2-Stop-Bit bit. For serial lines with e.g. 5 bits word, this will be
  //interpreted as 1.5 stop bits accodring to kernel sources
  //https://stackoverflow.com/questions/46905431/linux-serial-port-1-5-stop-bits
  if not (StopBits = SerialStop1) then
    tios.c_cflag := tios.c_cflag or CSTOPB;

  if RtsCtsFlowControl in Flags then
    tios.c_cflag := tios.c_cflag or CRTSCTS;

  tcflush(Handle, TCIOFLUSH);
  tcsetattr(Handle, TCSANOW, tios)
end;

function SerSaveState(Handle: TSerialHandle): TSerialState;
begin
  fpioctl(Handle, TIOCMGET, @Result.LineState);
//  fpioctl(Handle, TCGETS, @Result.tios);
  TcGetAttr(handle,result.tios);

end;

procedure SerRestoreState(Handle: TSerialHandle; State: TSerialState);
begin
//  fpioctl(Handle, TCSETS, @State.tios);
    TCSetAttr(handle,TCSANOW,State.tios);
    fpioctl(Handle, TIOCMSET, @State.LineState);
end;

procedure SerSetDTR(Handle: TSerialHandle; State: Boolean);
const
  DTR: Cardinal = TIOCM_DTR;
begin
  if State then
    fpioctl(Handle, TIOCMBIS, @DTR)
  else
    fpioctl(Handle, TIOCMBIC, @DTR);
end;

procedure SerSetRTS(Handle: TSerialHandle; State: Boolean);
const
  RTS: Cardinal = TIOCM_RTS;
begin
  if State then
    fpioctl(Handle, TIOCMBIS, @RTS)
  else
    fpioctl(Handle, TIOCMBIC, @RTS);
end;

function SerGetCTS(Handle: TSerialHandle): Boolean;
var
  Flags: Cardinal;
begin
  fpioctl(Handle, TIOCMGET, @Flags);
  Result := (Flags and TIOCM_CTS) <> 0;
end;

function SerGetDSR(Handle: TSerialHandle): Boolean;
var
  Flags: Cardinal;
begin
  fpioctl(Handle, TIOCMGET, @Flags);
  Result := (Flags and TIOCM_DSR) <> 0;
end;

function SerGetCD(Handle: TSerialHandle): Boolean;
var
  Flags: Cardinal;
begin
  fpioctl(Handle, TIOCMGET, @Flags);
  Result := (Flags and TIOCM_CD) <> 0
end;

function SerGetRI(Handle: TSerialHandle): Boolean;
var
  Flags: Cardinal;
begin
  fpioctl(Handle, TIOCMGET, @Flags);
  Result := (Flags and TIOCM_RI) <> 0;
end;

procedure SerBreak(Handle: TSerialHandle; mSec: LongInt= 0; sync: boolean= true);
begin
  if sync then
    tcdrain(Handle);
  if mSec <= 0 then
    tcsendbreak(Handle, Abs(mSec))
  else
    tcsendbreak(Handle, Trunc(mSec / 250));
  if sync then
    tcdrain(Handle)
end;

function SerReadTimeout(Handle: TSerialHandle; var Buffer; mSec: LongInt): LongInt;

VAR     readSet: TFDSet;
        selectTimeout: TTimeVal;

begin
  fpFD_ZERO(readSet);
  fpFD_SET(Handle, readSet);
  selectTimeout.tv_sec := mSec div 1000;
  selectTimeout.tv_usec := (mSec mod 1000) * 1000;
  result := 0;
  if fpSelect(Handle + 1, @readSet, nil, nil, @selectTimeout) > 0 then
    result := fpRead(Handle, Buffer, 1)
end { SerReadTimeout } ;

{$ifdef LINUX}
  {$define SELECT_UPDATES_TIMEOUT}
{$endif}

{$ifdef SELECT_UPDATES_TIMEOUT}

function SerReadTimeout(Handle: TSerialHandle; var Buffer; count: LongInt; mSec: Cardinal): LongInt;

VAR     readSet: TFDSet;
        selectTimeout: TTimeVal;
        bufPtr: PByte;
        eaten: Longint;
begin
  fpFD_ZERO(readSet);
  fpFD_SET(Handle, readSet);
  selectTimeout.tv_sec := mSec div 1000;
  selectTimeout.tv_usec := (mSec mod 1000) * 1000;
  result := 0;

// Note: this variant of fpSelect() is a thin wrapper around the kernel's syscall.
// In the case of Linux the syscall DOES update the timeout parameter.
  bufPtr:=@Buffer;
  while fpSelect(Handle + 1, @readSet, nil, nil, @selectTimeout) > 0 do begin
    eaten := fpRead(Handle, bufPtr^, count - result);
    Inc(result, eaten);
    Inc(bufPtr, eaten);

    if result >= count then
      break;
    if Assigned(SerialIdle) then
      SerialIdle(Handle)
  end
end { SerReadTimeout } ;

{$else}

function SerReadTimeout(Handle: TSerialHandle; var Buffer: array of byte; count, mSec: LongInt): LongInt;

VAR     readSet: TFDSet;
        selectTimeout: TTimeVal;
        uSecOnEntry, uSecElapsed: QWord;

  function now64uSec: QWord;

  var   tv: timeval;

  begin
    fpgettimeofday(@tv, nil);
    result := tv.tv_sec * 1000000 + tv.tv_usec
  end { now64uSec } ;

begin
  fpFD_ZERO(readSet);
  fpFD_SET(Handle, readSet);
  selectTimeout.tv_sec := mSec div 1000;
  selectTimeout.tv_usec := (mSec mod 1000) * 1000;
  result := 0;
  uSecOnEntry := now64uSec;

// Note: this variant of fpSelect() is a thin wrapper around the kernel's syscall.
// In the case of Solaris the syscall DOES NOT update the timeout parameter.

  while fpSelect(Handle + 1, @readSet, nil, nil, @selectTimeout) > 0 do begin
    Inc(result,fpRead(Handle, Buffer[result], count - result));
    uSecElapsed := now64uSec - uSecOnEntry;
    if (result >= count) or (uSecElapsed >= mSec * 1000) then
      break;
    selectTimeout.tv_sec := (mSec * 1000 - uSecElapsed) div 1000000;
    selectTimeout.tv_usec := (mSec * 1000 - uSecElapsed) mod 1000000;
    if Assigned(SerialIdle) then
      SerialIdle(Handle)
  end
end { SerReadTimeout } ;

{$endif}

function GetBytesWaiting(Handle: TSerialHandle; out bytesAtPort:integer):boolean;
var
  data:PtrUint;
  pdata:PPtrUInt;
const
  FIONREAD = $541B;
begin
  data:=0;
  pdata:=@data;
  result := fpioctl(Handle, FIONREAD, pdata) >= 0;
  if result then bytesAtPort:=data;
end;
