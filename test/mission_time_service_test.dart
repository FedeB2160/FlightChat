import 'package:flight_chat/core/services/mission_time_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MissionTimeService', () {
    test('currentTimeDelta counts seconds from t0', () {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final service = MissionTimeService(t0: nowSeconds - 100);
      // Tolleranza di un secondo: il test può attraversare un tick.
      expect(service.currentTimeDelta(), inInclusiveRange(100, 101));
    });

    test('currentTimeDelta is zero at the mission start', () {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      expect(
        MissionTimeService(t0: nowSeconds).currentTimeDelta(),
        inInclusiveRange(0, 1),
      );
    });

    test('formatDelta renders T+HH:MM:SS', () {
      expect(MissionTimeService.formatDelta(0), 'T+00:00:00');
      expect(MissionTimeService.formatDelta(59), 'T+00:00:59');
      expect(MissionTimeService.formatDelta(60), 'T+00:01:00');
      expect(MissionTimeService.formatDelta(3600), 'T+01:00:00');
      expect(MissionTimeService.formatDelta(3661), 'T+01:01:01');
    });

    test('hours are not wrapped at 24', () {
      // Un volo lungo mostra T+25:01:01, non riparte da zero.
      expect(MissionTimeService.formatDelta(90061), 'T+25:01:01');
    });

    test('a negative delta clamps to the mission start', () {
      // Orologio del dispositivo indietro rispetto al t0 del gruppo.
      expect(MissionTimeService.formatDelta(-1), 'T+00:00:00');
      expect(MissionTimeService.formatDelta(-9999), 'T+00:00:00');
    });
  });
}
