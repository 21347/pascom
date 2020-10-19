# pascom
Simple ObjectPascal library for reading and writing to various types or communication sockets (Serial, TCP, etc.)

## Design

The library is intended so simplify mostly the development of client applications controlling various devices via different communication protocols.
In most cases, those communications require specific flow of control codes and device reads or queries, the library is hence designed to be mostly blocking.

## Communication resources

Different backend drivers are available to talk to your devices. The client application does not neccessarily need to know which channel is eventually used, it can be RS32 or TCP/IP for example.
The user selects the target endpoint by specifying the resource, i.e. `TCP:127.0.0.1:80` or `SER:\dev\ttyUSB0`, the communication code behind is the same.

## Licensing

pasCom is licensed under the LGPL.

Two components of this repository are currently included as modifications from the FreePascal RTL and maintain the respective licenses of the original source. Those are `minimalsetupapi.pas` (based on the Jedi Code Library, MPL) and `myserial.pas` (based on FPC's RTL library for serial port communication).