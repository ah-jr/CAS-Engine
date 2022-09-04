unit CasDecoderU;

interface

uses
  System.SysUtils,
  System.IOUtils,
  System.Generics.Collections,
  Classes,
  Windows,
  CasTrackU;

type
  TCasDecoder = class(TThread)
  private
    m_hwndCaller      : HWND;
    m_nAllowDecode    : Boolean;
    m_lstFiles        : TStrings;
    m_dSampleRate     : Single;
    m_lstCasTracks    : TList<TCasTrack>;

  protected
    procedure Execute; override;

  public
    constructor Create;
    destructor Destroy; override;

    function  DataToTrack    (a_aobInputPCMData : TBytes) : TCasTrack;
    function  DecodeFile     (a_strFileName : String; a_dSampleRate : Double) : TCasTrack;
    procedure AsyncDecodeFile(a_hwndCaller : HWND; a_lstFiles : TStrings; a_dSampleRate : Double);

    property Tracks : TList<TCasTrack> read m_lstCasTracks write m_lstCasTracks;

  end;

implementation

uses
  Math,
  CasUtilsU,
  CasConstantsU;

//==============================================================================
constructor TCasDecoder.Create;
begin
  m_nAllowDecode    := False;
  m_lstFiles        := nil;
  m_dSampleRate     := -1;
  m_lstCasTracks    := TList<TCasTrack>.Create;

  Inherited Create(False);
end;

//==============================================================================
destructor TCasDecoder.Destroy;
var
  CasTrack : TCasTrack;
begin
  for CasTrack in m_lstCasTracks do
    CasTrack.Free;

  m_lstCasTracks.Free;

  Terminate;

  Inherited;
end;

//==============================================================================
procedure TCasDecoder.Execute;
var
  strFileName : String;
begin
  NameThreadForDebugging('CasDecoder');

  while (not Terminated) do
  begin
    Sleep(10);  // Later: Set a event and use WaitFor
    if m_nAllowDecode and (m_lstFiles <> nil) then
    begin
      for strFileName in m_lstFiles do
        m_lstCasTracks.Add(DecodeFile(strFileName, m_dSampleRate));

      PostMessage(m_hwndCaller, CM_NotifyDecode, 0, 0);

      m_dSampleRate  := -1;
      m_hwndCaller   := 0;
      m_nAllowDecode := False;
    end;
  end;
end;

//==============================================================================
procedure TCasDecoder.AsyncDecodeFile(a_hwndCaller : HWND; a_lstFiles : TStrings; a_dSampleRate : Double);
begin
  m_dSampleRate := a_dSampleRate;
  m_hwndCaller  := a_hwndCaller;
  m_lstFiles    := a_lstFiles;

  m_nAllowDecode := True;
end;

//==============================================================================
function TCasDecoder.DecodeFile(a_strFileName : String; a_dSampleRate : Double)  : TCasTrack;
var
  strCommand  : String;
  aobFiledata : TBytes;
const
  c_strFfmpegBin      = 'ffmpeg/ffmpeg.exe';
begin
  try
    strCommand := '-i "'                              +
                  a_strFileName                       +
                  '" -f s24le -acodec pcm_s24le -ar ' +
                  a_dSampleRate.ToString              +
                  ' -ac 2 '                           +
                  'pipe:';

    aobFiledata     := RunCommand(c_strFfmpegBin + ' ' + strCommand, 0, True);
    Result          := DataToTrack(aobFiledata);
    Result.Title    := TPath.GetFileNameWithoutExtension(a_strFileName);
  except
    Result := nil;
  end;
end;

//==============================================================================
function TCasDecoder.DataToTrack(a_aobInputPCMData : TBytes) : TCasTrack;
var
  nSampleIdx         : Integer;
  nByteIdx           : Integer;
  nRightChannelBytes : Integer;
  nLeftChannelBytes  : Integer;
  nSize              : Integer;
  pData              : PRawData;
begin
  New(pData);

  nSize := Length(a_aobInputPCMData) div c_nBytesInSample;

  SetLength(pData.Left,  nSize);
  SetLength(pData.Right, nSize);


  for nSampleIdx := 0 to nSize - 1 do
  begin
    for nByteIdx := 0 to c_nBytesInChannel - 1  do
    begin
      nLeftChannelBytes  := a_aobInputPCMData[c_nBytesInSample * nSampleIdx + nByteIdx];
      nRightChannelBytes := a_aobInputPCMData[c_nBytesInSample * nSampleIdx + nByteIdx + c_nBytesInChannel];

      pData.Left[nSampleIdx]  := pData.Left[nSampleIdx]  + nLeftChannelBytes  * Trunc(Power(2, c_nByteSize * nByteIdx));
      pData.Right[nSampleIdx] := pData.Right[nSampleIdx] + nRightChannelBytes * Trunc(Power(2, c_nByteSize * nByteIdx));
    end;

    // Two's complement:
    if (pData.Left[nSampleIdx]  >= Power(2, c_nBitDepth - 1)) then
      pData.Left[nSampleIdx]  := pData.Left[nSampleIdx]  - Trunc(Power(2, c_nBitDepth));

    if (pData.Right[nSampleIdx] >= Power(2, c_nBitDepth - 1)) then
      pData.Right[nSampleIdx] := pData.Right[nSampleIdx] - Trunc(Power(2, c_nBitDepth));
  end;

  Result := TCasTrack.Create;
  Result.RawData := pData;

  SetLength(a_aobInputPCMData, 0);
end;

end.
