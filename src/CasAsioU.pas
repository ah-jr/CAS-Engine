unit CasAsioU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Generics.Collections,
  CasConstantsU,
  CasTypesU,
  AsioList,
  Asio,
  VCL.ExtCtrls;

type
  TCasAsio = class(TInterfacedObject, IAudioDriver)

  private
    m_hwndHandle                 : HWND;
    m_CasEngine                  : TObject;

    m_bBuffersCreated            : Boolean;
    m_bIsStarted                 : Boolean;
    m_nCurrentBufferSize         : Cardinal;

    m_RightBuffer                : TIntArray;
    m_LeftBuffer                 : TIntArray;

    m_AsioDriver                 : TOpenAsio;
    m_DriverList                 : TAsioDriverList;
    m_Callbacks                  : TASIOCallbacks;
    m_BufferInfo                 : PAsioBufferInfo;
    m_BufferTime                 : TAsioTime;
    m_ChannelInfos               : Array[0..1] of TASIOChannelInfo;

    procedure InitializeVariables;
    procedure CreateBuffers;
    procedure DestroyBuffers;

    function  GetPlaying    : Boolean;
    function  GetReady      : Boolean;
    function  GetSampleRate : Double;
    function  GetBufferSize : Cardinal;

  public
    constructor Create(a_Owner : TObject);
    destructor  Destroy; override;

    procedure BufferSwitch         (a_nIndex : Integer);
    procedure BufferSwitchTimeInfo (a_nIndex : Integer; const Params : TAsioTime);
    procedure CMAsio(var Message: TMessage); message CM_ASIO;

    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure ControlPanel;

    procedure InitDriver(a_nID : Integer);
    procedure CloseDriver;
    procedure NotifyOwner  (a_ntNotification : TNotificationType);

    property BufferTime : TAsioTime read m_BufferTime write m_BufferTime;
    property Handle     : HWND      read m_hwndHandle write m_hwndHandle;

    property Playing    : Boolean   read m_bIsStarted;
    property Ready      : Boolean   read GetReady;
    property SampleRate : Double    read GetSampleRate;
    property BufferSize : Cardinal  read m_nCurrentBufferSize;

  end;

var
  CasASIO : TCasAsio;

implementation

uses
  VCL.Dialogs,
  System.Classes,
  System.SysUtils,
  CasEngineU,
  Math;


//==============================================================================
procedure AsioBufferSwitch(DoubleBufferIndex: LongInt; DirectProcess: TASIOBool); cdecl;
begin
  case DirectProcess of
    ASIOFalse :  PostMessage(CasASIO.Handle, CM_ASIO, AM_BufferSwitch, DoubleBufferIndex);
    ASIOTrue  :  CasASIO.BufferSwitch(DoubleBufferIndex);
  end;
end;

//==============================================================================s
function AsioMessage(Selector, Value: LongInt; message: Pointer; Ppt: PDouble): LongInt; cdecl;
begin
  Result := 0;

  case Selector of
    kAsioSelectorSupported :
      begin
        case Value of
          kAsioEngineVersion        :  Result := 1;
          kAsioResetRequest         :  Result := 1;
          kAsioBufferSizeChange     :  Result := 0;
          kAsioResyncRequest        :  Result := 1;
          kAsioLatenciesChanged     :  Result := 1;
          kAsioSupportsTimeInfo     :  Result := 1;
          kAsioSupportsTimeCode     :  Result := 1;
          kAsioSupportsInputMonitor :  Result := 0;
        end;
      end;
    kAsioEngineVersion :  Result := 2;
    kAsioResetRequest  :
      begin
        PostMessage(CasASIO.Handle, CM_ASIO, AM_ResetRequest, 0);
        Result := 1;
      end;
    kAsioBufferSizeChange :
      begin
        PostMessage(CasASIO.Handle, CM_ASIO, AM_ResetRequest, 0);
        Result := 1;
      end;
    kAsioResyncRequest    : ;
    kAsioLatenciesChanged :
      begin
        PostMessage(CasASIO.Handle, CM_ASIO, AM_LatencyChanged, 0);
        Result := 1;
      end;
    kAsioSupportsTimeInfo     : Result := 1;
    kAsioSupportsTimeCode     : Result := 0;
    kAsioSupportsInputMonitor : ;
  end;
end;

//==============================================================================
function AsioBufferSwitchTimeInfo(var Params: TASIOTime; DoubleBufferIndex: LongInt; DirectProcess: TASIOBool): PASIOTime; cdecl;
begin
  case directProcess of
    ASIOFalse :
      begin
        CasASIO.BufferTime := Params;
        PostMessage(CasASIO.Handle, CM_ASIO, AM_BufferSwitchTimeInfo, DoubleBufferIndex);
      end;
    ASIOTrue  : CasASIO.BufferSwitchTimeInfo(DoubleBufferIndex, Params);
  end;

  Result := nil;
end;

//==============================================================================
constructor TCasAsio.Create(a_Owner : TObject);
begin
  if a_Owner is TCasEngine then
    m_CasEngine := a_Owner;

  InitializeVariables;
end;

//==============================================================================
destructor TCasAsio.Destroy;
begin
  CloseDriver;

  SetLength(m_DriverList, 0);
  DestroyWindow(m_hwndHandle);

  Inherited;
end;

//==============================================================================
procedure TCasAsio.InitializeVariables;
begin
  m_hwndHandle := AllocateHWnd(nil);
  CasASIO      := Self;

  m_Callbacks.BufferSwitch         := AsioBufferSwitch;
  m_Callbacks.AsioMessage          := AsioMessage;
  m_Callbacks.BufferSwitchTimeInfo := AsioBufferSwitchTimeInfo;

  m_AsioDriver := nil;
  m_BufferInfo := nil;

  m_bBuffersCreated := False;
  m_bIsStarted      := False;

  SetLength(m_DriverList, 0);
  ListAsioDrivers(m_DriverList);
end;

//==============================================================================
procedure TCasAsio.CMAsio(var Message: TMessage);
var
   inp, outp: integer;
begin
  case Message.WParam of
    AM_ResetRequest         :  NotifyOwner(ntRequestedReset);
    AM_BufferSwitch         :  BufferSwitch(Message.LParam);
    AM_BufferSwitchTimeInfo :  BufferSwitchTimeInfo(Message.LParam, m_BufferTime);
    AM_LatencyChanged       :
      if (m_AsioDriver <> nil) then
      begin
        m_AsioDriver.GetLatencies(inp, outp);
      end;
  end;
end;

//==============================================================================
procedure TCasAsio.BufferSwitch(a_nIndex : Integer);
begin
  FillChar(m_BufferTime, SizeOf(TAsioTime), 0);

  if m_AsioDriver.GetSamplePosition(m_BufferTime.TimeInfo.SamplePosition, m_BufferTime.TimeInfo.SystemTime) = ASE_OK then
    m_BufferTime.TimeInfo.Flags := kSystemTimeValid or kSamplePositionValid;

  BufferSwitchTimeInfo(a_nIndex, m_BufferTime)
end;

//==============================================================================
procedure TCasAsio.BufferSwitchTimeInfo(a_nIndex : Integer; const Params : TAsioTime);
var
  nChannelIdx              : Integer;
  nBufferIdx               : Integer;
  OutputInt32              : PInteger;
  Info                     : PAsioBufferInfo;
begin
  if m_CasEngine is TCasEngine then
    (m_CasEngine as TCasEngine).CalculateBuffers(@m_LeftBuffer, @m_RightBuffer);

  Info := m_BufferInfo;

  for nChannelIdx := 0 to c_nChannelCount - 1 do
  begin
    case m_ChannelInfos[nChannelIdx].vType of
      ASIOSTInt16MSB   : ;
      ASIOSTInt24MSB   : ;
      ASIOSTInt32MSB   : ;
      ASIOSTFloat32MSB : ;
      ASIOSTFloat64MSB : ;

      ASIOSTInt32MSB16 : ;
      ASIOSTInt32MSB18 : ;
      ASIOSTInt32MSB20 : ;
      ASIOSTInt32MSB24 : ;

      ASIOSTInt16LSB   : ;
      ASIOSTInt24LSB   : ;
      ASIOSTInt32LSB   :
        begin
          OutputInt32 := Info^.Buffers[a_nIndex];
          for nBufferIdx := 0 to m_nCurrentBufferSize-1 do
          begin
            if nChannelIdx = 0
              then OutputInt32^ := Trunc(Power(2, 32 - c_nBitDepth) * m_LeftBuffer [nBufferIdx])
              else OutputInt32^ := Trunc(Power(2, 32 - c_nBitDepth) * m_RightBuffer[nBufferIdx]);

            Inc(OutputInt32);
          end;
        end;
      ASIOSTFloat32LSB : ;
      ASIOSTFloat64LSB : ;
      ASIOSTInt32LSB16 : ;
      ASIOSTInt32LSB18 : ;
      ASIOSTInt32LSB20 : ;
      ASIOSTInt32LSB24 : ;
    end;

    Inc(Info);
  end;

  m_AsioDriver.OutputReady;
end;

//==============================================================================
procedure TCasAsio.NotifyOwner(a_ntNotification : TNotificationType);
begin
  if (m_CasEngine is TCasEngine) then
    (m_CasEngine as TCasEngine).NotifyOwner(a_ntNotification);
end;

//==============================================================================
procedure TCasAsio.InitDriver(a_nID : Integer);
begin
  if m_AsioDriver <> nil then
    CloseDriver;

  //////////////////////////////////////////////////////////////////////////////
  ///  Open ASIO driver
  m_AsioDriver := TOpenAsio.Create(m_DriverList[a_nID].Id);
  if (m_AsioDriver <> nil) then
    if not Succeeded(m_AsioDriver.Init(Handle))
      then m_AsioDriver := nil
      else CreateBuffers;
end;

//==============================================================================
procedure TCasAsio.CreateBuffers;
var
   nMin          : Integer;
   nMax          : Integer;
   nPref         : Integer;
   nGran         : Integer;
   nChannelIdx   : Integer;
   Currentbuffer : PAsioBufferInfo;
begin
  if (m_AsioDriver <> nil) then
  begin
    if m_bBuffersCreated then
      DestroyBuffers;

    m_AsioDriver.GetBufferSize(nMin, nMax, nPref, nGran);
    GetMem(m_BufferInfo, SizeOf(TAsioBufferInfo)*c_nChannelCount);
    Currentbuffer := m_BufferInfo;

    for nChannelIdx := 0 to c_nChannelCount - 1 do
    begin
      Currentbuffer^.IsInput     := ASIOFalse;
      Currentbuffer^.ChannelNum  := nChannelIdx;
      Currentbuffer^.Buffers[0] := nil;
      Currentbuffer^.Buffers[1] := nil;
      Inc(Currentbuffer);
    end;

    m_bBuffersCreated := (m_AsioDriver.CreateBuffers(m_BufferInfo, c_nChannelCount, nPref, m_Callbacks) = ASE_OK);
    if m_bBuffersCreated
      then m_nCurrentBufferSize := nPref
      else m_nCurrentBufferSize := 0;

    NotifyOwner(ntBuffersCreated);

    if m_AsioDriver <> nil then
    begin
      if m_bBuffersCreated then
      begin
        for nChannelIdx := 0 to c_nChannelCount - 1 do
        begin
          m_ChannelInfos[nChannelIdx].Channel := nChannelIdx;
          m_ChannelInfos[nChannelIdx].IsInput := ASIOFalse;
          m_AsioDriver.GetChannelInfo(m_ChannelInfos[nChannelIdx]);
        end;
      end;
    end;
  end;
end;

//==============================================================================
procedure TCasAsio.DestroyBuffers;
begin
  if (m_AsioDriver <> nil) and m_bBuffersCreated then
  begin
    FreeMem(m_BufferInfo);
    m_AsioDriver.DisposeBuffers;

    m_BufferInfo         := nil;
    m_bBuffersCreated    := False;
    m_nCurrentBufferSize := 0;

    NotifyOwner(ntBuffersDestroyed);
  end;
end;

//==============================================================================
procedure TCasAsio.CloseDriver;
begin
  if m_AsioDriver <> nil then
  begin
    if m_bIsStarted then
      Stop;

    if m_bBuffersCreated then
      DestroyBuffers;

    m_AsioDriver := nil;
  end;

  NotifyOwner(ntDriverClosed);
end;

//==============================================================================
procedure TCasAsio.Play;
begin
  if m_AsioDriver <> nil then
    m_bIsStarted := (m_AsioDriver.Start = ASE_OK);
end;

//==============================================================================
procedure TCasAsio.Pause;
begin
  if m_AsioDriver <> nil then
  begin
    if m_bIsStarted then
    begin
      m_AsioDriver.Stop;
      m_bIsStarted := False;
    end;
  end;
end;

//==============================================================================
procedure TCasAsio.Stop;
begin
  if m_AsioDriver <> nil then
    Pause;
end;

//==============================================================================
procedure TCasAsio.ControlPanel;
begin
  if (m_AsioDriver <> nil) then
    m_AsioDriver.ControlPanel;
end;

//==============================================================================
function TCasAsio.GetPlaying : Boolean;
begin
  Result := m_bIsStarted;
end;

//==============================================================================
function TCasAsio.GetReady : Boolean;
begin
  Result := m_AsioDriver <> nil;
end;

//==============================================================================
function TCasAsio.GetSampleRate : Double;
begin
  Result := c_nDefaultSampleRate;

  if Ready then
  begin
    try
      m_AsioDriver.GetSampleRate(Result);
    except
    end;
  end;
end;

//==============================================================================
function TCasAsio.GetBufferSize : Cardinal;
begin
  Result := m_nCurrentBufferSize;
end;

end.


