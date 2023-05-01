unit CasTrackU;

interface

uses
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.Messages,
  CasTypesU;

type
  TCasTrack = class

  private
    m_nID          : Integer;
    m_strTitle     : String;
    m_dLevel       : Double;
    m_RawData      : PRawData;
    m_lstClips     : TList<Integer>;

    //procedure Normalize;
    function  GetSize : Integer;

  public
    constructor Create;
    destructor  Destroy; override;

    function  Clone   : TTrackInfo;

    procedure AddClip   (a_nClipID : Integer);
    procedure RemoveClip(a_nClipID : Integer);

    property ID        : Integer               read m_nID          write m_nID;
    property Title     : String                read m_strTitle     write m_strTitle;

    property RawData   : PRawData              read m_RawData      write m_RawData;
    property Level     : Double                read m_dLevel       write m_dLevel;
    property Size      : Integer               read GetSize;
    property Clips     : TList<Integer>        read m_lstClips;

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
  m_dLevel    := 1;
  m_RawData   := nil;

  m_lstClips  := TList<Integer>.Create;
end;

//==============================================================================
destructor TCasTrack.Destroy;
begin
  if m_RawData <> nil then
  begin
    SetLength(m_RawData.Left,  0);
    SetLength(m_RawData.Right, 0);

    Dispose(m_RawData);
  end;

  m_lstClips.Free;
end;

//==============================================================================
function TCasTrack.Clone : TTrackInfo;
var
  pData : PRawData;
begin
  Result.Title := m_strTitle;

  New(pData);

  SetLength(pData.Left,  GetSize);
  SetLength(pData.Right, GetSize);

  Move(m_RawData.Left [0], pData.Left [0], GetSize * SizeOf(Integer));
  Move(m_RawData.Right[0], pData.Right[0], GetSize * SizeOf(Integer));

  Result.Data := pData;
end;

//==============================================================================
procedure TCasTrack.AddClip(a_nClipID : Integer);
begin
  m_lstClips.Add(a_nClipID);
end;

//==============================================================================
procedure TCasTrack.RemoveClip(a_nClipID : Integer);
begin
  m_lstClips.Remove(a_nClipID);
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

