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

function RunCommand(a_strCommand : string; a_bStdIn : TBytes) : TBytes;

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
function RunCommand(a_strCommand : string; a_bStdIn : TBytes) : TBytes;
const
  c_nBufSize = 4096;
var
  hdlStdOutRd    : THandle;
  hdlStdOutWr    : THandle;
  tmpStartupInfo : TStartupInfo;
  tmpProcessInfo : TProcessInformation;
  chBuf          : array[0..c_nBufSize] of Byte;
  saAttr         : SECURITY_ATTRIBUTES;
  bReading       : Boolean;
  nBufIdx        : Integer;
  nDataIdx       : Integer;
  dwRead         : DWORD;
  tmpProgram     : String;
begin
  saAttr.nLength              := sizeof(SECURITY_ATTRIBUTES);
  saAttr.bInheritHandle       := TRUE;
  saAttr.lpSecurityDescriptor := nil;

  CreatePipe(hdlStdOutRd, hdlStdOutWr, @saAttr, 0);
  SetHandleInformation(hdlStdOutRd, HANDLE_FLAG_INHERIT, 0);

  tmpProgram := Trim(a_strCommand);
  FillChar(tmpStartupInfo, SizeOf(tmpStartupInfo), 0);

  tmpStartupInfo.cb          := SizeOf(TStartupInfo);
  tmpStartupInfo.wShowWindow := SW_HIDE;
  tmpStartupInfo.hStdOutput  := hdlStdOutWr;
  tmpStartupInfo.dwFlags     := tmpStartupInfo.dwFlags or STARTF_USESTDHANDLES;

  if CreateProcess(nil, PChar(tmpProgram), nil, nil, True, CREATE_NO_WINDOW,
    nil, nil, tmpStartupInfo, tmpProcessInfo) then
  begin
    CloseHandle(tmpProcessInfo.hProcess);
    CloseHandle(tmpProcessInfo.hThread);
    CloseHandle(hdlStdOutWr);

    bReading := True;
    dwRead   := 0;
    nDataIdx := 0;

    // Read from process's pipe
    while (bReading) do
    begin
      bReading := ReadFile(hdlStdOutRd, chBuf, c_nBufSize, &dwRead, nil);
      SetLength(Result, nDataIdx + Integer(dwRead));

      for nBufIdx := 0 to dwRead - 1 do
      begin
        Result[nDataIdx] := chBuf[nBufIdx];
        Inc(nDataIdx);
      end;
    end;
  end
  else
  begin
    RaiseLastOSError;
  end;
end;

end.
