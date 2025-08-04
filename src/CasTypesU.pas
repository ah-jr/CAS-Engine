unit CasTypesU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  SysUtils,
  System.Generics.Collections;

type
  TNotificationType = (ntBuffersCreated,
                       ntBuffersDestroyed,
                       ntBuffersUpdated,
                       ntDriverClosed,
                       ntRequestedReset);

  TSecondSplit = (spMilliSeconds,
                  spCentiSeconds,
                  spDeciSeconds,
                  spNone);

  TDriverType = (dtDirectSound,
                 dtASIO,
                 dtNone);

  TAudioFormat = (afMp3,
                  afWav);

  TAudioSpecs = record
    BitDepth   : Integer;
    SampleRate : Integer;
    Format     : TAudioFormat;
  end;

  TRawData = record
    Right : Array of Integer;
    Left  : Array of Integer;
  end;
  PRawData = ^TRawData;

  TTrackInfo = record
    Title : String;
    Data  : PRawData;
  end;

  TSmallMinMax = record
    Max : SmallInt;
    Min : SmallInt;
  end;

  PBytes = ^TBytes;

  TIntArray = Array of Integer;
  PIntArray = ^TIntArray;

  TCallbackEvent  = procedure(nOffset : Cardinal) of object;
  TCallbackExtern = function : Integer of object; stdcall;

  IAudioDriver = interface(IUnknown)
    procedure Play;
    procedure Pause;
    procedure Stop;

    procedure InitDriver (a_nID : Integer);
    procedure CloseDriver;
    procedure NotifyOwner  (a_ntNotification : TNotificationType);

    function  GetPlaying    : Boolean;
    function  GetReady      : Boolean;
    function  GetSampleRate : Double;
    function  GetBufferSize : Cardinal;

    property Playing    : Boolean   read GetPlaying;
    property Ready      : Boolean   read GetReady;
    property SampleRate : Double    read GetSampleRate;
    property BufferSize : Cardinal  read GetBufferSize;
  end;

  TSampleMinMax = class
    private
      m_nSegTree : TList<TSmallMinMax>;

    public
      constructor Create(a_pData : PIntArray);
      destructor  Destroy; override;

      procedure Update(a_nIndex : Integer; a_nValue : SmallInt);

      function GetMinMax(a_nStart, a_nEnd : Integer) : TSmallMinMax;
  end;

implementation

uses
  Math;

//==============================================================================
constructor TSampleMinMax.Create(a_pData : PIntArray);
var
  nIndex  : Integer;
  nSize   : Integer;
  smmInfo : TSmallMinMax;
  nMax    : Integer;
begin
  nMax := Trunc(Math.Power(2, 24 - 1)); // FIX THAT

  smmInfo.Max := 0;
  smmInfo.Min := 0;
  nSize       := Length(a_pData^);

  m_nSegTree := TList<TSmallMinMax>.Create;

  for nIndex := 0 to (2 * nSize - 1) do
    m_nSegTree.Add(smmInfo);

  for nIndex := 0 to nSize - 1 do
  begin
    smmInfo.Max := Trunc(TIntArray(a_pData^)[nIndex] * (32767 / nMax));
    smmInfo.Min := Trunc(TIntArray(a_pData^)[nIndex] * (32767 / nMax));

    m_nSegTree[nSize + nIndex] := smmInfo;
  end;

  for nIndex := nSize - 1 downto 1 do
  begin
    smmInfo.Max := Max(m_nSegTree[2*nIndex].Max, m_nSegTree[2*nIndex + 1].Max);
    smmInfo.Min := Min(m_nSegTree[2*nIndex].Min, m_nSegTree[2*nIndex + 1].Min);

    m_nSegTree[nIndex] := smmInfo;
  end;
end;

//==============================================================================
destructor TSampleMinMax.Destroy;
begin
  m_nSegTree.Free;
end;

//==============================================================================
procedure TSampleMinMax.Update(a_nIndex : Integer; a_nValue : SmallInt);
begin
  //
end;

//==============================================================================
function TSampleMinMax.GetMinMax(a_nStart, a_nEnd : Integer) : TSmallMinMax;
var
  nSize : Integer;
  nMin  : SmallInt;
  nMax  : SmallInt;
begin
  nSize := m_nSegTree.Count div 2;

  a_nStart := Min(a_nStart, nSize - 1);
  a_nEnd   := Min(a_nEnd,   nSize - 1);
  a_nStart := a_nStart + nSize;
  a_nEnd   := a_nEnd   + nSize;

  nMax := -32768;
  nMin :=  32767;

  while a_nStart < a_nEnd do
  begin
    if (a_nStart and 1) = 1 then
    begin
      nMax := Max(nMax, m_nSegTree[a_nStart].Max);
      nMin := Min(nMin, m_nSegTree[a_nStart].Min);
      Inc(a_nStart);
    end;
    
    if (a_nEnd and 1) = 1 then
    begin
      Dec(a_nEnd);
      nMax := Max(nMax, m_nSegTree[a_nEnd].Max);
      nMin := Min(nMin, m_nSegTree[a_nEnd].Min);
    end;    

    a_nStart := a_nStart div 2;
    a_nEnd   := a_nEnd   div 2;
  end;

  Result.Max := nMax;
  Result.Min := nMin;
end;


end.
