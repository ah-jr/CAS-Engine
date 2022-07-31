unit CasPlaylistU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Generics.Collections,
  CasDatabaseU;

type
  TCasPlaylist = class

  private
    m_dPosition  : Double;
    m_dSpeed     : Double;
    m_lstTracks  : TList<Integer>;
    m_lstActTrks : TList<Integer>;

    m_CasDatabase : TCasDatabase;

    function GetProgress : Double;
    function GetLength   : Integer;
    function GetPosition : Integer;

    procedure SetPosition(a_nPosition : Integer);

  public
    constructor Create(a_CasDatabase: TCasDatabase);
    destructor  Destroy; override;

    procedure AddTrack   (a_nID: Integer);
    procedure RemoveTrack(a_nID: Integer);
    procedure ClearTracks;
    procedure GoToTrack  (a_nID: Integer);

    function GetActiveTracks : TList<Integer>;
    function GetTrackProgress(a_nTrackId : Integer) : Double;

    property Progress    : Double   read GetProgress;
    property Position    : Integer  read GetPosition   write SetPosition;
    property RelPos      : Double   read m_dPosition   write m_dPosition;
    property Length      : Integer  read GetLength;
    property Speed       : Double   read m_dSpeed      write m_dSpeed;

    property ActiveTracks : TList<Integer> read GetActiveTracks;

  end;

implementation

uses
  Math,
  CasConstantsU,
  CasTrackU;

//==============================================================================
constructor TCasPlaylist.Create(a_CasDatabase: TCasDatabase);
begin
  m_dPosition   := 0;
  m_dSpeed      := 1;
  m_CasDatabase := a_CasDatabase;
  m_lstTracks   := TList<Integer>.Create;
  m_lstActTrks  := TList<Integer>.Create;
end;

//==============================================================================
destructor TCasPlaylist.Destroy;
begin
  m_lstTracks.Free;
  m_lstActTrks.Free;

  Inherited;
end;

//==============================================================================
function TCasPlaylist.GetPosition : Integer;
begin
  Result := Ceil(m_dPosition);
end;

//==============================================================================
procedure TCasPlaylist.SetPosition(a_nPosition : Integer);
begin
  m_dPosition := Min(Max(0, a_nPosition), GetLength);
end;

//==============================================================================
function TCasPlaylist.GetProgress : Double;
var
  nLength : Integer;
begin
  nLength := GetLength;

  if nLength > 0 then
    Result := m_dPosition / nLength
  else
    Result := 0;
end;

//==============================================================================
function TCasPlaylist.GetLength : Integer;
var
  nTrackIdx : Integer;
  nMaxSize  : Integer;
  CasTrack  : TCasTrack;
begin
  nMaxSize := 0;

  for nTrackIdx := 0 to m_lstTracks.Count - 1 do
    if m_CasDatabase.GetTrackById(m_lstTracks[nTrackIdx], CasTrack) then
      nMaxSize := Max(CasTrack.Position + CasTrack.Size, nMaxSize);

  Result := nMaxSize;
end;

//==============================================================================
function TCasPlaylist.GetActiveTracks : TList<Integer>;
var
  CasTrack  : TCasTrack;
  nTrackIdx : Integer;
begin
  m_lstActTrks.Clear;

  for nTrackIdx := 0 to m_lstTracks.Count - 1 do
  begin
    if m_CasDatabase.GetTrackById(m_lstTracks.Items[nTrackIdx], CasTrack) then
    begin
      if CasTrack.IsPlaying(m_dPosition) then
        m_lstActTrks.Add(CasTrack.ID);
    end;
  end;

  Result := m_lstActTrks;
end;

//==============================================================================
function TCasPlaylist.GetTrackProgress(a_nTrackId : Integer) : Double;
var
  CasTrack  : TCasTrack;
  nPosition : Integer;
begin
  Result := -1;

  if m_CasDatabase.GetTrackById(a_nTrackId, CasTrack) then
  begin
    nPosition := Trunc(m_dPosition - CasTrack.Position);
  
    if CasTrack.IsPlaying(m_dPosition) then
      Result := nPosition/CasTrack.Size;
  end;
end;

//==============================================================================
procedure TCasPlaylist.AddTrack(a_nID: Integer);
begin
  m_lstTracks.Add(a_nID);
end;

//==============================================================================
procedure TCasPlaylist.RemoveTrack(a_nID: Integer);
begin
  m_lstTracks.Remove(a_nID);
end;

//==============================================================================
procedure TCasPlaylist.ClearTracks;
begin
  m_lstTracks.Clear;
end;

//==============================================================================
procedure TCasPlaylist.GoToTrack(a_nID: Integer);
var
  CasTrack : TCasTrack;
begin
  if m_lstTracks.IndexOf(a_nID) >= 0 then
  begin
    m_CasDatabase.GetTrackById(a_nID, CasTrack);
  
    Position := CasTrack.Position;
  end;
end;


end.

