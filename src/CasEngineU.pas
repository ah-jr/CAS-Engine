unit CasEngineU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Generics.Collections,
  CasConstantsU,
  CasTypesU,
  CasMixerU,
  CasDatabaseU,
  CasPlaylistU,
  VCL.ExtCtrls;

type
  TCasEngine = class(TObject)

  private
    m_hwndHandle    : HWND;
    m_hwndOwner     : HWND;

    m_dtDriverType  : TDriverType;
    m_AudioDriver   : IAudioDriver;
    m_CasDatabase   : TCasDatabase;
    m_CasPlaylist   : TCasPlaylist;
    m_MainMixer     : TCasMixer;

    m_tmrUpdateInfo : TTimer;
    m_bBufferSync   : Boolean;
    m_nAsyncPos     : Integer;
    m_nUpdateCount  : Integer;
    m_dtLastUpdate  : TDateTime;
    m_bAsyncUpdate  : Boolean;
    m_ptrCallback   : TCallbackExtern;

    procedure StartUpdate;
    procedure StopUpdate;
    procedure OnUpdateInfoTimer(Sender: TObject);
    procedure ProcessMessage(var MsgRec: TMessage);
    procedure InitializeVariables;
    procedure FreeDriver;

  public
    constructor Create(a_hwndOwner : HWND = 0);
    destructor  Destroy; override;

    procedure NotifyOwner(a_ntNotification : TNotificationType);

    procedure Play;
    procedure Pause;
    procedure Stop;
    procedure Prev;
    procedure Next;
    procedure GoToClip(a_nID: Integer);

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
    function  GetTrackCount : Integer;

    procedure ControlPanel;
    procedure SetLevel     (a_dLevel : Double);
    procedure SetPosition  (a_nPosition : Integer);
    procedure ChangeDriver (a_dtDriverType : TDriverType; a_nID : Integer);

    function  AddTrack(a_strTitle : String; a_pData : PRawData; a_nMixerId : Integer = -1) : Integer;
    procedure ChangeTracksMixer(a_nTrackId : Integer; a_nMixerId : Integer);
    procedure DeleteTrack(a_nTrackId : Integer);
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
    property CallbackExt : TCallbackExtern  read m_ptrCallback  write m_ptrCallback;

    // Turn on AsyncUpdate if the size of the buffer is too large to update the
    // application fast enough.
    property AsyncUpdate : Boolean          read m_bAsyncUpdate write m_bAsyncUpdate;

    property Progress    : Double           read GetProgress;
    property Length      : Integer          read GetLength;
    property Time        : String           read GetTime;
    property Duration    : String           read GetDuration;

    property Ready       : Boolean          read GetReady;
    property Playing     : Boolean          read GetPlaying;
    property SampleRate  : Double           read GetSampleRate;
    property BufferSize  : Cardinal         read GetBufferSize;

  end;

implementation

uses
  VCL.Dialogs,
  System.Classes,
  System.SysUtils,
  CasBasicFxU,
  CasDirectSoundU,
  CasAsioU,
  CasUtilsU,
  CasTrackU,
  CasClipU,
  DateUtils,
  Math;


//==============================================================================
constructor TCasEngine.Create(a_hwndOwner : HWND = 0);
begin
  m_hwndOwner := a_hwndOwner;

  InitializeVariables;
end;

//==============================================================================
destructor TCasEngine.Destroy;
begin
  DestroyWindow(m_hwndHandle);

  m_tmrUpdateInfo.Enabled := False;
  m_tmrUpdateInfo.Free;
  m_CasDatabase.Free;
  m_CasPlaylist.Free;

  FreeDriver;

  Inherited;
end;

//==============================================================================
procedure TCasEngine.InitializeVariables;
var
  nIndex   : Integer;
  CasMixer : TCasMixer;
begin
  m_CasDatabase            := TCasDatabase.Create;
  m_hwndHandle             := AllocateHWnd(ProcessMessage);

  m_tmrUpdateInfo          := TTimer.Create(nil);
  m_tmrUpdateInfo.Interval := c_nUpdateInterval;
  m_tmrUpdateInfo.OnTimer  := OnUpdateInfoTimer;
  m_tmrUpdateInfo.Enabled  := True;

  m_MainMixer              := TCasMixer.Create;
  m_MainMixer.ID           := GenerateId;
  m_MainMixer.Level        := 0.75;

  m_CasDatabase.AddMixer(m_MainMixer);
  m_CasPlaylist            := TCasPlaylist.Create(m_CasDatabase);
  m_CasPlaylist.Position   := 0;

  for nIndex := 0 to c_nDefMixerCount - 1 do
  begin
    CasMixer              := TCasMixer.Create;
    CasMixer.ID           := GenerateId;
    CasMixer.Level        := 0.75;
    m_CasDatabase.AddMixer(CasMixer);
    m_MainMixer.AddMixer(CasMixer.ID);
  end;

  m_bAsyncUpdate           := False;
  m_nAsyncPos              := 0;
  m_nUpdateCount           := 0;
  m_AudioDriver            := nil;
  m_ptrCallback            := nil;
  m_dtDriverType           := dtNone;
  m_bBufferSync            := False;
  m_dtLastUpdate           := -1;
end;

//==============================================================================
procedure TCasEngine.StartUpdate;
begin
  m_dtLastUpdate := Now;
  m_tmrUpdateInfo.Enabled := True;
end;

//==============================================================================
procedure TCasEngine.StopUpdate;
begin
  m_tmrUpdateInfo.Enabled := False;
  m_dtLastUpdate := -1;
  m_bBufferSync  := False;
  m_nUpdateCount := 0;
end;

//==============================================================================
procedure TCasEngine.OnUpdateInfoTimer(Sender: TObject);
var
  dtDelta    : Double;
  dPosOffset : Double;
const
  c_nThreshold = 100;
begin
  if m_bAsyncUpdate then
  begin
    dtDelta := MilliSecondsBetween(Now, m_dtLastUpdate);

    if dtDelta > c_nUpdateInterval then
    begin
      NotifyOwner(ntBuffersUpdated);

      dPosOffset     := SampleRate * dtDelta * 0.001 * Playlist.Speed;
      m_nAsyncPos    := Trunc(m_nAsyncPos + dPosOffset);
      m_dtLastUpdate := Now;
      Inc(m_nUpdateCount);

      if m_nAsyncPos > m_CasPlaylist.Length then
        m_nAsyncPos := m_nAsyncPos - m_CasPlaylist.Length;

      // Sync with buffer once and a while
      if m_nUpdateCount > c_nThreshold then
      begin
        m_nUpdateCount := 0;
        m_nAsyncPos    := m_CasPlaylist.Position;
      end;
    end;
  end
  else
  begin
    if not m_bBufferSync then
    begin
      NotifyOwner(ntBuffersUpdated);
      m_bBufferSync  := True;
    end;
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
procedure TCasEngine.ChangeTracksMixer(a_nTrackId : Integer; a_nMixerId : Integer);
var
  OldCasMixer : TCasMixer;
  NewCasMixer : TCasMixer;
  CasTrack    : TCasTrack;
begin
  if not m_CasDatabase.GetTrackById(a_nTrackId, CasTrack) then
    Exit;

  if not m_CasDatabase.GetMixerById(a_nMixerId, NewCasMixer) then
    Exit;

  if m_CasDatabase.GetMixerById(CasTrack.MixerId, OldCasMixer) then
    OldCasMixer.RemoveTrack(CasTrack.ID);

  NewCasMixer.AddTrack(CasTrack.ID);
  CasTrack.MixerID := a_nMixerId;
end;

//==============================================================================
procedure TCasEngine.DeleteTrack(a_nTrackId : Integer);
begin
  m_CasPlaylist.RemoveTrack(a_nTrackId);
  m_CasDatabase.RemoveTrack(a_nTrackId);
end;

//==============================================================================
function TCasEngine.AddTrack(a_strTitle : String; a_pData : PRawData; a_nMixerId : Integer) : Integer;
var
  CasMixer : TCasMixer;
  CasTrack : TCasTrack;
begin
  CasTrack         := TCasTrack.Create(a_pData);
  CasTrack.Title   := a_strTitle;
  CasTrack.ID      := GenerateID;

  m_CasDatabase.AddTrack(CasTrack);
  Result := CasTrack.ID;

  if a_nMixerId < 0 then
    Exit;

  if m_CasDatabase.GetMixerById(a_nMixerId, CasMixer) then
  begin
    CasMixer.AddTrack(CasTrack.ID);
    CasTrack.MixerID := a_nMixerId;
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
  Pause;
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
  nMixerID    : Integer;
  nBufInSize  : Integer;
  nBufEndPos  : Integer;
  dGap        : Double;
  CasTrack    : TCasTrack;
  CasClip     : TCasClip;
  CasMixer    : TCasMixer;
  LeftMaster  : TIntArray;
  RightMaster : TIntArray;
  LeftTrack   : TIntArray;
  RightTrack  : TIntArray;
  nClipIdx    : Integer;
  nClipID     : Integer;
  nStart      : Integer;

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
        Trunc(m_MainMixer.Level * CasMixer.Level * LeftTrack [nBufferIdx]);

      RightMaster[nBufferIdx] := RightMaster[nBufferIdx] +
        Trunc(m_MainMixer.Level * CasMixer.Level * RightTrack[nBufferIdx]);
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
    for nMixerIdx := 0 to m_MainMixer.GetMixers.Count - 1 do
    begin
      nMixerID := m_MainMixer.GetMixers.Items[nMixerIdx];
      if m_CasDatabase.GetMixerById(nMixerID, CasMixer) then
      begin
        // For each track, get all clips:
        for nTrackIdx := 0 to CasMixer.Tracks.Count - 1 do
        begin
          nTrackID := CasMixer.Tracks.Items[nTrackIdx];
          if m_CasDatabase.GetTrackById(nTrackID, CasTrack) then
          begin
            // For each clip, add data to the buffer:
            for nClipIdx := 0 to CasTrack.Clips.Count - 1 do
            begin
              nClipID := CasTrack.Clips[nClipIdx];
            
              if m_CasPlaylist.IsClipInBuffer(nClipID, nBufInSize) then
              begin
                if m_CasPlaylist.GetClip(nClipID, CasClip) then
                begin
                  // If track is within buffer range its data is added:
                  nStart    := CasClip.StartPos - CasClip.Offset;
                  nPosition := Trunc(m_CasPlaylist.RelPos) - nStart;
                  if (nPosition + nBufInSize >= 0) then
                    AddTrackToBuffer;

                  // If playlist reached the end but the buffer still not full, the
                  // tracks at the beginning are added too:
                  nBufEndPos := m_CasPlaylist.Position + nBufInSize - m_CasPlaylist.Length;
                  nPosition  := Trunc(m_CasPlaylist.RelPos) - (nStart + m_CasPlaylist.Length);
                  if (nBufEndPos >= 0) and (nStart < nBufEndPos) then
                    AddTrackToBuffer;

                  // Note: theoretically there could be a buffer that is two or more
                  // times bigger than the track's length, in that case we should add
                  // the track more times in the same buffer. That could be a future
                  // improvement.
                end;
              end;
            end;
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

    m_bBufferSync := False;
  end;

  // Call extern functions (USE WISELY!)
  if Assigned(m_ptrCallback) then
    m_ptrCallback;
end;

//==============================================================================
procedure TCasEngine.Play;
begin
  if m_AudioDriver <> nil then
    m_AudioDriver.Play;

  StartUpdate;
end;

//==============================================================================
procedure TCasEngine.Pause;
begin
  if m_AudioDriver <> nil then
    m_AudioDriver.Pause;

  StopUpdate;
end;

//==============================================================================
procedure TCasEngine.Stop;
begin
  if m_AudioDriver <> nil then
    m_AudioDriver.Stop;

  StopUpdate;
  m_nAsyncPos := 0;
  m_CasPlaylist.Position := 0;
end;

//==============================================================================
procedure TCasEngine.Prev;
begin
  m_CasPlaylist.GoToPrevClip;
  m_nAsyncPos := m_CasPlaylist.Position;
end;

//==============================================================================
procedure TCasEngine.Next;
begin
  m_CasPlaylist.GoToNextClip;
  m_nAsyncPos := m_CasPlaylist.Position;
end;

//==============================================================================
procedure TCasEngine.GoToClip(a_nID: Integer);
begin
  m_CasPlaylist.GoToClip(a_nID);
  m_nAsyncPos := m_CasPlaylist.Position;
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
  Result := m_CasDatabase.GenerateID;
end;

//==============================================================================
function TCasEngine.GetLevel : Double;
begin
  Result := m_MainMixer.Level;
end;

//==============================================================================
function TCasEngine.GetPosition : Integer;
begin
  if m_bAsyncUpdate
    then Result := m_nAsyncPos
    else Result := m_CasPlaylist.Position;
end;

//==============================================================================
function TCasEngine.GetProgress : Double;
var
  nLength : Integer;
begin
  if m_bAsyncUpdate then
  begin
    nLength := m_CasPlaylist.Length;

    if nLength > 0
      then Result := m_nAsyncPos / nLength
      else Result := 0;
  end
    else Result := m_CasPlaylist.Progress;
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
function TCasEngine.GetTrackCount : Integer;
begin
  Result := m_CasDatabase.Tracks.Count;
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
  m_nAsyncPos := m_CasPlaylist.Position;
end;

//==============================================================================
end.


