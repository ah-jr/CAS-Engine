unit CasUtilsU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Math,
  CasTrackU,
  CasTypesU,
  CasConstantsU;

  function BoolToInt (a_bBool : Boolean) : Integer;
  function TimeString(a_nMiliSeconds : Int64 ; a_tmMeasure : TSecondSplit = spNone) : String;
  function GE_L      (a_nTarget, a_nFirst, a_nSecond : Integer) : Boolean;

implementation

uses
  System.SysUtils;

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

end.
