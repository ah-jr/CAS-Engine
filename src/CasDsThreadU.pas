unit CasDsThreadU;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  Classes,
  Windows,
  DirectSound,
  CasTypesU,
  CasTrackU;

type
  TCasDsThread = class(TThread)
  private
    m_SoundBuffer    : IDirectSoundBuffer;
    m_nSampleSize    : Cardinal;
    m_BufferCallback : TCallbackEvent;

  protected
    procedure Execute; override;

  public
    constructor Create(a_SoundBuffer : IDirectSoundBuffer; a_SampleSize : Cardinal);
    destructor  Destroy; override;

    property SampleSize : Cardinal       read m_nSampleSize    write m_nSampleSize;
    property Callback   : TCallbackEvent read m_BufferCallback write m_BufferCallback;
  end;

implementation

uses
  MMSystem,
  Math,
  CasConstantsU;

//==============================================================================
constructor TCasDsThread.Create(a_SoundBuffer : IDirectSoundBuffer; a_SampleSize : Cardinal);
begin
  Inherited Create(False);

  m_SoundBuffer := a_SoundBuffer;
  m_nSampleSize := a_SampleSize;
end;

//==============================================================================
destructor TCasDsThread.Destroy;
begin
  Inherited;
end;

//==============================================================================
procedure TCasDsThread.Execute;
var
  dwPlayPos  : Cardinal;
  dwWritePos : Cardinal;
  bHalved    : Boolean;
  pdwStatus  : DWORD;
begin
  NameThreadForDebugging('CasDirectSound');

  bHalved := True;

  while (not Terminated) do
  begin
    ////////////////////////////////////////////////////////////////////////////
    ///  The buffer is divided in two. Each time a half of the buffer starts
    ///  playing, the other half gets filled with new samples
    if m_SoundBuffer <> nil then
    begin
      m_SoundBuffer.GetCurrentPosition(@dwPlayPos, @dwWritePos);
      m_SoundBuffer.GetStatus(pdwStatus);
    end;

    if Assigned(m_BufferCallback) and (pdwStatus and DSBSTATUS_PLAYING > 0) then
    begin
      if (dwPlayPos < m_nSampleSize) and (bHalved) then
      begin
        m_BufferCallback(m_nSampleSize);
        bHalved := False;
      end
      else if (dwPlayPos >= m_nSampleSize) and (not bHalved)  then
      begin
        m_BufferCallback(0);
        bHalved := True;
      end;
    end;

    Sleep(1);   // Later: Set a event and use WaitFor
  end;
end;

end.
