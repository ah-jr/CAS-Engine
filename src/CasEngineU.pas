unit CasEngineU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Generics.Collections,
  CasTrackU,
  CasConstantsU,
  CasTypesU,
  CasMixerU,
  CasDatabaseU,
  CasPlaylistU,
  VCL.ExtCtrls;

type
  TCasEngine = class(TObject)

  private
    m_hwndHandle                 : HWND;
    m_hwndOwner                  : HWND;
    m_Owner                      : TObject;
    m_MainMixer                  : TCasMixer;
    m_tmrUpdateInfo              : TTimer;
    m_dtDriverType               : TDriverType;

    m_CasDatabase                : TCasDatabase;
    m_CasPlaylist                : TCasPlaylist;

    m_nIdCount                   : Integer;
    m_bBlockBufferPositionUpdate : Boolean;
    m_bOwnerUpToDate             : Boolean;

    m_AudioDriver                : IAudioDriver;

    procedure OnUpdateInfoTimer(Sender: TObject);
    procedure ProcessMessage(var MsgRec: TMessage);
    procedure InitializeVariables;
    procedure FreeDriver;

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
    function  GetPlaying    : Boolean;
    function  GetSampleRate : Double;
    function  GetBufferSize : Cardinal;
    function  GetTime       : String;
    function  GetDuration   : String;
    function  GenerateID    : Integer;

    procedure ControlPanel;
    procedure SetLevel     (a_dLevel : Double);
    procedure SetPosition  (a_nPosition : Integer);
    procedure ChangeDriver (a_dtDriverType : TDriverType; a_nID : Integer);

    function  AddTrackToPlaylist(a_nTrackId, a_nPosition : Integer) : Boolean;
    function  AddTrack(a_CasTrack : TCasTrack; a_nMixerId : Integer) : Boolean;
    procedure ClearTracks;
    procedure CalculateBuffers(a_LeftOut : PIntArray; a_RightOut : PIntArray);


    property Driver      : IAudioDriver     read m_AudioDriver  write m_AudioDriver;
    property DriverType  : TDriverType      read m_dtDriverType write m_dtDriverType;
    property Level       : Double           read GetLevel       write SetLevel;
    property Position    : Integer          read GetPosition    write SetPosition;

    property Playlist    : TCasPlaylist     read m_CasPlaylist  write m_CasPlaylist;
    property Database    : TCasDatabase     read m_CasDatabase  write m_CasDatabase;
    property MainMixer   : TCasMixer        read m_MainMixer    write m_MainMixer;
    property Handle      : HWND             read m_hwndHandle   write m_hwndHandle;

    property Progress    : Double           read GetProgress;
    property Length      : Integer          read GetLength;
    property Time        : String           read GetTime;
    property Duration    : String           read GetDuration;

    property Ready       : Boolean          read GetReady;
    property Playing     : Boolean          read GetPlaying;
    property SampleRate  : Double           read GetSampleRate;
    property BufferSize  : Cardinal         read GetBufferSize;

  end;

var
  CasEngine: TCasEngine;

implementation

uses
  VCL.Dialogs,
  System.Classes,
  System.SysUtils,
  CasBasicFxU,
  CasDirectSoundU,
  CasAsioU,
  CasUtilsU,
  Math;


//==============================================================================
constructor TCasEngine.Create(a_Owner : TObject; a_Handle : HWND = 0);
begin
  m_Owner     := a_Owner;
  m_hwndOwner := a_Handle;

  InitializeVariables;
end;

//==============================================================================
destructor TCasEngine.Destroy;
begin
  DestroyWindow(m_hwndHandle);

  m_tmrUpdateInfo.Enabled := False;
  m_tmrUpdateInfo.Free;

  FreeDriver;

  Inherited;
end;

//==============================================================================
procedure TCasEngine.InitializeVariables;
begin
  CasEngine    := Self;
  m_hwndHandle := AllocateHWnd(ProcessMessage);

  m_tmrUpdateInfo := TTimer.Create(nil);
  m_tmrUpdateInfo.Interval := 10;
  m_tmrUpdateInfo.OnTimer := OnUpdateInfoTimer;
  m_tmrUpdateInfo.Enabled := True;

  m_MainMixer       := TCasMixer.Create;
  m_MainMixer.ID    := 0;
  m_MainMixer.Level := 1;

  m_CasDatabase := TCasDatabase.Create;
  m_CasDatabase.AddMixer(m_MainMixer);
  m_CasPlaylist := TCasPlaylist.Create(m_CasDatabase);
  m_CasPlaylist.Position := 0;

  m_nIdCount      := 0;
  m_AudioDriver  := nil;
  m_dtDriverType := dtNone;

  m_bBlockBufferPositionUpdate := False;
  m_bOwnerUpToDate             := True;
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
procedure TCasEngine.FreeDriver;
begin
  if (m_AudioDriver <> nil) then
    m_AudioDriver := nil;
end;

//==============================================================================
procedure TCasEngine.ChangeDriver(a_dtDriverType : TDriverType; a_nID : Integer);
begin
  m_dtDriverType := a_dtDriverType;

  //////////////////////////////////////////////////////////////////////////////
  ///  Close running drivers
  FreeDriver;

  //////////////////////////////////////////////////////////////////////////////
  ///  Open new driver
  if m_AudioDriver = nil then
  begin
    case a_dtDriverType of
      dtASIO        : m_AudioDriver := TCasAsio.Create(Self);
      dtDirectSound : m_AudioDriver := TCasDirectSound.Create(Self);
    end;

    if m_AudioDriver <> nil then
      m_AudioDriver.InitDriver(a_nID);
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
procedure TCasEngine.CalculateBuffers(a_LeftOut : PIntArray; a_RightOut : PIntArray);
var
  nBufferIdx  : Integer;
  nPosition   : Integer;
  nTrackIdx   : Integer;
  nTrackID    : Integer;
  nMixerIdx   : Integer;
  nBufInSize  : Integer;
  nBufEndPos  : Integer;
  dGap        : Double;
  CasTrack    : TCasTrack;
  CasMixer    : TCasMixer;
  LeftMaster  : TIntArray;
  RightMaster : TIntArray;
  LeftTrack   : TIntArray;
  RightTrack  : TIntArray;

  //////////////////////////////////////////////////////////////////////////////
  ///  This procedure requires initialized data
  procedure AddTrackToBuffer;
  var
    nBufferIdx : Integer;
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

begin
  if m_CasPlaylist.Speed > 0 then
  begin
    // The gap variable is used in order to prevent distortion when changing the
    // speed of playlist. It enables the interpolation algorithm to determine
    // which value goes first in the buffer.
    dGap := (1 - Frac(m_CasPlaylist.RelPos)) / m_CasPlaylist.Speed;

    nBufInSize := Ceil((BufferSize - dGap) * m_CasPlaylist.Speed) + 2;

    SetLength(TIntArray(a_LeftOut^),  BufferSize);
    SetLength(TIntArray(a_RightOut^), BufferSize);

    SetLength(LeftMaster,    nBufInSize);
    SetLength(RightMaster,   nBufInSize);
    SetLength(LeftTrack,     nBufInSize);
    SetLength(RightTrack,    nBufInSize);

    // Clear buffers:
    for nBufferIdx := 0 to BufferSize - 1 do
    begin
      TIntArray(a_LeftOut^) [nBufferIdx] := 0;
      TIntArray(a_RightOut^)[nBufferIdx] := 0;
    end;

    // For each mixer, get all linked tracks:
    for nMixerIdx := 0 to m_CasDatabase.Mixers.Count - 1 do
    begin
      CasMixer := m_CasDatabase.Mixers.Items[nMixerIdx];
      for nTrackIdx := 0 to CasMixer.Tracks.Count - 1 do
      begin
        nTrackID := CasMixer.Tracks.Items[nTrackIdx];
        if m_CasDatabase.GetTrackById(nTrackID, CasTrack) then
        begin
          // If the track's position is not -1, it's in the playlist:
          if (CasTrack.Position >= 0) then
          begin
            // If track is within buffer range its data is added:
            nPosition := Trunc(m_CasPlaylist.RelPos) - CasTrack.Position;
            if (nPosition + nBufInSize >= 0) then
              AddTrackToBuffer;

            // If playlist reached the end but the buffer still not full, the
            // tracks at the beginning are added too:
            nBufEndPos := m_CasPlaylist.Position + nBufInSize - m_CasPlaylist.Length;
            nPosition  := Trunc(m_CasPlaylist.RelPos) - (CasTrack.Position + m_CasPlaylist.Length);
            if (nBufEndPos >= 0) and (CasTrack.Position < nBufEndPos) then
              AddTrackToBuffer;

            // Note: theoretically there could be a buffer that is two or more
            // times bigger than the track's length, in that case we should add
            // the track more times in the same buffer. That could be a future
            // improvement.
          end;
        end;
      end;
    end;

    // Interpolate whole playlist:
    InterpolateRT(@LeftMaster,
                  @RightMaster,
                  a_LeftOut,
                  a_RightOut,
                  nBufInSize,
                  BufferSize,
                  m_CasPlaylist.Speed,
                  0,
                  dGap);

    // Update playlist's position:
    m_CasPlaylist.RelPos := m_CasPlaylist.RelPos + BufferSize * m_CasPlaylist.Speed;

    // If the position of the playlist's exceeded it's length, the tracks at the
    // beginning already have been considered, so the position doesn't go back to
    // zero. Instead it goes pass the start:
    while m_CasPlaylist.RelPos > m_CasPlaylist.Length do
      m_CasPlaylist.RelPos := m_CasPlaylist.RelPos - m_CasPlaylist.Length;

    m_bOwnerUpToDate := False;
  end
end;

//==============================================================================
procedure TCasEngine.Play;
begin
  if m_AudioDriver <> nil then
    m_AudioDriver.Play;
end;

//==============================================================================
procedure TCasEngine.Pause;
begin
  if m_AudioDriver <> nil then
    m_AudioDriver.Pause;
end;

//==============================================================================
procedure TCasEngine.Stop;
begin
  if m_AudioDriver <> nil then
    m_AudioDriver.Stop;

  m_CasPlaylist.Position := 0;
end;

//==============================================================================
procedure TCasEngine.Prev;
var
  nIndex : Integer;
  nPos   : Integer;
begin
  if m_AudioDriver <> nil then
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
  if m_AudioDriver <> nil then
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
procedure TCasEngine.ControlPanel;
begin
  if (m_AudioDriver <> nil) then
  begin
    if m_AudioDriver is TCasAsio then
      TCasAsio(m_AudioDriver).ControlPanel
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
  Result := (m_AudioDriver <> nil);
end;

//==============================================================================
function TCasEngine.GetPlaying : Boolean;
begin
  Result := (m_AudioDriver <> nil) and m_AudioDriver.Playing;
end;


//==============================================================================
function TCasEngine.GetSampleRate : Double;
begin
  Result := c_nDefaultSampleRate;

  if m_AudioDriver <> nil then
    Result := m_AudioDriver.SampleRate;
end;

//==============================================================================
function TCasEngine.GetBufferSize : Cardinal;
begin
  Result := c_nDefaultBufSize;

  if m_AudioDriver <> nil then
    Result := m_AudioDriver.BufferSize;
end;

//==============================================================================
function TCasEngine.GetTime : String;
var
  dSampleRate : Double;
begin
  dSampleRate := GetSampleRate;

  if dSampleRate > 0 then
    Result := TimeString(Trunc(1000 * (m_CasPlaylist.Position / dSampleRate)));
end;

//==============================================================================
function TCasEngine.GetDuration : String;
var
  dSampleRate : Double;
begin
  dSampleRate := GetSampleRate;

  if dSampleRate > 0 then
    Result := TimeString(Trunc(1000 * (m_CasPlaylist.Length / dSampleRate)));
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


