unit CasUtilsU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Math,
  CasTrackU,
  CasConstantsU;

  function BoolToInt(a_bBool : Boolean) : Integer;

implementation

//==============================================================================
function BoolToInt(a_bBool : Boolean) : Integer;
begin
  if a_bBool then
    Result := 1
  else
    Result := 0;
end;

end.
