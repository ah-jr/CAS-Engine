unit CasTypesU;

interface

uses
  Winapi.Windows,
  Winapi.Messages;

type
  TNotificationType = (ntBuffersCreated,
                       ntBuffersDestroyed,
                       ntBuffersUpdated,
                       ntDriverClosed,
                       ntRequestedReset);

  TSecondSplit = (spMilliSeconds,
                  spCentiSeconds,
                  spDeciSeconds,
                  spNone);

  TDriverType = (dtDirectSound,
                 dtASIO);

  TIntArray = Array of Integer;
  PIntArray = ^TIntArray;

  IAudioDriver = interface(IUnknown)
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

end.
