unit CasPlaylistU;

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.Generics.Collections,
  CasDatabaseU,
  CasClipU,
  CasTypesU;

type
  TCasPlaylist = class

  private
    m_dPosition  : Double;
    m_dSpeed     : Double;
    m_dctClips   : TDictionary<Integer, TCasClip>;

    m_CasDatabase : TCasDatabase;

    function GetProgress : Double;
    function GetLength   : Integer;
    function GetPosition : Integer;

    procedure SetPosition(a_nPosition : Integer);

  public
    constructor Create(a_CasDatabase: TCasDatabase);
    destructor  Destroy; override;

    procedure SetClipPos (a_nClipID  : Integer; a_nPos: Integer; a_nStart: Integer = -1; a_nSize: Integer = -1);
    procedure GoToClip   (a_nClipID  : Integer);
    procedure RemoveClip (a_nClipID  : Integer);
    procedure RemoveTrack(a_nTrackID : Integer);
    procedure ClearClips;

    procedure GoToNextClip;
    procedure GoToPrevClip;

    function AddClip(a_nTrackID: Integer; a_nPos: Integer = 0; a_nStart: Integer = 0; a_nSize: Integer = -1) : Integer;

    function GetClip        (a_nClipID  : Integer; var a_nClip : TCasClip) : Boolean;
    function GetClipSize    (a_nClipID  : Integer) : Integer;
    function GetClipProgress(a_nClipID  : Integer) : Double;
    function IsClipPlaying  (a_nClipID  : Integer) : Boolean;
    function IsTrackPlaying (a_nTrackID : Integer) : Boolean;

    function GetTrackList    : TList<Integer>;
    function GetActiveTracks : TList<Integer>;
    function GetActiveClips  : TList<Integer>;
    function GetClipsByTrack (a_nTrackID : Integer) : TList<Integer>;

    property Position    : Integer  read GetPosition   write SetPosition;
    property RelPos      : Double   read m_dPosition   write m_dPosition;
    property Speed       : Double   read m_dSpeed      write m_dSpeed;
    property Progress    : Double   read GetProgress;
    property Length      : Integer  read GetLength;

    property ActiveClips  : TList<Integer> read GetActiveClips;
    property ActiveTracks : TList<Integer> read GetActiveTracks;

  end;

implementation

uses
  Math,
  CasTrackU,
  CasConstantsU;

//==============================================================================
constructor TCasPlaylist.Create(a_CasDatabase: TCasDatabase);
begin
  m_dPosition   := 0;
  m_dSpeed      := 1;
  m_CasDatabase := a_CasDatabase;
  m_dctClips    := TDictionary<Integer, TCasClip>.Create;
end;

//==============================================================================
destructor TCasPlaylist.Destroy;
begin
  m_dctClips.Free;

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
  nMaxSize : Integer;
  Item     : TPair<Integer, TCasClip>;
begin
  nMaxSize := 0;

  for Item in m_dctClips do
    nMaxSize := Max(Item.Value.LastPos, nMaxSize);

  Result := nMaxSize;
end;

//==============================================================================
function TCasPlaylist.IsClipPlaying(a_nClipID : Integer) : Boolean;
var
  Clip : TCasClip;
begin
  Result := False;

  if m_dctClips.TryGetValue(a_nClipID, Clip) then
  begin
    Result := (Clip.Pos     <= m_dPosition) and
              (Clip.LastPos >= m_dPosition);
  end;
end;

//==============================================================================
function TCasPlaylist.IsTrackPlaying(a_nTrackID : Integer) : Boolean;
var
  Clip : TCasClip;
  Item : TPair<Integer, TCasClip>;
begin
  Result := False;

  for Item in m_dctClips do
  begin
    Clip := Item.Value;

    Result := ((Clip.TrackID = a_nTrackID) and
               (Clip.Pos     <= m_dPosition) and
               (Clip.LastPos >= m_dPosition));

    if Result then
      Break;
  end;
end;

//==============================================================================
function TCasPlaylist.GetClip(a_nClipID : Integer; var a_nClip : TCasClip) : Boolean;
begin
  Result := m_dctClips.TryGetValue(a_nClipID, a_nClip);
end;

//==============================================================================
function TCasPlaylist.GetClipSize(a_nClipID : Integer) : Integer;
var
  Clip : TCasClip;
begin
  Result := -1;

  if m_dctClips.TryGetValue(a_nClipID, Clip) then
    Result := Clip.Size;
end;

//==============================================================================
function TCasPlaylist.GetClipProgress(a_nClipID : Integer) : Double;
var
  nPos : Integer;
  Clip : TCasClip;
begin
  Result := -1;

  if m_dctClips.TryGetValue(a_nClipID, Clip) then
  begin
    nPos := Trunc(Position - Clip.Pos);

    if IsClipPlaying(Clip.ID) then
      Result := nPos/(Clip.Size);
  end;
end;

//==============================================================================
function TCasPlaylist.GetTrackList : TList<Integer>;
var
  lstTracks : TList<Integer>;
  Item      : TPair<Integer, TCasClip>;
begin
  lstTracks := TList<Integer>.Create;

  for Item in m_dctClips do
  begin
    if not lstTracks.Contains(Item.Value.TrackID) then
      lstTracks.Add(Item.Value.TrackID);
  end;

  Result := lstTracks;
end;

//==============================================================================
function TCasPlaylist.GetActiveClips : TList<Integer>;
var
  lstClips : TList<Integer>;
  Item     : TPair<Integer, TCasClip>;
begin
  lstClips := TList<Integer>.Create;

  for Item in m_dctClips do
  begin
    if IsClipPlaying(Item.Value.ID) then
      lstClips.Add(Item.Value.ID);
  end;

  Result := lstClips;
end;

//==============================================================================
function TCasPlaylist.GetClipsByTrack(a_nTrackID : Integer) : TList<Integer>;
var
  lstClips : TList<Integer>;
  Item     : TPair<Integer, TCasClip>;
begin
  lstClips := TList<Integer>.Create;

  for Item in m_dctClips do
  begin
    if Item.Value.TrackID = a_nTrackID then
      lstClips.Add(Item.Value.ID);
  end;

  Result := lstClips;
end;

//==============================================================================
function TCasPlaylist.GetActiveTracks : TList<Integer>;
var
  nTrackIdx       : Integer;
  lstTracks       : TList<Integer>;
  lstActiveTracks : TList<Integer>;
begin
  lstTracks       := GetTrackList;
  lstActiveTracks := TList<Integer>.Create;

  for nTrackIdx := 0 to lstTracks.Count - 1 do
  begin
    if IsTrackPlaying(lstTracks[nTrackIdx]) then
      lstActiveTracks.Add((lstTracks[nTrackIdx]));
  end;

  lstTracks.Free;
  Result := lstActiveTracks;
end;

//==============================================================================
function TCasPlaylist.AddClip(a_nTrackID: Integer; a_nPos: Integer; a_nStart: Integer; a_nSize: Integer) : Integer;
var
  CasTrack : TCasTrack;
  Clip     : TCasClip;
begin
  Result := -1;

  if m_CasDatabase.GetTrackById(a_nTrackID, CasTrack) then
  begin
    Clip       := TCasClip.Create(m_CasDatabase.GenerateID, a_nTrackID);
    Clip.Pos   := a_nPos;
    Clip.Start := a_nStart;

    if a_nSize = -1 then
      Clip.Size := CasTrack.Size - a_nStart
    else
      Clip.Size := a_nSize;

    if m_dctClips.TryAdd(Clip.ID, Clip) then
    begin
      Result := Clip.ID;
      CasTrack.AddClip(Clip.ID);
    end;
  end;
end;

//==============================================================================
procedure TCasPlaylist.RemoveClip(a_nClipID: Integer);
var
  CasTrack : TCasTrack;
  Item     : TPair<Integer, TCasClip>;
begin
  for Item in m_dctClips do
  begin
    if Item.Value.ID = a_nClipID then
    begin
      if m_CasDatabase.GetTrackById(Item.Value.TrackID, CasTrack) then
        CasTrack.RemoveClip(Item.Value.ID);

      m_dctClips.Remove(Item.Key);
      Break;
    end;
  end;
end;

//==============================================================================
procedure TCasPlaylist.RemoveTrack(a_nTrackID: Integer);
var
  CasTrack : TCasTrack;
  nKey     : Integer;
  Item     : TPair<Integer, TCasClip>;
  lstRem   : TList<Integer>;
begin
  lstRem := TList<Integer>.Create;

  for Item in m_dctClips do
  begin
    if Item.Value.TrackID = a_nTrackID then
    begin
      lstRem.Add(Item.Key);

      if m_CasDatabase.GetTrackById(Item.Value.TrackID, CasTrack) then
        CasTrack.RemoveClip(Item.Value.ID);
    end;
  end;

  for nKey in lstRem do
    m_dctClips.Remove(nKey);

  lstRem.Free;
end;

//==============================================================================
procedure TCasPlaylist.ClearClips;
var
  CasTrack : TCasTrack;
  Item     : TPair<Integer, TCasClip>;
begin
  for Item in m_dctClips do
  begin
    if m_CasDatabase.GetTrackById(Item.Value.TrackID, CasTrack) then
      CasTrack.RemoveClip(Item.Value.ID);
  end;

  m_dctClips.Clear;
end;

//==============================================================================
procedure TCasPlaylist.SetClipPos(a_nClipID : Integer; a_nPos: Integer; a_nStart: Integer; a_nSize: Integer);
var
  Clip : TCasClip;
begin
  if m_dctClips.TryGetValue(a_nClipID, Clip) then
  begin
    Clip.Pos := a_nPos;

    if a_nStart >= 0 then
      Clip.Start := a_nStart;

    if a_nSize >= 0 then
      Clip.Size := a_nSize
  end;
end;

//==============================================================================
procedure TCasPlaylist.GoToClip(a_nClipID: Integer);
var
  Clip : TCasClip;
begin
  if m_dctClips.TryGetValue(a_nClipID, Clip) then
  begin
    Position := Clip.Pos;
  end;
end;

//==============================================================================
procedure TCasPlaylist.GoToNextClip;
var
  nDiff  : Integer;
  nPos   : Integer;
  nStart : Integer;
  Item   : TPair<Integer, TCasClip>;
begin
  nPos  := 0;
  nDiff := Length;

  for Item in m_dctClips do
  begin
    nStart := Item.Value.Pos;

    if (nStart > Position) and ((nStart - Position) < nDiff) then
    begin
      nDiff := nStart - Position;
      nPos  := nStart;
    end;
  end;

  Position := nPos;
end;

//==============================================================================
procedure TCasPlaylist.GoToPrevClip;
var
  nDiff  : Integer;
  nPos   : Integer;
  nStart : Integer;
  Item   : TPair<Integer, TCasClip>;
begin
  nPos  := 0;
  nDiff := Length;

  for Item in m_dctClips do
  begin
    nStart := Item.Value.Pos;

    if (nStart < Position) and ((Position - nStart) < nDiff) then
    begin
      nDiff := Position - nStart;
      nPos := nStart;
    end;
  end;

  Position := nPos;
end;

end.

