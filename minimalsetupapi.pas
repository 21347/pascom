{This unit is based on the JEDI Code Library for the SetupAPI that ships with FreePascal but was corrected and adapted for Win32 AND Win64.
The file stays under the original license of the respective files in the FPC repository and will be removed if the changed can be
applied upstream.}

unit MinimalSetupApi;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils;

const
  SetupApiModuleName = 'SetupApi.dll';

type
//
// Define type for reference to device information set
//
  HDEVINFO = THandle;
  {$EXTERNALSYM HDEVINFO}

//
// Device information structure (references a device instance
// that is a member of a device information set)
//
  PSPDevInfoData = ^TSPDevInfoData;
  SP_DEVINFO_DATA = packed record
    cbSize: DWORD;
    ClassGuid: TGUID;
    DevInst: DWORD; // DEVINST handle
    Reserved: PtrUInt;
  end;
  {$EXTERNALSYM SP_DEVINFO_DATA}
  TSPDevInfoData = SP_DEVINFO_DATA;


//
// Flags controlling what is included in the device information set built
// by SetupDiGetClassDevs
//
const
  DIGCF_DEFAULT         = $00000001; // only valid with DIGCF_DEVICEINTERFACE
  {$EXTERNALSYM DIGCF_DEFAULT}
  DIGCF_PRESENT         = $00000002;
  {$EXTERNALSYM DIGCF_PRESENT}
  DIGCF_ALLCLASSES      = $00000004;
  {$EXTERNALSYM DIGCF_ALLCLASSES}
  DIGCF_PROFILE         = $00000008;
  {$EXTERNALSYM DIGCF_PROFILE}
  DIGCF_DEVICEINTERFACE = $00000010;
  {$EXTERNALSYM DIGCF_DEVICEINTERFACE}

//
// Device registry property codes
// (Codes marked as read-only (R) may only be used for
// SetupDiGetDeviceRegistryProperty)
//
// These values should cover the same set of registry properties
// as defined by the CM_DRP codes in cfgmgr32.h.
//
const
  SPDRP_DEVICEDESC                  = $00000000; // DeviceDesc (R/W)
  {$EXTERNALSYM SPDRP_DEVICEDESC}
  SPDRP_HARDWAREID                  = $00000001; // HardwareID (R/W)
  {$EXTERNALSYM SPDRP_HARDWAREID}
  SPDRP_COMPATIBLEIDS               = $00000002; // CompatibleIDs (R/W)
  {$EXTERNALSYM SPDRP_COMPATIBLEIDS}
  SPDRP_UNUSED0                     = $00000003; // unused
  {$EXTERNALSYM SPDRP_UNUSED0}
  SPDRP_SERVICE                     = $00000004; // Service (R/W)
  {$EXTERNALSYM SPDRP_SERVICE}
  SPDRP_UNUSED1                     = $00000005; // unused
  {$EXTERNALSYM SPDRP_UNUSED1}
  SPDRP_UNUSED2                     = $00000006; // unused
  {$EXTERNALSYM SPDRP_UNUSED2}
  SPDRP_CLASS                       = $00000007; // Class (R--tied to ClassGUID)
  {$EXTERNALSYM SPDRP_CLASS}
  SPDRP_CLASSGUID                   = $00000008; // ClassGUID (R/W)
  {$EXTERNALSYM SPDRP_CLASSGUID}
  SPDRP_DRIVER                      = $00000009; // Driver (R/W)
  {$EXTERNALSYM SPDRP_DRIVER}
  SPDRP_CONFIGFLAGS                 = $0000000A; // ConfigFlags (R/W)
  {$EXTERNALSYM SPDRP_CONFIGFLAGS}
  SPDRP_MFG                         = $0000000B; // Mfg (R/W)
  {$EXTERNALSYM SPDRP_MFG}
  SPDRP_FRIENDLYNAME                = $0000000C; // FriendlyName (R/W)
  {$EXTERNALSYM SPDRP_FRIENDLYNAME}
  SPDRP_LOCATION_INFORMATION        = $0000000D; // LocationInformation (R/W)
  {$EXTERNALSYM SPDRP_LOCATION_INFORMATION}
  SPDRP_PHYSICAL_DEVICE_OBJECT_NAME = $0000000E; // PhysicalDeviceObjectName (R)
  {$EXTERNALSYM SPDRP_PHYSICAL_DEVICE_OBJECT_NAME}
  SPDRP_CAPABILITIES                = $0000000F; // Capabilities (R)
  {$EXTERNALSYM SPDRP_CAPABILITIES}
  SPDRP_UI_NUMBER                   = $00000010; // UiNumber (R)
  {$EXTERNALSYM SPDRP_UI_NUMBER}
  SPDRP_UPPERFILTERS                = $00000011; // UpperFilters (R/W)
  {$EXTERNALSYM SPDRP_UPPERFILTERS}
  SPDRP_LOWERFILTERS                = $00000012; // LowerFilters (R/W)
  {$EXTERNALSYM SPDRP_LOWERFILTERS}
  SPDRP_BUSTYPEGUID                 = $00000013; // BusTypeGUID (R)
  {$EXTERNALSYM SPDRP_BUSTYPEGUID}
  SPDRP_LEGACYBUSTYPE               = $00000014; // LegacyBusType (R)
  {$EXTERNALSYM SPDRP_LEGACYBUSTYPE}
  SPDRP_BUSNUMBER                   = $00000015; // BusNumber (R)
  {$EXTERNALSYM SPDRP_BUSNUMBER}
  SPDRP_ENUMERATOR_NAME             = $00000016; // Enumerator Name (R)
  {$EXTERNALSYM SPDRP_ENUMERATOR_NAME}
  SPDRP_SECURITY                    = $00000017; // Security (R/W, binary form)
  {$EXTERNALSYM SPDRP_SECURITY}
  SPDRP_SECURITY_SDS                = $00000018; // Security (W, SDS form)
  {$EXTERNALSYM SPDRP_SECURITY_SDS}
  SPDRP_DEVTYPE                     = $00000019; // Device Type (R/W)
  {$EXTERNALSYM SPDRP_DEVTYPE}
  SPDRP_EXCLUSIVE                   = $0000001A; // Device is exclusive-access (R/W)
  {$EXTERNALSYM SPDRP_EXCLUSIVE}
  SPDRP_CHARACTERISTICS             = $0000001B; // Device Characteristics (R/W)
  {$EXTERNALSYM SPDRP_CHARACTERISTICS}
  SPDRP_ADDRESS                     = $0000001C; // Device Address (R)
  {$EXTERNALSYM SPDRP_ADDRESS}
  SPDRP_UI_NUMBER_DESC_FORMAT       = $0000001E; // UiNumberDescFormat (R/W)
  {$EXTERNALSYM SPDRP_UI_NUMBER_DESC_FORMAT}
  SPDRP_MAXIMUM_PROPERTY            = $0000001F; // Upper bound on ordinals
  {$EXTERNALSYM SPDRP_MAXIMUM_PROPERTY}
//
// Class registry property codes
// (Codes marked as read-only (R) may only be used for
// SetupDiGetClassRegistryProperty)
//
// These values should cover the same set of registry properties
// as defined by the CM_CRP codes in cfgmgr32.h.
// they should also have a 1:1 correspondence with Device registers, where applicable
// but no overlap otherwise
//
  SPCRP_SECURITY         = $00000017; // Security (R/W, binary form)
  {$EXTERNALSYM SPCRP_SECURITY}
  SPCRP_SECURITY_SDS     = $00000018; // Security (W, SDS form)
  {$EXTERNALSYM SPCRP_SECURITY_SDS}
  SPCRP_DEVTYPE          = $00000019; // Device Type (R/W)
  {$EXTERNALSYM SPCRP_DEVTYPE}
  SPCRP_EXCLUSIVE        = $0000001A; // Device is exclusive-access (R/W)
  {$EXTERNALSYM SPCRP_EXCLUSIVE}
  SPCRP_CHARACTERISTICS  = $0000001B; // Device Characteristics (R/W)
  {$EXTERNALSYM SPCRP_CHARACTERISTICS}
  SPCRP_MAXIMUM_PROPERTY = $0000001C; // Upper bound on ordinals
  {$EXTERNALSYM SPCRP_MAXIMUM_PROPERTY}

//
// KeyType values for SetupDiCreateDevRegKey, SetupDiOpenDevRegKey, and
// SetupDiDeleteDevRegKey.
//
const
  DIREG_DEV  = $00000001; // Open/Create/Delete device key
  {$EXTERNALSYM DIREG_DEV}
  DIREG_DRV  = $00000002; // Open/Create/Delete driver key
  {$EXTERNALSYM DIREG_DRV}
  DIREG_BOTH = $00000004; // Delete both driver and Device key
  {$EXTERNALSYM DIREG_BOTH}

//
// Values specifying the scope of a device property change
//
const
  DICS_FLAG_GLOBAL         = $00000001;  // make change in all hardware profiles
  {$EXTERNALSYM DICS_FLAG_GLOBAL}
  DICS_FLAG_CONFIGSPECIFIC = $00000002;  // make change in specified profile only
  {$EXTERNALSYM DICS_FLAG_CONFIGSPECIFIC}
  DICS_FLAG_CONFIGGENERAL  = $00000004;  // 1 or more hardware profile-specific
  {$EXTERNALSYM DICS_FLAG_CONFIGGENERAL} // changes to follow.

function SetupDiGetClassDevsA(ClassGuid: PGUID; const Enumerator: PAnsiChar;
  hwndParent: HWND; Flags: DWORD): HDEVINFO; stdcall;
{$EXTERNALSYM SetupDiGetClassDevsA}
function SetupDiGetClassDevsW(ClassGuid: PGUID; const Enumerator: PWideChar;
  hwndParent: HWND; Flags: DWORD): HDEVINFO; stdcall;
{$EXTERNALSYM SetupDiGetClassDevsW}
function SetupDiGetClassDevs(ClassGuid: PGUID; const Enumerator: PChar;
  hwndParent: HWND; Flags: DWORD): HDEVINFO; stdcall;
{$EXTERNALSYM SetupDiGetClassDevs}

function SetupDiGetDeviceRegistryPropertyA(DeviceInfoSet: HDEVINFO;
  const DeviceInfoData: TSPDevInfoData; Property_: DWORD;
  PropertyRegDataType: PDWORD; PropertyBuffer: PBYTE; PropertyBufferSize: DWORD;
  RequiredSize: PDWORD): LongBool; stdcall;
{$EXTERNALSYM SetupDiGetDeviceRegistryPropertyA}
function SetupDiGetDeviceRegistryPropertyW(DeviceInfoSet: HDEVINFO;
  const DeviceInfoData: TSPDevInfoData; Property_: DWORD;
  PropertyRegDataType: PDWORD; PropertyBuffer: PBYTE; PropertyBufferSize: DWORD;
  RequiredSize: PDWORD): LongBool; stdcall;
{$EXTERNALSYM SetupDiGetDeviceRegistryPropertyW}
function SetupDiGetDeviceRegistryProperty(DeviceInfoSet: HDEVINFO;
  const DeviceInfoData: TSPDevInfoData; Property_: DWORD;
  PropertyRegDataType: PDWORD; PropertyBuffer: PBYTE; PropertyBufferSize: DWORD;
  RequiredSize: PDWORD): LongBool; stdcall;
{$EXTERNALSYM SetupDiGetDeviceRegistryProperty}

function SetupDiEnumDeviceInfo(DeviceInfoSet: HDEVINFO;
  MemberIndex: DWORD; var DeviceInfoData: TSPDevInfoData): LongBool; stdcall;
{$EXTERNALSYM SetupDiEnumDeviceInfo}

function SetupDiOpenDevRegKey(DeviceInfoSet: HDEVINFO;
  var DeviceInfoData: TSPDevInfoData; Scope, HwProfile, KeyType: DWORD;
  samDesired: REGSAM): HKEY; stdcall;
{$EXTERNALSYM SetupDiOpenDevRegKey}

implementation

function SetupDiGetClassDevsA(ClassGuid: PGUID; const Enumerator: PAnsiChar;
  hwndParent: HWND; Flags: DWORD): HDEVINFO; stdcall; external SetupApiModuleName name 'SetupDiGetClassDevsA';
function SetupDiGetClassDevsW(ClassGuid: PGUID; const Enumerator: PWideChar;
  hwndParent: HWND; Flags: DWORD): HDEVINFO; stdcall; external SetupApiModuleName name 'SetupDiGetClassDevsW';
function SetupDiGetClassDevs(ClassGuid: PGUID; const Enumerator: PChar;
  hwndParent: HWND; Flags: DWORD): HDEVINFO; stdcall; external SetupApiModuleName name 'SetupDiGetClassDevsA';

function SetupDiGetDeviceRegistryPropertyA(DeviceInfoSet: HDEVINFO;
  const DeviceInfoData: TSPDevInfoData; Property_: DWORD;
  PropertyRegDataType: PDWORD; PropertyBuffer: PBYTE; PropertyBufferSize: DWORD;
  RequiredSize: PDWORD): LongBool; stdcall; external SetupApiModuleName name 'SetupDiGetDeviceRegistryPropertyA';
function SetupDiGetDeviceRegistryPropertyW(DeviceInfoSet: HDEVINFO;
  const DeviceInfoData: TSPDevInfoData; Property_: DWORD;
  PropertyRegDataType: PDWORD; PropertyBuffer: PBYTE; PropertyBufferSize: DWORD;
  RequiredSize: PDWORD): LongBool; stdcall; external SetupApiModuleName name 'SetupDiGetDeviceRegistryPropertyW';
function SetupDiGetDeviceRegistryProperty(DeviceInfoSet: HDEVINFO;
  const DeviceInfoData: TSPDevInfoData; Property_: DWORD;
  PropertyRegDataType: PDWORD; PropertyBuffer: PBYTE; PropertyBufferSize: DWORD;
  RequiredSize: PDWORD): LongBool; stdcall; external SetupApiModuleName name 'SetupDiGetDeviceRegistryPropertyA';

function SetupDiEnumDeviceInfo(DeviceInfoSet: HDEVINFO;
  MemberIndex: DWORD; var DeviceInfoData: TSPDevInfoData): LongBool; stdcall; external SetupApiModuleName name 'SetupDiEnumDeviceInfo';

function SetupDiOpenDevRegKey(DeviceInfoSet: HDEVINFO;
  var DeviceInfoData: TSPDevInfoData; Scope, HwProfile, KeyType: DWORD;
  samDesired: REGSAM): HKEY; stdcall; external SetupApiModuleName name 'SetupDiOpenDevRegKey';

end.

