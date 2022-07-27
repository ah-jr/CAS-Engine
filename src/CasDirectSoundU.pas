unit CasDirectSoundU;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  Classes,
  Windows,
  DirectSound,
  CasTrackU;

type
  TCasDirectSound = class(TThread)
  private
    m_nBufferSize : Cardinal;
    m_nSampleSize : Cardinal;

    m_SoundBuffer : IDirectSoundBuffer;
    m_DirectSound : IDirectSound;

    procedure PopulateBuffer(nOffset : Cardinal);
    procedure SetBuffersLoop;
    procedure CreateBuffer;

  protected
    procedure Execute; override;

  public
    constructor Create(CreateSuspended: Boolean = False);
    destructor  Destroy; override;

  end;

implementation

uses
  MMSystem,
  Math,
  CasConstantsU;

//==============================================================================
constructor TCasDirectSound.Create(CreateSuspended: Boolean);
begin
  Inherited Create(CreateSuspended);

  m_nBufferSize := c_nDirSndDefaultBufSize;
  m_nSampleSize := m_nBufferSize * c_nBytesInSample;
end;

//==============================================================================
destructor TCasDirectSound.Destroy;
begin
  Inherited;
end;

//==============================================================================
procedure TCasDirectSound.Execute;
var
  hWnd : THandle;
begin
  NameThreadForDebugging('CasDirectSound');

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
  m_SoundBuffer.Play(0, 0, DSCBSTART_LOOPING);
  SetBuffersLoop;

  //////////////////////////////////////////////////////////////////////////////
  ///  Stop playback and Nil pointers
  m_SoundBuffer.Stop;
  m_SoundBuffer := nil;
  m_DirectSound := nil;
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
  wavFormat.nSamplesPerSec  := c_nDefaultSampleRate;
  wavFormat.nAvgBytesPerSec := c_nBytesInSample * c_nDefaultSampleRate;
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
procedure TCasDirectSound.SetBuffersLoop;
var
  dwPlayPos  : Cardinal;
  dwWritePos : Cardinal;
  bHalved    : Boolean;
begin
  bHalved := True;

  while (not Terminated) do
  begin
    ////////////////////////////////////////////////////////////////////////////
    ///  The buffer is divided in two. Each time a half of the buffer starts
    ///  playing, the other half gets filled with new samples
    m_SoundBuffer.GetCurrentPosition(@dwPlayPos, @dwWritePos);

    if (dwPlayPos < m_nSampleSize) and (bHalved) then
    begin
      PopulateBuffer(m_nSampleSize);
      bHalved := False;
    end
    else if (dwPlayPos >= m_nSampleSize) and (not bHalved)  then
    begin
      PopulateBuffer(0);
      bHalved := True;
    end;

    Sleep(1);   // Later: Set a event and use WaitFor
  end;
end;

//==============================================================================
procedure TCasDirectSound.PopulateBuffer(nOffset : Cardinal);
var
  ptrAudio1     : Pointer;
  ptrAudio2     : Pointer;
  dwBytesAudio1 : Cardinal;
  dwBytesAudio2 : Cardinal;
  nBufferIdx    : Integer;
begin
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
  for nBufferIdx := 0 to dwBytesAudio1 - 1 do
    TByteArray(ptrAudio1^)[nBufferIdx] := 0; //WIP

  //////////////////////////////////////////////////////////////////////////////
  ///  Unlock for writing   
  m_SoundBuffer.UnLock(ptrAudio1, 
                     dwBytesAudio1, 
                     ptrAudio2, 
                     dwBytesAudio2);
end;

end.
