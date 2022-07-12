unit CasBasicFxU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Math,
  CasTrackU,
  CasConstantsU;

procedure InterpolateRT(a_LeftIn    : PIntArray;
                        a_RightIn   : PIntArray;
                        a_LeftOut   : PIntArray;
                        a_RightOut  : PIntArray;
                        a_nInSize   : Integer;
                        a_nOutSize  : Integer;
                        a_dSpeed    : Double;
                        a_nOffset   : Integer);

implementation

//==============================================================================
procedure InterpolateRT(a_LeftIn    : PIntArray;
                        a_RightIn   : PIntArray;
                        a_LeftOut   : PIntArray;
                        a_RightOut  : PIntArray;
                        a_nInSize   : Integer;
                        a_nOutSize  : Integer;
                        a_dSpeed    : Double;
                        a_nOffset   : Integer);
var
  p, k, r : double;
  v : integer;
  nBufferIdx : Integer;
  d : Double;
begin
  r := 1 / a_dSpeed;
  p := r;
  v := 0;
  d := r;

  for nBufferIdx := 0 to a_nOutSize - 1 do
  begin
    if a_dSpeed < 1 then
    begin
      if (v + 1) < a_nInSize then
      begin
        TIntArray(a_LeftOut^) [nBufferIdx] := Trunc(TIntArray(a_LeftIn^) [a_nOffset + v    ] * ((    d) * a_dSpeed) +
                                                    TIntArray(a_LeftIn^) [a_nOffset + v + 1] * ((r - d) * a_dSpeed));

        TIntArray(a_RightOut^)[nBufferIdx] := Trunc(TIntArray(a_RightIn^)[a_nOffset + v    ] * ((    d) * a_dSpeed) +
                                                    TIntArray(a_RightIn^)[a_nOffset + v + 1] * ((r - d) * a_dSpeed));
        d := d - 1;

        if d < 0 then
        begin
          inc(v);
          d := r + d;
        end;
      end
    end
    else if a_dSpeed > 1 then
    begin
      TIntArray(a_LeftOut^) [nBufferIdx] := Trunc(p * TIntArray(a_LeftIn^) [a_nOffset + v]);
      TIntArray(a_RightOut^)[nBufferIdx] := Trunc(p * TIntArray(a_RightIn^)[a_nOffset + v]);
      k := 0;

      while (1-(p+k)) > -FLT_EPS do
      begin
        inc(v);
        inc(TIntArray(a_LeftOut^) [nBufferIdx], Trunc(min(1-(p+k), r) * TIntArray(a_LeftIn^) [a_nOffset + v]));
        inc(TIntArray(a_RightOut^)[nBufferIdx], Trunc(min(1-(p+k), r) * TIntArray(a_RightIn^)[a_nOffset + v]));

        k := k + r;
      end;

      k := k - r;

      if IsZero((1-(p+k)) - r, FLT_EPS) then
      begin
        inc(v);
        p := r;
      end
      else
      begin
        p := r - (1-(p+k));
      end;
    end
    else
    begin
      TIntArray(a_LeftOut^) [nBufferIdx] := TIntArray(a_LeftIn^) [a_nOffset + nBufferIdx];
      TIntArray(a_RightOut^)[nBufferIdx] := TIntArray(a_RightIn^)[a_nOffset + nBufferIdx];
    end
  end;
end;

end.
