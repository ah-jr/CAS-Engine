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
    m_nStart       : Integer;
    m_nSize        : Integer;

  public
    constructor Create(a_nID : Integer; a_nTrackID : Integer);

    destructor  Destroy; override;

    function GetSize    : Integer;
    function GetPos     : Integer;
    function GetStart   : Integer;
    function GetLastPos : Integer;

    procedure SetSize (a_nSize  : Integer);
    procedure SetPos  (a_nPos   : Integer);
    procedure SetStart(a_nStart : Integer);

    property ID          : Integer      read m_nID;
    property TrackID     : Integer      read m_nTrackID;
    property LastPos     : Integer      read GetLastPos;
    property Pos         : Integer      read GetPos       write SetPos;
    property Start       : Integer      read GetStart     write SetStart;
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
  m_nStart       := 0;
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
function TCasClip.GetPos : Integer;
begin
  Result := m_nPosition;
end;

//==============================================================================
function TCasClip.GetStart : Integer;
begin
  Result := m_nStart;
end;

//==============================================================================
function TCasClip.GetLastPos : Integer;
begin
  Result := m_nPosition + m_nSize;
end;

//==============================================================================
procedure TCasClip.SetSize(a_nSize : Integer);
begin
  m_nSize := a_nSize;
end;

//==============================================================================
procedure TCasClip.SetPos(a_nPos : Integer);
begin
  m_nPosition := a_nPos;
end;

//==============================================================================
procedure TCasClip.SetStart(a_nStart : Integer);
var
  nDif : Integer;
begin
  nDif        := a_nStart - m_nStart;
  m_nStart    := a_nStart;
  m_nPosition := m_nPosition + nDif;
  m_nSize     := m_nSize - nDif;
end;

end.

