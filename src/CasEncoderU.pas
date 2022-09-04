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
const
  c_strFfmpegBin      = 'ffmpeg/ffmpeg.exe';
begin
  Result := True;

  try
    aobFiledata := RenderToPcm(a_CasEngine);
    strCommand := '-f s24le -acodec pcm_s24le -ar ' +
                  a_asOut.SampleRate.ToString       +
                  ' -ac 2 -i pipe: "'               +
                  a_strFileName + '"';

    RunCommand(c_strFfmpegBin + ' ' + strCommand, aobFiledata);
  except
    Result := False;
  end;
end;

//==============================================================================
function TCasEncoder.RenderToPcm(a_CasEngine : TCasEngine) : TBytes;
var
  bufLeft       : TIntArray;
  bufRight      : TIntArray;
  nLastPosition : Integer;
  nSmpIdx       : Integer;
  nByteIdx      : Integer;
  bResult       : Byte;
begin
  SetLength(Result, 0);
  a_CasEngine.SetPosition(0);
  nLastPosition := 0;

  while a_CasEngine.GetPosition > nLastPosition do
  begin
    nLastPosition := a_CasEngine.GetPosition;

    a_CasEngine.CalculateBuffers(@bufLeft, @bufRight);
    SetLength(Result, Length(Result) + Length(bufLeft)  * c_nBytesInChannel +
                                       Length(bufRight) * c_nBytesInChannel);

    for nSmpIdx := 0 to Length(bufLeft) - 1 do
    begin
      for nByteIdx := 0 to c_nBytesInSample - 1 do
      begin
        bResult := IntBufferToPcm24(@bufLeft, @bufRight, nSmpIdx, nByteIdx);
        Result[Length(Result) - (c_nBytesInSample - nByteIdx)] := bResult;
      end;
    end;
  end;
end;

end.
