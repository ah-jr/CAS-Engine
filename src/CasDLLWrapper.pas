unit CasDLLWrapper;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Math,
  SysUtils,
  CasEngineU,
  CasTrackU,
  CasTypesU,
  CasConstantsU,
  CasDecoderU;

var
  g_Engine  : TCasEngine  = nil;
  g_Decoder : TCasDecoder = nil;
  g_nSampleRate : Integer = 44100;

function ce_init : Integer; stdcall;
function ce_free : Integer; stdcall;

function ce_loadDirectSound : Integer; stdcall;
function ce_loadFileIntoTrack (filename : PAnsiChar) : Integer; stdcall;
function ce_addTrackToPlaylist(trackID : Integer) : Integer; stdcall;
function ce_setCallback(callback : TCallbackExtern) : Integer; stdcall;

function ce_play : Integer; stdcall;
function ce_pause : Integer; stdcall;
function ce_stop : Integer; stdcall;
function ce_setSpeed(speed : Double) : Integer; stdcall;
function ce_setLevel(level : Double) : Integer; stdcall;
function ce_getProgress : Double; stdcall;

function ce_isPlaying : Boolean; stdcall;


implementation

function ce_init : Integer;
begin
  Result := 0;

  try
    g_Engine  := TCasEngine.Create;
    g_Decoder := TCasDecoder.Create;

  except
    Result := -1;
  end;
end;

function ce_free: Integer;
begin
  Result := 1;

  try
    if g_Engine <> nil then
      g_Engine.Free;

    if g_Decoder <> nil then
      g_Engine.Free;

  except
    Result := -1;
  end;
end;

////////////////////////////////////////////////////////////////////////////////
//   ce_loadFile : Returns track's ID, or -1 if it fails
function ce_loadFileIntoTrack(filename : PAnsiChar) : Integer;
var
  Track : TTrackInfo;
begin
  Result := -1;

  try
    if FileExists(String(filename)) then
    begin
      Track  := g_Decoder.DecodeFile(String(filename), g_nSampleRate);
      Result := g_Engine.AddTrack(Track.Title, Track.Data, 0);
    end;
  except
  end;
end;

function ce_addTrackToPlaylist(trackID : Integer) : Integer;
begin
  Result := 1;

  try
    g_Engine.Playlist.AddClip(trackID, 0);
  except
    Result := -1;
  end;
end;

function ce_setCallback(callback : TCallbackExtern) : Integer;
begin
  Result := 1;

  try
    g_Engine.CallbackExt := callback;
  except
    Result := -1;
  end;
end;

function ce_loadDirectSound : Integer;
begin
  Result := 1;

  try
    g_Engine.ChangeDriver(dtDirectSound, 0);
  except
    Result := -1;
  end;
end;

function ce_play : Integer;
begin
  Result := 1;

  try
    g_Engine.Play;
  except
    Result := -1;
  end;
end;

function ce_pause : Integer;
begin
  Result := 1;

  try
    g_Engine.Pause;
  except
    Result := -1;
  end;
end;

function ce_stop : Integer;
begin
  Result := 1;

  try
    g_Engine.Stop;
  except
    Result := -1;
  end;
end;

function ce_setSpeed(speed : Double) : Integer;
begin
  Result := 1;

  try
    g_Engine.Playlist.Speed := speed;
  except
    Result := -1;
  end;
end;

function ce_setLevel(level : Double) : Integer;
begin
  Result := 1;

  try
    g_Engine.Level := level;
  except
    Result := -1;
  end;
end;

function ce_getProgress : Double;
begin
  try
    Result := g_Engine.Progress;
  except
    Result := -1;
  end;
end;

function ce_isPlaying : Boolean;
begin
  Result := g_Engine.Playing;
end;



end.
