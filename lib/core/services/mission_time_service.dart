// lib/core/services/mission_time_service.dart — Mission Time: time_delta a partire dal t0 del gruppo
/// L'ora locale dei dispositivi non e allineata e non va usata: ogni messaggio
/// porta i secondi trascorsi dal `t0` del gruppo, che arriva dal QR.
class MissionTimeService {
  final int t0;

  const MissionTimeService({required this.t0});

  /// Secondi trascorsi dal tempo zero del gruppo.
  int currentTimeDelta() =>
      (DateTime.now().millisecondsSinceEpoch ~/ 1000) - t0;

  /// Unica implementazione del formato `T+HH:MM:SS`, usata anche da
  /// `ChatMessage.formattedTime`. Le ore non sono in modulo 24: un volo lungo
  /// mostra `T+26:10:00`, non riparte da zero.
  static String formatDelta(int delta) {
    // Un delta negativo significa orologio del dispositivo indietro rispetto
    // al t0: si mostra il tempo zero invece di un valore assurdo.
    final safe = delta < 0 ? 0 : delta;
    final duration = Duration(seconds: safe);
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return 'T+$hours:$minutes:$seconds';
  }
}
