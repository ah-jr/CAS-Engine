unit CasEncoderU;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  CasEngineU,
  CasTypesU,
  Classes,
  Windows,
  CasTrackU;

type
  TCasEncoder = class
  private
    //

  public
    constructor Create;
    destructor Destroy; override;

    function AudioExport(a_CasEngine : TCasEngine; a_asOut : TAudioSpecs; a_strFileName : String) : Boolean;
    function RenderToPcm(a_CasEngine : TCasEngine) : TBytes;

  end;

implementation

uses
  Math,
  CasUtilsU,
  CasConstantsU;

//==============================================================================
constructor TCasEncoder.Create;
begin
  //
end;

//==============================================================================
destructor TCasEncoder.Destroy;
begin
  Inherited;
end;

//==============================================================================
function TCasEncoder.AudioExport(a_CasEngine : TCasEngine; a_asOut : TAudioSpecs; a_strFileName : String) : Boolean;
var
  strCommand  : String;
  aobFiledata : TBytes;
  strFullPath : String;
const
  c_strFfmpegBin      = 'ffmpeg/ffmpeg.exe';
begin
  Result := True;

  strFullPath := a_strFileName + AudioFormatToString(a_asOut.Format);

  try
    aobFiledata := RenderToPcm(a_CasEngine);
    strCommand := '-f s24le -acodec pcm_s24le -ar ' +
                  a_asOut.SampleRate.ToString       +
                  ' -ac 2 -i pipe: "'               +
                  strFullPath + '"';

    RunCommand(c_strFfmpegBin + ' ' + strCommand, aobFiledata);
  except
    Result := False;
  end;
end;

//==============================================================================
function TCasEncoder.RenderToPcm(a_CasEngine : TCasEngine) : TBytes;
var
  bufLeft   : TIntArray;
  bufRight  : TIntArray;
  nSmpIdx   : Integer;
  nByteIdx  : Integer;
  nResIdx   : Integer;
  nPosition : Integer;
  bResult   : Byte;
begin
  nPosition := 0;
  a_CasEngine.SetPosition(0);
  SetLength(Result, a_CasEngine.Playlist.Length * c_nBytesInSample);

  while nPosition < Length(Result) do
  begin
    a_CasEngine.CalculateBuffers(@bufLeft, @bufRight);

    for nSmpIdx := 0 to a_CasEngine.BufferSize - 1 do
    begin
      for nByteIdx := 0 to c_nBytesInSample - 1 do
      begin
        bResult := IntBufferToPcm24(@bufLeft, @bufRight, nSmpIdx, nByteIdx);
        nResIdx := nPosition + nSmpIdx*c_nBytesInSample + nByteIdx;
        if nResIdx < Length(Result) then
          Result[nResIdx] := bResult;
      end;
    end;

    Inc(nPosition, a_CasEngine.BufferSize * c_nBytesInSample);
  end;
end;

end.
