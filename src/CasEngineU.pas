unit CasEngineU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Generics.Collections,
  CasTrackU,
  CasConstantsU,
  CasMixerU,
  CasDatabaseU,
  CasPlaylistU,
  AsioList,
  Asio,
  VCL.ExtCtrls;

type
  TCasEngine = class(TObject)

  private
    m_hwndHandle                 : HWND;
    m_hwndOwner                  : HWND;
    m_Owner                      : TObject;
    m_MainMixer                  : TCasMixer;
    m_tmrUpdateInfo              : TTimer;

    m_CasDatabase                : TCasDatabase;
    m_CasPlaylist                : TCasPlaylist;

    m_nIdCount                   : Integer;
    m_nCurrentBufferSize         : Integer;
    m_bBlockBufferPositionUpdate : Boolean;
    m_bFileLoaded                : Boolean;
    m_bBuffersCreated            : Boolean;
    m_bIsStarted                 : Boolean;
    m_bOwnerUpToDate             : Boolean;

    m_RightBuffer                : TIntArray;
    m_LeftBuffer                 : TIntArray;

    m_AsioDriver                 : TOpenAsio;
    m_DriverList                 : TAsioDriverList;
    m_Callbacks                  : TASIOCallbacks;
    m_BufferInfo                 : PAsioBufferInfo;
    m_BufferTime                 : TAsioTime;
    m_ChannelInfos               : Array[0..1] of TASIOChannelInfo;

    procedure OnUpdateInfoTimer(Sender: TObject);
    procedure ProcessMessage(var MsgRec: TMessage);
    procedure InitializeVariables;
    procedure CloseDriver;
    procedure CalculateBuffers;
    procedure CreateBuffers;
    procedure DestroyBuffers;

  public
    constructor Create(a_Owner : TObject; a_Handle : HWND = 0);
    destructor  Destroy; override;

    procedure NotifyOwner(a_ntNotification : TNotificationType);

    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure Prev;
    procedure Next;

    function  GetLevel      : Double;
    function  GetPosition   : Integer;
    function  GetProgress   : Double;
    function  GetLength     : Integer;
    function  GetReady      : Boolean;
    function  GetSampleRate : Double;

    function  GenerateID    : Integer;

    procedure SetLevel   (a_dLevel : Double);
    procedure SetPosition(a_nPosition : Integer);

    function  AddTrackToPlaylist(a_nTrackId, a_nPosition : Integer) : Boolean;

    function  AddTrack(a_CasTrack : TCasTrack; a_nMixerId : Integer) : Boolean;
    procedure ClearTracks;
    procedure ChangeDriver(a_nID : Integer);

    procedure BufferSwitch         (a_nIndex : Integer);
    procedure BufferSwitchTimeInfo (a_nIndex : Integer; const Params : TAsioTime);

    procedure CMAsio(var Message: TMessage); message CM_ASIO;

    property Level      : Double    read GetLevel     write SetLevel;
    property Position   : Integer   read GetPosition  write SetPosition;
    property Progress   : Double    read GetProgress;
    property Length     : Integer   read GetLength;

    property Ready      : Boolean   read GetReady;
    property Playing    : Boolean   read m_bIsStarted;
    property BuffersOn  : Boolean   read m_bBuffersCreated;
    property SampleRate : Double    read GetSampleRate;

    property Playlist   : TCasPlaylist read m_CasPlaylist write m_CasPlaylist;
    property Database   : TCasDatabase read m_CasDatabase write m_CasDatabase;
    property AsioDriver : TOpenAsio    read m_AsioDriver  write m_AsioDriver;
    property MainMixer  : TCasMixer    read m_MainMixer   write m_MainMixer;

    property BufferTime : TAsioTime read m_BufferTime write m_BufferTime;
    property Handle     : HWND      read m_hwndHandle write m_hwndHandle;

  end;

var
  CasEngine: TCasEngine;

implementation

uses
  VCL.Dialogs,
  System.Classes,
  System.SysUtils,
  CasBasicFxU,
  CasUtilsU,
  Math;


//==============================================================================
procedure AsioBufferSwitch(DoubleBufferIndex: LongInt; DirectProcess: TASIOBool); cdecl;
begin
  case DirectProcess of
    ASIOFalse :  PostMessage(CasEngine.Handle, CM_ASIO, AM_BufferSwitch, DoubleBufferIndex);
    ASIOTrue  :  CasEngine.BufferSwitch(DoubleBufferIndex);
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
        PostMessage(CasEngine.Handle, CM_ASIO, AM_ResetRequest, 0);
        Result := 1;
      end;
    kAsioBufferSizeChange :
      begin
        PostMessage(CasEngine.Handle, CM_ASIO, AM_ResetRequest, 0);
        Result := 1;
      end;
    kAsioResyncRequest    : ;
    kAsioLatenciesChanged :
      begin
        PostMessage(CasEngine.Handle, CM_ASIO, AM_LatencyChanged, 0);
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
        CasEngine.BufferTime := Params;
        PostMessage(CasEngine.Handle, CM_ASIO, AM_BufferSwitchTimeInfo, DoubleBufferIndex);
      end;
    ASIOTrue  : CasEngine.BufferSwitchTimeInfo(DoubleBufferIndex, Params);
  end;

  Result := nil;
end;

//==============================================================================
constructor TCasEngine.Create(a_Owner : TObject; a_Handle : HWND = 0);
begin
  m_Owner     := a_Owner;
  m_hwndOwner := a_Handle;
  CasEngine   := Self;
  m_nIdCount  := 0;

  InitializeVariables;
end;

//==============================================================================
destructor TCasEngine.Destroy;
begin
  if m_AsioDriver <> nil then
    m_AsioDriver.Destroy;
  DestroyWindow(m_hwndHandle);

  m_tmrUpdateInfo.Enabled := False;
  m_tmrUpdateInfo.Free;

  Inherited;
end;

//==============================================================================
procedure TCasEngine.InitializeVariables;
begin
  m_hwndHandle := AllocateHWnd(ProcessMessage);

  m_tmrUpdateInfo := TTimer.Create(nil);
  m_tmrUpdateInfo.Interval := 10;
  m_tmrUpdateInfo.OnTimer := OnUpdateInfoTimer;
  m_tmrUpdateInfo.Enabled := True;

  m_CasDatabase := TCasDatabase.Create;
  m_CasPlaylist := TCasPlaylist.Create(m_CasDatabase);
  m_CasPlaylist.Position := 0;

  m_MainMixer       := TCasMixer.Create;
  m_MainMixer.ID    := 0;
  m_MainMixer.Level := 1;

  m_CasDatabase.AddMixer(m_MainMixer);

  m_Callbacks.BufferSwitch         := AsioBufferSwitch;
  m_Callbacks.AsioMessage          := AsioMessage;
  m_Callbacks.BufferSwitchTimeInfo := AsioBufferSwitchTimeInfo;

  m_AsioDriver := nil;
  m_BufferInfo := nil;

  m_bFileLoaded                := False;
  m_bBuffersCreated            := False;
  m_bIsStarted                 := False;
  m_bBlockBufferPositionUpdate := False;
  m_bOwnerUpToDate             := True;

  SetLength(m_DriverList, 0);
  ListAsioDrivers(m_DriverList);
end;

//==============================================================================
procedure TCasEngine.OnUpdateInfoTimer(Sender: TObject);
begin
  if not m_bOwnerUpToDate then
  begin
    NotifyOwner(ntBuffersUpdated);

    m_bOwnerUpToDate := True;
  end;
end;

//==============================================================================
procedure TCasEngine.NotifyOwner(a_ntNotification : TNotificationType);
begin
  if m_hwndOwner <> 0 then
  begin
    PostMessage(m_hwndOwner, CM_NotifyOwner, WParam(a_ntNotification), LParam(0));
  end;
end;

//==============================================================================
function TCasEngine.AddTrackToPlaylist(a_nTrackId, a_nPosition : Integer) : Boolean;
var
  CasTrack : TCasTrack;
begin
  Result := m_CasDatabase.GetTrackById(a_nTrackId, CasTrack);

  if Result then
  begin
    CasTrack.Position := a_nPosition;
    m_CasPlaylist.AddTrack(a_nTrackId);
  end;
end;

//==============================================================================
function TCasEngine.AddTrack(a_CasTrack : TCasTrack; a_nMixerId : Integer) : Boolean;
var
  CasMixer : TCasMixer;
begin
  Result := False;

  if m_CasDatabase.GetMixerById(a_nMixerId, CasMixer) then
  begin
    if CasMixer.Tracks.IndexOf(a_CasTrack.ID) < 0 then
      CasMixer.AddTrack(a_CasTrack.ID);

    m_CasDatabase.AddTrack(a_CasTrack);
    Result := True;
  end;
end;

//==============================================================================
procedure TCasEngine.ClearTracks;
begin
  m_CasDatabase.ClearTracks;
end;

//==============================================================================
procedure TCasEngine.ChangeDriver(a_nID : Integer);
begin
  if m_AsioDriver <> nil then
    CloseDriver;

  if a_nID >= 0 then
  begin
    m_AsioDriver := TOpenAsio.Create(m_DriverList[a_nID].Id);
    if (m_AsioDriver <> nil) then
      if not Succeeded(m_AsioDriver.Init(Handle))
        then m_AsioDriver := nil
        else CreateBuffers;
  end;
end;

//==============================================================================
procedure TCasEngine.ProcessMessage(var MsgRec: TMessage);
begin
  try
//    case MsgRec.Msg of
//
//    end;
  finally

  end;
end;

//==============================================================================
procedure TCasEngine.CMAsio(var Message: TMessage);
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
procedure TCasEngine.BufferSwitch(a_nIndex : Integer);
begin
  FillChar(m_BufferTime, SizeOf(TAsioTime), 0);

  if m_AsioDriver.GetSamplePosition(m_BufferTime.TimeInfo.SamplePosition, m_BufferTime.TimeInfo.SystemTime) = ASE_OK then
    m_BufferTime.TimeInfo.Flags := kSystemTimeValid or kSamplePositionValid;

  BufferSwitchTimeInfo(a_nIndex, m_BufferTime)
end;

//==============================================================================
procedure TCasEngine.BufferSwitchTimeInfo(a_nIndex : Integer; const Params : TAsioTime);
var
   nChannelIdx              : Integer;
   nBufferIdx               : Integer;
   Info                     : PAsioBufferInfo;
   OutputInt32              : PInteger;
begin
  if (m_CasPlaylist.Position < m_CasPlaylist.Length - m_nCurrentBufferSize * m_CasPlaylist.Speed) then
  begin
    Info := m_BufferInfo;

    CalculateBuffers;

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
              if nChannelIdx = 0 then
              begin
                OutputInt32^ := Trunc(Power(2, 32 - c_nBitDepth) * m_LeftBuffer[nBufferIdx]);
              end
              else
              begin
                OutputInt32^ := Trunc(Power(2, 32 - c_nBitDepth) * m_RightBuffer[nBufferIdx]);
              end;

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
  end
  else
  begin
    m_CasPlaylist.Position := 0;
  end;

  m_bOwnerUpToDate := False;
end;

//==============================================================================
procedure TCasEngine.CalculateBuffers;
var
  nBufferIdx  : Integer;
  nPosition   : Integer;
  nTrackIdx   : Integer;
  nTrackID    : Integer;
  nMixerIdx   : Integer;
  nBufInSize  : Integer;
  dGap        : Double;
  CasTrack    : TCasTrack;
  CasMixer    : TCasMixer;
  LeftMaster  : TIntArray;
  RightMaster : TIntArray;
  LeftTrack   : TIntArray;
  RightTrack  : TIntArray;
begin
  // The gap variable is used in order to prevent distortion when changing the
  // speed of playlist. It enables the interpolation algorithm to determine
  // which value goes first in the buffer.
  dGap := (1-Frac(m_CasPlaylist.RelPos))/m_CasPlaylist.Speed;

  nBufInSize := Ceil((m_nCurrentBufferSize - dGap) * m_CasPlaylist.Speed) + 2;

  SetLength(m_LeftBuffer,  m_nCurrentBufferSize);
  SetLength(m_RightBuffer, m_nCurrentBufferSize);
  SetLength(LeftMaster,    nBufInSize);
  SetLength(RightMaster,   nBufInSize);
  SetLength(LeftTrack,     nBufInSize);
  SetLength(RightTrack,    nBufInSize);

  // Clear buffers:
  for nBufferIdx := 0 to m_nCurrentBufferSize - 1 do
  begin
    m_LeftBuffer [nBufferIdx] := 0;
    m_RightBuffer[nBufferIdx] := 0;
  end;

  // For each mixer, get all linked tracks and add them to the buffer:
  for nMixerIdx := 0 to m_CasDatabase.Mixers.Count - 1 do
  begin
    CasMixer := m_CasDatabase.Mixers.Items[nMixerIdx];
    for nTrackIdx := 0 to CasMixer.Tracks.Count - 1 do
    begin
      nTrackID := CasMixer.Tracks.Items[nTrackIdx];
      if m_CasDatabase.GetTrackById(nTrackID, CasTrack) then
      begin
        // If track's position is positive a is in the playlist:
        if (CasTrack.Position >= 0) then
        begin
          nPosition := Trunc(m_CasPlaylist.RelPos) - CasTrack.Position;

          // If playlist reached track's position, plays:
          if (nPosition >= 0) and
             (nPosition < CasTrack.Size - nBufInSize) then
          begin
            InterpolateRT(@(CasTrack.RawData.Left),
                          @(CasTrack.RawData.Right),
                          @LeftTrack,
                          @RightTrack,
                          CasTrack.Size,
                          nBufInSize,
                          1,
                          nPosition);

            for nBufferIdx := 0 to nBufInSize - 1 do
            begin
              LeftMaster [nBufferIdx] := LeftMaster[nBufferIdx]  +
                Trunc(CasMixer.Level * LeftTrack [nBufferIdx]);

              RightMaster[nBufferIdx] := RightMaster[nBufferIdx] +
                Trunc(CasMixer.Level * RightTrack[nBufferIdx]);
            end;
          end;
        end;
      end;
    end;
  end;

  // Interpolate whole playlist:
  InterpolateRT(@LeftMaster,
                @RightMaster,
                @m_LeftBuffer,
                @m_RightBuffer,
                nBufInSize,
                m_nCurrentBufferSize,
                m_CasPlaylist.Speed,
                0,
                dGap);

  m_CasPlaylist.RelPos := m_CasPlaylist.RelPos + m_nCurrentBufferSize * m_CasPlaylist.Speed;
end;

//==============================================================================
procedure TCasEngine.CreateBuffers;
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
    if m_bBuffersCreated then
      m_nCurrentBufferSize := nPref
    else
      m_nCurrentBufferSize := 0;

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
procedure TCasEngine.DestroyBuffers;
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
procedure TCasEngine.CloseDriver;
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
procedure TCasEngine.Play;
begin
  if m_AsioDriver <> nil then
    m_bIsStarted := (m_AsioDriver.Start = ASE_OK);
end;

//==============================================================================
procedure TCasEngine.Pause;
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
procedure TCasEngine.Stop;
begin
  if m_AsioDriver <> nil then
  begin
    Pause;
    m_CasPlaylist.Position := 0;
  end;
end;

//==============================================================================
procedure TCasEngine.Prev;
var
  nIndex : Integer;
  nPos   : Integer;
begin
  if m_AsioDriver <> nil then
  begin
    nPos := 0;

    for nIndex := 0 to m_CasDatabase.Tracks.Count - 1 do
    begin
      if (m_CasDatabase.Tracks.Items[nIndex].Position < m_CasPlaylist.Position) then
        nPos := Max(nPos, m_CasDatabase.Tracks.Items[nIndex].Position);
    end;

    m_CasPlaylist.Position := nPos;
  end;
end;

//==============================================================================
procedure TCasEngine.Next;
var
  nIndex : Integer;
  nPos   : Integer;
begin
  if m_AsioDriver <> nil then
  begin
    nPos := MaxInt;

    for nIndex := 0 to m_CasDatabase.Tracks.Count - 1 do
    begin
      if (m_CasDatabase.Tracks.Items[nIndex].Position > m_CasPlaylist.Position) then
        nPos := Min(nPos, m_CasDatabase.Tracks.Items[nIndex].Position);
    end;

    m_CasPlaylist.Position := nPos;
  end;
end;

//==============================================================================
// Generate ID's for any CAS object
//==============================================================================
function TCasEngine.GenerateID : Integer;
begin
  Result := m_nIdCount;
  Inc(m_nIdCount);
end;

//==============================================================================
function TCasEngine.GetLevel : Double;
begin
  Result := m_MainMixer.Level;
end;

//==============================================================================
function TCasEngine.GetPosition : Integer;
begin
  Result := m_CasPlaylist.Position;
end;

//==============================================================================
function TCasEngine.GetProgress : Double;
begin
  Result := m_CasPlaylist.Progress;
end;

//==============================================================================
function TCasEngine.GetLength : Integer;
begin
  Result := m_CasPlaylist.Length;
end;

//==============================================================================
function TCasEngine.GetReady : Boolean;
begin
  Result := m_AsioDriver <> nil;
end;

//==============================================================================
function TCasEngine.GetSampleRate : Double;
begin
  if Ready then
  begin
    try
      m_AsioDriver.GetSampleRate(Result);
    except
      Result := 0;
    end;
  end;
end;

//==============================================================================
procedure TCasEngine.SetLevel(a_dLevel : Double);
begin
  m_MainMixer.Level := a_dLevel;
end;

//==============================================================================
procedure TCasEngine.SetPosition(a_nPosition : Integer);
begin
  m_CasPlaylist.Position := a_nPosition;
end;

//==============================================================================
end.


