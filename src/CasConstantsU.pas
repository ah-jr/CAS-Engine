unit CasConstantsU;

interface

uses
  Winapi.Windows,
  Winapi.Messages;

const

  // Messages:
  CM_ASIO             = WM_User + 100;
  CM_NotifyOwner      = CM_ASIO + 1;
  CM_NotifyDecode     = CM_ASIO + 2;

  // Constants:
  AM_ResetRequest         = 0;
  AM_BufferSwitch         = 1;
  AM_BufferSwitchTimeInfo = 2;
  AM_LatencyChanged       = 3;

  c_nBitDepth       = 24;
  c_nChannelCount   = 2;
  c_nByteSize       = 8;
  c_nBytesInChannel = 3;
  c_nBytesInSample  = 6;

  // Numerical
  FLT_EPS    = 0.000001;
  HOUR_SEC   = 3600;
  MINUTE_SEC = 60;

  c_nDefaultSampleRate = 44100;
  c_nDefaultBufSize    = 3000;

implementation

end.
