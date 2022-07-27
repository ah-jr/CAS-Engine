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
    m_CasEngine                  : TObject;

    m_nBufferSize : Cardinal;
    m_nSampleSize : Cardinal;

    m_CasDsThread : TCasDsThread;

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
end;

//==============================================================================
destructor TCasDirectSound.Destroy;
begin
  CloseDriver;

  Inherited;
end;

//==============================================================================
procedure TCasDirectSound.Play;
begin

end;

//==============================================================================
procedure TCasDirectSound.Pause;
begin

end;

//==============================================================================
procedure TCasDirectSound.Stop;
begin

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
  m_CasDsThread := TCasDsThread.Create(False);
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

end;

//==============================================================================
function  TCasDirectSound.GetReady : Boolean;
begin

end;

//==============================================================================
function  TCasDirectSound.GetSampleRate : Double;
begin

end;

//==============================================================================
function  TCasDirectSound.GetBufferSize : Cardinal;
begin

end;

end.
