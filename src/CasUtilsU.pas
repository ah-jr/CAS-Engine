unit CasUtilsU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Math,
  SysUtils,
  CasTrackU,
  CasTypesU,
  CasConstantsU;

function BoolToInt (a_bBool : Boolean) : Integer;
function TimeString(a_nMiliSeconds : Int64 ; a_tmMeasure : TSecondSplit = spNone) : String;
function GE_L      (a_nTarget, a_nFirst, a_nSecond : Integer) : Boolean;
function RunCommand(a_strCommand : string; a_bStdIn : TBytes; a_bRead : Boolean = False) : TBytes;
function IntBufferToPcm24(bufLeft, bufRight : PIntArray; a_nSmpIdx, a_nByteIdx : Integer) : Byte;
function AudioFormatToString(afFormat : TAudioFormat) : String;

implementation

//==============================================================================
function BoolToInt(a_bBool : Boolean) : Integer;
begin
  if a_bBool then
    Result := 1
  else
    Result := 0;
end;

//==============================================================================
function TimeString(a_nMiliSeconds : Int64 ; a_tmMeasure : TSecondSplit = spNone) : String;
var
  nHours     : Integer;
  nMinutes   : Integer;
  nSeconds   : Integer;
  nRemaining : Int64;
begin
  Result := '';

  nRemaining := a_nMiliSeconds;
  nHours     := Trunc(nRemaining / (1000 * HOUR_SEC));

  nRemaining := nRemaining - (nHours   * HOUR_SEC   * 1000);
  nMinutes   := Trunc(nRemaining / (1000 * MINUTE_SEC));

  nRemaining := nRemaining - (nMinutes * MINUTE_SEC * 1000);
  nSeconds   := Trunc(nRemaining / 1000);

  if nHours > 0 then
  begin
    Result := Result + IntToStr(nHours) + ':';
    Result := Result + FormatFloat('00', nMinutes) + ':';
  end
  else
    Result := Result + IntToStr(nMinutes) + ':';

  Result := Result + FormatFloat('00', nSeconds);

  nRemaining := nRemaining - (nSeconds * 1000);

  case a_tmMeasure of
    spMilliSeconds : Result := Result + ':' + IntToStr(Trunc(nRemaining / 1));
    spCentiSeconds : Result := Result + ':' + IntToStr(Trunc(nRemaining / 10));
    spDeciSeconds  : Result := Result + ':' + IntToStr(Trunc(nRemaining / 100));
  end;

end;

//==============================================================================
function GE_L(a_nTarget, a_nFirst, a_nSecond : Integer) : Boolean;
begin
  Result := (a_nTarget >= a_nFirst) and (a_nTarget < a_nSecond);
end;

//==============================================================================
function RunCommand(a_strCommand : string; a_bStdIn : TBytes; a_bRead : Boolean = False) : TBytes;
const
  c_nBufSize = 4096;
var
  hdlStdOutRd    : THandle;
  hdlStdOutWr    : THandle;
  hdlStdInRd     : THandle;
  hdlStdInWr     : THandle;
  tmpStartupInfo : TStartupInfo;
  tmpProcessInfo : TProcessInformation;
  chBufOut       : array[0..c_nBufSize] of Byte;
  chBufIn        : array[0..c_nBufSize] of Byte;
  saAttr         : SECURITY_ATTRIBUTES;
  bReading       : Boolean;
  bWriting       : Boolean;
  nBufIdx        : Integer;
  nDataIdx       : Integer;
  nWrLength      : Integer;
  dwRead         : DWORD;
  dwWritten      : DWORD;
  tmpProgram     : String;
begin
  saAttr.nLength              := sizeof(SECURITY_ATTRIBUTES);
  saAttr.bInheritHandle       := TRUE;
  saAttr.lpSecurityDescriptor := nil;

  // Create stdout :
  CreatePipe(hdlStdOutRd, hdlStdOutWr, @saAttr, 0);
  SetHandleInformation(hdlStdOutRd, HANDLE_FLAG_INHERIT, 0);

  // Create stdin :
  CreatePipe(hdlStdInRd, hdlStdInWr, @saAttr, 0);
  SetHandleInformation(hdlStdInWr, HANDLE_FLAG_INHERIT, 0);

  tmpProgram := Trim(a_strCommand);
  FillChar(tmpStartupInfo, SizeOf(tmpStartupInfo), 0);

  tmpStartupInfo.cb          := SizeOf(TStartupInfo);
  tmpStartupInfo.wShowWindow := SW_HIDE;
  tmpStartupInfo.hStdOutput  := hdlStdOutWr;
  tmpStartupInfo.hStdInput   := hdlStdInRd;
  tmpStartupInfo.dwFlags     := tmpStartupInfo.dwFlags or STARTF_USESTDHANDLES;

  if CreateProcess(nil, PChar(tmpProgram), nil, nil, True, CREATE_NO_WINDOW,
    nil, nil, tmpStartupInfo, tmpProcessInfo) then
  begin
    CloseHandle(hdlStdOutWr);
    CloseHandle(hdlStdInRd);

    // Read from stdout
    bReading := a_bRead;
    dwRead   := 0;
    nDataIdx := 0;

    while (bReading) do
    begin
      bReading := ReadFile(hdlStdOutRd, chBufOut, c_nBufSize, &dwRead, nil);
      SetLength(Result, nDataIdx + Integer(dwRead));

      for nBufIdx := 0 to dwRead - 1 do
      begin
        Result[nDataIdx] := chBufOut[nBufIdx];
        Inc(nDataIdx);
      end;
    end;

    // Write to stdin
    bWriting  := Length(a_bStdIn) > 0;
    dwWritten := 0;
    nWrLength := 0;
    nDataIdx  := 0;

    while (bWriting) do
    begin
      for nBufIdx := 0 to c_nBufSize - 1 do
      begin
        nWrLength := nBufIdx + 1;
        if nDataIdx >= Length(a_bStdIn) then Break;

        chBufIn[nBufIdx] := a_bStdIn[nDataIdx];
        Inc(nDataIdx);
      end;

      bWriting := WriteFile(hdlStdInWr, chBufIn, nWrLength, &dwWritten, nil);
      bWriting := bWriting and (nDataIdx < Length(a_bStdIn));
    end;

    CloseHandle(hdlStdOutRd);
    CloseHandle(hdlStdInWr);

    WaitForSingleObject(tmpProcessInfo.hProcess, INFINITE );
    CloseHandle(tmpProcessInfo.hProcess);
    CloseHandle(tmpProcessInfo.hThread);
  end
  else
  begin
    RaiseLastOSError;
  end;
end;

//==============================================================================
function IntBufferToPcm24(bufLeft, bufRight : PIntArray; a_nSmpIdx, a_nByteIdx : Integer) : Byte;
begin
  if a_nByteIdx < c_nBytesInChannel then
    Result := TIntArray(bufLeft^) [a_nSmpIdx] shr (8 * (a_nByteIdx))
  else
    Result := TIntArray(bufRight^)[a_nSmpIdx] shr (8 * (a_nByteIdx - c_nBytesInChannel));
end;

//==============================================================================
function AudioFormatToString(afFormat : TAudioFormat) : String;
begin
  Result := '';
  case afFormat of
    afMp3 : Result := '.mp3';
    afWav : Result := '.wav';
  end;
end;

end.
