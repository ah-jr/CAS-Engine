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
                 dtASIO,
                 dtNone);

  TAudioFormat = (afMp3,
                  afWav);

  TAudioSpecs = record
    BitDepth   : Integer;
    SampleRate : Integer;
    Format     : TAudioFormat;
  end;

  TRawData = record
    Right : Array of Integer;
    Left  : Array of Integer;
  end;
  PRawData = ^TRawData;

  TTrackInfo = record
    Title : String;
    Data  : PRawData;
  end;

  TIntArray = Array of Integer;
  PIntArray = ^TIntArray;

  TCallbackEvent  = procedure(nOffset : Cardinal) of object;
  TCallbackExtern = function : Integer of object; stdcall;

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
