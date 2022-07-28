unit CasBasicFxU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  Math,
  CasTrackU,
  CasTypesU,
  CasConstantsU;

procedure InterpolateRT(a_LeftIn    : PIntArray;
                        a_RightIn   : PIntArray;
                        a_LeftOut   : PIntArray;
                        a_RightOut  : PIntArray;
                        a_nInSize   : Integer;
                        a_nOutSize  : Integer;
                        a_dSpeed    : Double;
                        a_nOffset   : Integer;
                        a_dGap      : Double = 0);

implementation

uses
  CasUtilsU;

//==============================================================================
procedure InterpolateRT(a_LeftIn    : PIntArray;
                        a_RightIn   : PIntArray;
                        a_LeftOut   : PIntArray;
                        a_RightOut  : PIntArray;
                        a_nInSize   : Integer;
                        a_nOutSize  : Integer;
                        a_dSpeed    : Double;
                        a_nOffset   : Integer;
                        a_dGap      : Double = 0);
var
  dInc       : Double;
  dSpeedInv  : Double;
  dDistance  : Double;
  nIndex     : Integer;
  nBufferIdx : Integer;
begin
  dSpeedInv := 1 / a_dSpeed;
  nIndex    := 0;

  // Initial distance from next sample is equal to the gap of samples between
  // buffers:
  if a_dGap <> 0
    then dDistance := a_dGap
    else dDistance := dSpeedInv;

  for nBufferIdx := 0 to a_nOutSize - 1 do
  begin
    // When resampling to decrease pitch, each position in the output buffer
    // receives the value of its two nearest neighbors multiplied by the
    // inverse of their distances:
    if a_dSpeed < 1 then
    begin
      if GE_L(a_nOffset + nIndex + 1, 0, a_nInSize) then
      begin
        TIntArray(a_LeftOut^) [nBufferIdx] := Trunc(TIntArray(a_LeftIn^) [a_nOffset + nIndex    ] * ((            dDistance) * a_dSpeed) +
                                                    TIntArray(a_LeftIn^) [a_nOffset + nIndex + 1] * ((dSpeedInv - dDistance) * a_dSpeed));

        TIntArray(a_RightOut^)[nBufferIdx] := Trunc(TIntArray(a_RightIn^)[a_nOffset + nIndex    ] * ((            dDistance) * a_dSpeed) +
                                                    TIntArray(a_RightIn^)[a_nOffset + nIndex + 1] * ((dSpeedInv - dDistance) * a_dSpeed));
        dDistance := dDistance - 1;

        if dDistance < 0 then
        begin
          Inc(nIndex);
          dDistance := dSpeedInv + dDistance;
        end;
      end
      else
      begin
        TIntArray(a_LeftOut^) [nBufferIdx] := 0;
        TIntArray(a_RightOut^)[nBufferIdx] := 0;
      end;
    end
    // When resampling to increase pitch, each position in the output buffer
    // receives the mean of the samples within that range:
    else if a_dSpeed > 1 then
    begin
      if GE_L(a_nOffset + nIndex, 0, a_nInSize) then
      begin
        TIntArray(a_LeftOut^) [nBufferIdx] := Trunc(dDistance * TIntArray(a_LeftIn^) [a_nOffset + nIndex]);
        TIntArray(a_RightOut^)[nBufferIdx] := Trunc(dDistance * TIntArray(a_RightIn^)[a_nOffset + nIndex]);

        dInc := 0;

        while (1 - (dDistance + dInc)) > -FLT_EPS do
        begin
          Inc(nIndex);
          if GE_L(a_nOffset + nIndex, 0, a_nInSize) then
          begin
            Inc(TIntArray(a_LeftOut^) [nBufferIdx], Trunc(min(1 - (dDistance + dInc), dSpeedInv) * TIntArray(a_LeftIn^) [a_nOffset + nIndex]));
            Inc(TIntArray(a_RightOut^)[nBufferIdx], Trunc(min(1 - (dDistance + dInc), dSpeedInv) * TIntArray(a_RightIn^)[a_nOffset + nIndex]));
          end;
          dInc := dInc + dSpeedInv;
        end;

        dInc := dInc - dSpeedInv;

        if IsZero((1 - (dDistance + dInc)) - dSpeedInv, FLT_EPS) then
          Inc(nIndex);

        dDistance := dSpeedInv - (1 - (dDistance + dInc));
      end
      else
      begin
        TIntArray(a_LeftOut^) [nBufferIdx] := 0;
        TIntArray(a_RightOut^)[nBufferIdx] := 0;
      end;
    end
    // If there's no speed change, simply copy values to the output buffer:
    else
    begin
      if GE_L(a_nOffset + nBufferIdx, 0, a_nInSize) then
      begin
        TIntArray(a_LeftOut^) [nBufferIdx] := TIntArray(a_LeftIn^) [a_nOffset + nBufferIdx];
        TIntArray(a_RightOut^)[nBufferIdx] := TIntArray(a_RightIn^)[a_nOffset + nBufferIdx];
      end
      else
      begin
        TIntArray(a_LeftOut^) [nBufferIdx] := 0;
        TIntArray(a_RightOut^)[nBufferIdx] := 0;
      end;
    end
  end;
end;

end.
