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
// Result := True;

// try

// aobFiledata := PlaylistToPcm(a_CasEngine);
// strCommand := ...
// RunCommand(strCommand, aobFiledata);

// except
// Result := False;



//  try
//    strCommand := '-i "'                              +
//                  a_strFileName                       +
//                  '" -f s24le -acodec pcm_s24le -ar ' +
//                  a_dSampleRate.ToString              +
//                  ' -ac 2 '                           +
//                  'pipe:';
//
//    aobFiledata     := RunCommand(c_strFfmpegBin + ' ' + strCommand);
//    Result          := CreateTrack(aobFiledata);
//    Result.Title    := TPath.GetFileNameWithoutExtension(a_strFileName);
//  except
//    Result := nil;
//  end;
end;

//==============================================================================
function TCasEncoder.RenderToPcm(a_CasEngine : TCasEngine) : TBytes;
var
  nSampleIdx         : Integer;
  nByteIdx           : Integer;
  nRightChannelBytes : Integer;
  nLeftChannelBytes  : Integer;
  nSize              : Integer;
  pData              : PRawData;
begin
// for ... a_CasEngine.CalculateBuffers(left, right)
// Result.Append(left, right)


//  New(pData);
//
//  nSize := Length(a_aobInputPCMData) div c_nBytesInSample;
//
//  SetLength(pData.Left,  nSize);
//  SetLength(pData.Right, nSize);
//
//
//  for nSampleIdx := 0 to nSize - 1 do
//  begin
//    for nByteIdx := 0 to c_nBytesInChannel - 1  do
//    begin
//      nLeftChannelBytes  := a_aobInputPCMData[c_nBytesInSample * nSampleIdx + nByteIdx];
//      nRightChannelBytes := a_aobInputPCMData[c_nBytesInSample * nSampleIdx + nByteIdx + c_nBytesInChannel];
//
//      pData.Left[nSampleIdx]  := pData.Left[nSampleIdx]  + nLeftChannelBytes  * Trunc(Power(2, c_nByteSize * nByteIdx));
//      pData.Right[nSampleIdx] := pData.Right[nSampleIdx] + nRightChannelBytes * Trunc(Power(2, c_nByteSize * nByteIdx));
//    end;
//
//    // Two's complement:
//    if (pData.Left[nSampleIdx]  >= Power(2, c_nBitDepth - 1)) then
//      pData.Left[nSampleIdx]  := pData.Left[nSampleIdx]  - Trunc(Power(2, c_nBitDepth));
//
//    if (pData.Right[nSampleIdx] >= Power(2, c_nBitDepth - 1)) then
//      pData.Right[nSampleIdx] := pData.Right[nSampleIdx] - Trunc(Power(2, c_nBitDepth));
//  end;
//
//  Result := TCasTrack.Create;
//  Result.RawData := pData;
//
//  SetLength(a_aobInputPCMData, 0);
end;

end.
