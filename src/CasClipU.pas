unit CasClipU;

interface

uses
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.Messages,
  CasTypesU;

type
  TCasClip = class

  private
    m_nID          : Integer;
    m_nTrackID     : Integer;
    m_nPosition    : Integer;
    m_nOffset      : Integer;
    m_nSize        : Integer;

  public
    constructor Create(a_nID : Integer; a_nTrackID : Integer);

    destructor  Destroy; override;

    function GetSize     : Integer;
    function GetOffset   : Integer;
    function GetStartPos : Integer;
    function GetEndPos   : Integer;

    procedure SetSize    (a_nSize     : Integer);
    procedure SetStartPos(a_nStartPos : Integer);
    procedure SetOffset  (a_nOffset   : Integer);

    procedure SetLeftBound (a_nPos : Integer);
    procedure SetRightBound(a_nPos : Integer);

    property ID          : Integer      read m_nID;
    property TrackID     : Integer      read m_nTrackID;
    property EndPos      : Integer      read GetEndPos;
    property StartPos    : Integer      read GetStartPos  write SetStartPos;
    property Offset      : Integer      read GetOffset    write SetOffset;
    property Size        : Integer      read GetSize      write SetSize;

  end;

implementation

uses
  Math,
  CasConstantsU;

//==============================================================================
constructor TCasClip.Create(a_nID : Integer; a_nTrackID : Integer);
begin
  m_nID          := a_nID;
  m_nTrackID     := a_nTrackID;
  m_nPosition    := 0;
  m_nOffset      := 0;
  m_nSize        := 0;
end;

//==============================================================================
destructor TCasClip.Destroy;
begin
  //
end;

//==============================================================================
function TCasClip.GetSize : Integer;
begin
  Result := m_nSize;
end;

//==============================================================================
function TCasClip.GetStartPos : Integer;
begin
  Result := m_nPosition;
end;

//==============================================================================
function TCasClip.GetOffset : Integer;
begin
  Result := m_nOffset;
end;

//==============================================================================
function TCasClip.GetEndPos : Integer;
begin
  Result := m_nPosition + m_nSize;
end;

//==============================================================================
procedure TCasClip.SetSize(a_nSize : Integer);
begin
  m_nSize := a_nSize;
end;

//==============================================================================
procedure TCasClip.SetStartPos(a_nStartPos : Integer);
begin
  m_nPosition := a_nStartPos;
end;

//==============================================================================
procedure TCasClip.SetOffset(a_nOffset : Integer);
begin
  m_nOffset   := a_nOffset;
end;

//==============================================================================
procedure TCasClip.SetLeftBound(a_nPos : Integer);
var
  nDif : Integer;
begin
  nDif        := a_nPos - m_nPosition;
  m_nPosition := a_nPos;
  m_nOffset   := m_nOffset + nDif;
  m_nSize     := m_nSize - nDif;
end;

//==============================================================================
procedure TCasClip.SetRightBound(a_nPos : Integer);
begin
  m_nSize := a_nPos - m_nPosition;
end;

end.

