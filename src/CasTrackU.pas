unit CasTrackU;

interface

uses
  Winapi.Windows,
  Winapi.Messages;

type
  TRawData = record
    Right : Array of Integer;
    Left  : Array of Integer;
  end;
  PRawData = ^TRawData;

  TCasTrack = class

  private
    m_nID       : Integer;
    m_strTitle  : String;
    m_nPosition : Integer;
    m_dLevel    : Double;
    m_RawData   : PRawData;

    //procedure Normalize;
    function  GetSize : Integer;

  public
    constructor Create;
    destructor  Destroy; override;
    function  Clone   : TCasTrack;
    function  IsPlaying(a_dPosition : Double) : Boolean;

    property ID          : Integer  read m_nID         write m_nID;
    property Title       : String   read m_strTitle    write m_strTitle;
    property Position    : Integer  read m_nPosition   write m_nPosition;

    property RawData     : PRawData read m_RawData     write m_RawData;
    property Level       : Double   read m_dLevel      write m_dLevel;
    property Size        : Integer  read GetSize;

  end;

implementation

uses
  Math,
  CasConstantsU;

//==============================================================================
constructor TCasTrack.Create;
begin
  m_nID       := -1;
  m_strTitle  := '';
  m_nPosition := -1;
  m_dLevel    := 1;
  RawData     := nil;
end;

//==============================================================================
destructor TCasTrack.Destroy;
begin
  if RawData <> nil then
  begin
    SetLength(m_RawData.Left,  0);
    SetLength(m_RawData.Right, 0);
  end;
end;

//==============================================================================
function TCasTrack.Clone : TCasTrack;
var
  pData : PRawData;
begin
  Result       := TCasTrack.Create;
  Result.ID    := -1;
  Result.Title := m_strTitle;
  Result.Level := m_dLevel;

  New(pData);

  SetLength(pData.Left,  GetSize);
  SetLength(pData.Right, GetSize);

  Move(m_RawData.Left [0], pData.Left [0], GetSize * SizeOf(Integer));
  Move(m_RawData.Right[0], pData.Right[0], GetSize * SizeOf(Integer));

  Result.RawData := pData;
end;

//==============================================================================
function TCasTrack.IsPlaying(a_dPosition : Double) : Boolean;
begin
  Result := (m_nPosition < a_dPosition) and (m_nPosition + Size > a_dPosition);
end;

////==============================================================================
//procedure TCasTrack.Normalize;
//begin
//  // WIP
//end;

//==============================================================================
function TCasTrack.GetSize : Integer;
begin
  if m_RawData <> nil then
  begin
    Result := Length(m_RawData.Right);
  end
  else
    Result := 0;
end;

end.

