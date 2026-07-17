import 'package:equatable/equatable.dart';

import 'player_enums.dart';

/// Persisted per-video playback state restored on reopen.
class PlaybackState extends Equatable {
  const PlaybackState({
    this.positionMs = 0,
    this.subtitleUri,
    this.subtitleEnabled = true,
    this.audioTrackId,
    this.speed = 1.0,
    this.aspectMode = AspectRatioMode.fit,
    this.videoScale = 1.0,
    this.subtitleDelaySec = 0,
    this.subtitleFontScale = 1.0,
    this.subtitleColorArgb = 0xFFFFFFFF,
    this.subtitleBackgroundOpacity = 0.5,
    this.subtitleOutline = true,
  });

  final int positionMs;
  final String? subtitleUri;
  final bool subtitleEnabled;
  final String? audioTrackId;
  final double speed;
  final AspectRatioMode aspectMode;
  final double videoScale;
  final double subtitleDelaySec;
  final double subtitleFontScale;
  final int subtitleColorArgb;
  final double subtitleBackgroundOpacity;
  final bool subtitleOutline;

  Map<String, Object?> toJson() => {
        'positionMs': positionMs,
        'subtitleUri': subtitleUri,
        'subtitleEnabled': subtitleEnabled,
        'audioTrackId': audioTrackId,
        'speed': speed,
        'aspectMode': aspectMode.index,
        'videoScale': videoScale,
        'subtitleDelaySec': subtitleDelaySec,
        'subtitleFontScale': subtitleFontScale,
        'subtitleColorArgb': subtitleColorArgb,
        'subtitleBackgroundOpacity': subtitleBackgroundOpacity,
        'subtitleOutline': subtitleOutline,
      };

  factory PlaybackState.fromJson(Map<String, Object?> json) {
    final aspectIndex = json['aspectMode'] as int? ?? 0;
    return PlaybackState(
      positionMs: json['positionMs'] as int? ?? 0,
      subtitleUri: json['subtitleUri'] as String?,
      subtitleEnabled: json['subtitleEnabled'] as bool? ?? true,
      audioTrackId: json['audioTrackId'] as String?,
      speed: (json['speed'] as num?)?.toDouble() ?? 1.0,
      aspectMode: AspectRatioMode
          .values[aspectIndex.clamp(0, AspectRatioMode.values.length - 1)],
      videoScale: (json['videoScale'] as num?)?.toDouble() ?? 1.0,
      subtitleDelaySec: (json['subtitleDelaySec'] as num?)?.toDouble() ?? 0,
      subtitleFontScale: (json['subtitleFontScale'] as num?)?.toDouble() ?? 1.0,
      subtitleColorArgb: json['subtitleColorArgb'] as int? ?? 0xFFFFFFFF,
      subtitleBackgroundOpacity:
          (json['subtitleBackgroundOpacity'] as num?)?.toDouble() ?? 0.5,
      subtitleOutline: json['subtitleOutline'] as bool? ?? true,
    );
  }

  PlaybackState copyWith({
    int? positionMs,
    String? subtitleUri,
    bool? subtitleEnabled,
    String? audioTrackId,
    double? speed,
    AspectRatioMode? aspectMode,
    double? videoScale,
    double? subtitleDelaySec,
    double? subtitleFontScale,
    int? subtitleColorArgb,
    double? subtitleBackgroundOpacity,
    bool? subtitleOutline,
  }) =>
      PlaybackState(
        positionMs: positionMs ?? this.positionMs,
        subtitleUri: subtitleUri ?? this.subtitleUri,
        subtitleEnabled: subtitleEnabled ?? this.subtitleEnabled,
        audioTrackId: audioTrackId ?? this.audioTrackId,
        speed: speed ?? this.speed,
        aspectMode: aspectMode ?? this.aspectMode,
        videoScale: videoScale ?? this.videoScale,
        subtitleDelaySec: subtitleDelaySec ?? this.subtitleDelaySec,
        subtitleFontScale: subtitleFontScale ?? this.subtitleFontScale,
        subtitleColorArgb: subtitleColorArgb ?? this.subtitleColorArgb,
        subtitleBackgroundOpacity:
            subtitleBackgroundOpacity ?? this.subtitleBackgroundOpacity,
        subtitleOutline: subtitleOutline ?? this.subtitleOutline,
      );

  @override
  List<Object?> get props => [positionMs, subtitleUri, speed, aspectMode];
}
