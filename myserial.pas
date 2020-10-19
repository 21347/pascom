{This unit was originally part of the FreePascal RTL library. It was adapted at some points to allow easier use on different platforms
and will stay in this repository under the original FreePascal license (see e.g. https://wiki.lazarus.freepascal.org/licensing) until the
changes could be merged back to master, if possible.}

unit MySerial;

{$if defined(UNIX)}
  {$MODE objfpc}
  {$H+}
  {$PACKRECORDS C}
{$elseif defined(WINDOWS)}
  {$MODE objfpc}
  {$H+}
{$else}
{$warning MySerial is not supported on your platform!}
{$endif}

interface

//Uses    
{$if defined(UNIX)}
uses BaseUnix,termio,unix; 
{$elseif defined(WINDOWS)}   
uses Windows;
{$endif}

//Global Definitions

type
  {$if defined(UNIX)}
  TSerialHandle = LongInt;
  {$elseif defined(WINDOWS)}    
  TSerialHandle = THandle;
  {$endif}

  TParityType = (NoneParity, OddParity, EvenParity);

  TStopBits = (SerialStop1, SerialStop15, SerialStop2);

  TSerialFlags = set of (RtsCtsFlowControl);

  {$if defined(UNIX)}
  TSerialState = record
    LineState: LongWord;
    tios: termios;
  end;       
  {$elseif defined(WINDOWS)}
  TSerialState = TDCB;
  {$endif}

type    TSerialIdle= procedure(h: TSerialHandle);
                                          
  { Set this to a shim around Application.ProcessMessages if calling SerReadTimeout(),
    SerBreak() etc. from the main thread so that it doesn't lock up a Lazarus app. }
var     SerialIdle: TSerialIdle= nil;

//Platform independant interface


{ Open the serial device with the given device name, for example:
    /dev/ttyS0, /dev/ttyS1... for normal serial ports
    /dev/ttyI0, /dev/ttyI1... for ISDN emulated serial ports
    other device names are possible; refer to your OS documentation.
  Returns "0" if device could not be found }
function SerOpen(const DeviceName: String): TSerialHandle;

{ Closes a serial device previously opened with SerOpen. }
procedure SerClose(Handle: TSerialHandle);

{ Flushes the data queues of the given serial device. DO NOT USE THIS:
  use either SerSync (non-blocking) or SerDrain (blocking). }
procedure SerFlush(Handle: TSerialHandle); deprecated;

{ Suggest to the kernel that buffered output data should be sent. This
  is unlikely to have a useful effect except possibly in the case of
  buggy ports that lose Tx interrupts, and is implemented as a preferred
  alternative to the deprecated SerFlush procedure. }
procedure SerSync(Handle: TSerialHandle);

{ Wait until all buffered output has been transmitted. It is the caller's
  responsibility to ensure that this won't block permanently due to an
  inappropriate handshake state. }
procedure SerDrain(Handle: TSerialHandle);

{ Discard all pending input. }
procedure SerFlushInput(Handle: TSerialHandle);

{ Discard all unsent output. }
procedure SerFlushOutput(Handle: TSerialHandle);

{ Reads a maximum of "Count" bytes of data into the specified buffer.
  Result: Number of bytes read. }
function SerRead(Handle: TSerialHandle; var Buffer; Count: LongInt): LongInt;

{ Tries to write "Count" bytes from "Buffer".
  Result: Number of bytes written. }
function SerWrite(Handle: TSerialHandle; Const Buffer; Count: LongInt): LongInt;

procedure SerSetParams(Handle: TSerialHandle; BitsPerSec: LongInt;
  ByteSize: Integer; Parity: TParityType; StopBits: TStopBits;
  Flags: TSerialFlags);

{ Saves and restores the state of the serial device. }
function SerSaveState(Handle: TSerialHandle): TSerialState;
procedure SerRestoreState(Handle: TSerialHandle; State: TSerialState);

{ Getting and setting the line states directly. }
procedure SerSetDTR(Handle: TSerialHandle; State: Boolean);
procedure SerSetRTS(Handle: TSerialHandle; State: Boolean);
function SerGetCTS(Handle: TSerialHandle): Boolean;
function SerGetDSR(Handle: TSerialHandle): Boolean;
function SerGetCD(Handle: TSerialHandle): Boolean;
function SerGetRI(Handle: TSerialHandle): Boolean;

{ Set a line break state. If the requested time is greater than zero this is in
  mSec, in the case of unix this is likely to be rounded up to a few hundred
  mSec and to increase by a comparable increment; on unix if the time is less
  than or equal to zero its absolute value will be passed directly to the
  operating system with implementation-specific effect. If the third parameter
  is omitted or true there will be an implicit call of SerDrain() before and
  after the break.

  NOTE THAT on Linux, the only reliable mSec parameter is zero which results in
  a break of around 250 mSec. Might be completely ineffective on Solaris.
 }
procedure SerBreak(Handle: TSerialHandle; mSec: LongInt=0; sync: boolean= true);

{ This is similar to SerRead() but adds a mSec timeout. Note that this variant
  returns as soon as a single byte is available, or as dictated by the timeout. }
function SerReadTimeout(Handle: TSerialHandle; var Buffer; mSec: LongInt): LongInt;

{ This is similar to SerRead() but adds a mSec timeout. Note that this variant
  attempts to accumulate as many bytes as are available, but does not exceed
  the timeout. Set up a SerIdle callback if using this in a main thread in a
  Lazarus app. }
function SerReadTimeout(Handle: TSerialHandle; var Buffer; count: LongInt; mSec: Cardinal): LongInt;

function GetBytesWaiting(Handle: TSerialHandle; out bytesAtPort:integer):boolean;


implementation

{$if defined(UNIX)}
{$MODE objfpc}
{$H+}
{$PACKRECORDS C}
{$I serialunix.inc}
{$elseif defined(WINDOWS)}
{$I serialwin.inc}
{$else}
{$warning MySerial is not supported on your platform!}
{$endif}

end.
