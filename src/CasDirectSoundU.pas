unit CasDirectSoundU;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  Classes,
  Windows,
  DirectSound,
  CasDsThreadU,
  CasTypesU,
  CasTrackU;

type
  TCasDirectSound = class(TInterfacedObject, IAudioDriver)
  private
    m_CasEngine   : TObject;
    m_CasDsThread : TCasDsThread;

    m_bIsStarted  : Boolean;

    m_RightBuffer : TIntArray;
    m_LeftBuffer  : TIntArray;

    m_nBufferSize : Cardinal;
    m_nSampleRate : Cardinal;
    m_nSampleSize : Cardinal;

    m_SoundBuffer : IDirectSoundBuffer;
    m_DirectSound : IDirectSound;


    procedure InitializeVariables;
    procedure BufferCallback(nOffset : Cardinal);
    function  ConvertSample (a_nSmpIdx, a_nByteIdx : Integer) : Byte;
    procedure CreateBuffer;

  public
    constructor Create(a_Owner : TObject);
    destructor  Destroy; override;

    procedure Play;
    procedure Pause;
    procedure Stop;

    procedure InitDriver (a_nID : Integer);
    procedure CloseDriver;
    procedure NotifyOwner  (a_ntNotification : TNotificationType);

    function  GetPlaying    : Boolean;
    function  GetReady      : Boolean;
    function  GetSampleRate : Double;
    function  GetBufferSize : Cardinal;

    property Playing    : Boolean   read GetPlaying;
    property Ready      : Boolean   read GetReady;
    property SampleRate : Double    read GetSampleRate;
    property BufferSize : Cardinal  read GetBufferSize;

  end;

implementation

uses
  MMSystem,
  Math,
  CasEngineU,
  CasConstantsU;

//==============================================================================
constructor TCasDirectSound.Create(a_Owner : TObject);
begin
  if a_Owner is TCasEngine then
    m_CasEngine := a_Owner;

  m_CasDsThread := nil;

  InitializeVariables;
end;

//==============================================================================
destructor TCasDirectSound.Destroy;
begin
  CloseDriver;

  //////////////////////////////////////////////////////////////////////////////
  ///  Stop playback and Nil pointers
  m_SoundBuffer.Stop;
  m_SoundBuffer := nil;
  m_DirectSound := nil;

  inherited;
end;

//==============================================================================
procedure TCasDirectSound.InitializeVariables;
var
  hWnd : THandle;
begin
  m_bIsStarted := False;
  m_nBufferSize := c_nDefaultBufSize;
  m_nSampleRate := c_nDefaultSampleRate;
  m_nSampleSize := m_nBufferSize * c_nBytesInSample;

  //////////////////////////////////////////////////////////////////////////////
  ///  Creates m_DirectSound object
  hWnd := GetForegroundWindow();
	if (hWnd = 0) then
		hWnd := GetDesktopWindow();

  DirectSoundCreate(nil, m_DirectSound, nil);
  m_DirectSound.SetCooperativeLevel(hWnd, DSSCL_PRIORITY);

  //////////////////////////////////////////////////////////////////////////////
  ///  Create buffers and start
  CreateBuffer;
end;

//==============================================================================
procedure TCasDirectSound.CreateBuffer;
var
  bufDesc   : DSBUFFERDESC;
  wavFormat : TWaveFormatEx;
begin
  //////////////////////////////////////////////////////////////////////////////
  ///  Set the wave format and buffer attributes
  wavFormat.wFormatTag      := 1;
  wavFormat.nChannels       := c_nChannelCount;
  wavFormat.nSamplesPerSec  := m_nSampleRate;
  wavFormat.nAvgBytesPerSec := c_nBytesInSample * m_nSampleRate;
  wavFormat.nBlockAlign     := c_nBytesInSample;
  wavFormat.wBitsPerSample  := 8 * c_nBytesInChannel;
  wavFormat.cbSize          := 0;

  ZeroMemory(@bufDesc, SizeOf(DSBUFFERDESC));

  bufDesc.dwSize        := SizeOf(DSBUFFERDESC);
  bufDesc.dwFlags       := DSBCAPS_CTRLPOSITIONNOTIFY or DSBCAPS_GLOBALFOCUS;
  bufDesc.dwBufferBytes := 2 * m_nSampleSize;
  bufDesc.lpwfxFormat   := @wavFormat;

  //////////////////////////////////////////////////////////////////////////////
  ///  Create the buffer object
  m_DirectSound.CreateSoundBuffer(bufDesc, m_SoundBuffer, nil);
end;

//==============================================================================
procedure TCasDirectSound.BufferCallback(nOffset : Cardinal);
var
  ptrAudio1     : Pointer;
  ptrAudio2     : Pointer;
  dwBytesAudio1 : Cardinal;
  dwBytesAudio2 : Cardinal;
  nSmpIdx       : Integer;
  nByteIdx      : Integer;
  nSamples      : Integer;
begin
  if m_bIsStarted then
  begin
    if m_CasEngine is TCasEngine then
      (m_CasEngine as TCasEngine).CalculateBuffers(@m_LeftBuffer, @m_RightBuffer);

    //////////////////////////////////////////////////////////////////////////////
    ///  Lock for writing
    m_SoundBuffer.Lock(nOffset,
                       m_nSampleSize,
                       @ptrAudio1,
                       @dwBytesAudio1,
                       @ptrAudio2,
                       @dwBytesAudio2,
                       0);

    //////////////////////////////////////////////////////////////////////////////
    ///  Clear buffer
    if (ptrAudio1 <> nil) then
      ZeroMemory(ptrAudio1, dwBytesAudio1);

    if (ptrAudio2 <> nil) then
      ZeroMemory(ptrAudio2, dwBytesAudio2);

    //////////////////////////////////////////////////////////////////////////////
    ///  Fill buffer
    nSamples := dwBytesAudio1 div 6;

    for nSmpIdx := 0 to nSamples - 1 do
    begin
      for nByteIdx := 0 to c_nBytesInSample - 1 do
        TByteArray(ptrAudio1^)[nSmpIdx*c_nBytesInSample + nByteIdx] := ConvertSample(nSmpIdx, nByteIdx);
    end;

    //////////////////////////////////////////////////////////////////////////////
    ///  Unlock for writing
    m_SoundBuffer.UnLock(ptrAudio1,
                         dwBytesAudio1,
                         ptrAudio2,
                         dwBytesAudio2);
  end;
end;

//==============================================================================
function TCasDirectSound.ConvertSample(a_nSmpIdx, a_nByteIdx : Integer) : Byte;
begin
  if a_nByteIdx < c_nBytesInChannel then
    Result := m_LeftBuffer [a_nSmpIdx] shr (8 * (a_nByteIdx))
  else
    Result := m_RightBuffer[a_nSmpIdx] shr (8 * (a_nByteIdx - c_nBytesInChannel));
end;

//==============================================================================
procedure TCasDirectSound.Play;
begin
  m_SoundBuffer.Play(0, 0, DSCBSTART_LOOPING);
  m_bIsStarted := True;
end;

//==============================================================================
procedure TCasDirectSound.Pause;
begin
  m_SoundBuffer.Stop;
  m_bIsStarted := False;
end;

//==============================================================================
procedure TCasDirectSound.Stop;
begin
  m_SoundBuffer.Stop;
  m_bIsStarted := False;
end;

//==============================================================================
procedure TCasDirectSound.NotifyOwner(a_ntNotification : TNotificationType);
begin
  if (m_CasEngine is TCasEngine) then
    (m_CasEngine as TCasEngine).NotifyOwner(a_ntNotification);
end;

//==============================================================================
procedure TCasDirectSound.InitDriver(a_nID : Integer);
begin
  m_CasDsThread := TCasDsThread.Create(m_SoundBuffer, m_nSampleSize);
  m_CasDsThread.Callback := BufferCallback;
end;

//==============================================================================
procedure TCasDirectSound.CloseDriver;
begin
  if (m_CasDsThread <> nil) then
  begin
    m_CasDsThread.Terminate;
    m_CasDsThread.WaitFor;
    FreeAndNil(m_CasDsThread);
  end;
end;

//==============================================================================
function  TCasDirectSound.GetPlaying : Boolean;
begin
  Result := m_bIsStarted;
end;

//==============================================================================
function  TCasDirectSound.GetReady : Boolean;
begin
  Result := m_CasDsThread <> nil;
end;

//==============================================================================
function  TCasDirectSound.GetSampleRate : Double;
begin
  Result := m_nSampleRate;
end;

//==============================================================================
function  TCasDirectSound.GetBufferSize : Cardinal;
begin
  Result := m_nBufferSize;
end;

end.
