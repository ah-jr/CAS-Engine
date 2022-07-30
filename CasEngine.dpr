library CasEngine;

uses
  Asiolist        in 'Asio\AsioList.pas',
  Asio            in 'Asio\Asio.pas',
  CasConstantsU   in 'src\CasConstantsU.pas',
  CasTypesU       in 'src\CasTypesU.pas',
  CasEngineU      in 'src\CasEngineU.pas',
  CasAsioU        in 'src\CasAsioU.pas',
  CasDirectSoundU in 'src\CasDirectSoundU.pas',
  CasDsThreadU    in 'src\CasDsThreadU.pas',
  CasTrackU       in 'src\CasTrackU.pas',
  CasMixerU       in 'src\CasMixerU.pas',
  CasPlaylistU    in 'src\CasPlaylistU.pas',
  CasDecoderU     in 'src\CasDecoderU.pas',
  CasDatabaseU    in 'src\CasDatabaseU.pas',
  CasBasicFxU     in 'src\CasBasicFxU.pas',
  CasUtilsU       in 'src\CasUtilsU.pas',
  CasDLLWrapper   in 'src\CasDLLWrapper.pas';

{$R *.res}

exports
  ce_init,
  ce_free,

  ce_loadDirectSound,
  ce_loadFileIntoTrack,
  ce_addTrackToPlaylist,

  ce_play,
  ce_pause,
  ce_stop,
  ce_changeSpeed,

  ce_isPlaying;

begin
end.
