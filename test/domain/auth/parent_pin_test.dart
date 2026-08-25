import 'package:english_app/domain/auth/parent_pin.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hash is not the raw pin', () {
    final h = hashParentPin(uid: 'u1', pin: '123456');
    expect(h, isNot('123456'));
    expect(verifyParentPin(uid: 'u1', pin: '123456', hash: h), isTrue);
    expect(verifyParentPin(uid: 'u1', pin: '000000', hash: h), isFalse);
  });

  test('same pin different uid does not verify', () {
    final h = hashParentPin(uid: 'u1', pin: '123456');
    expect(verifyParentPin(uid: 'u2', pin: '123456', hash: h), isFalse);
  });

  test('isSixDigitPin', () {
    expect(isSixDigitPin('123456'), isTrue);
    expect(isSixDigitPin('12345'), isFalse);
    expect(isSixDigitPin('12345a'), isFalse);
  });

  test('five wrong tries lock for 60 seconds', () {
    final hash = hashParentPin(uid: 'u1', pin: '123456');
    final gate = PinGate();
    final t0 = DateTime.utc(2026, 8, 25, 12);

    for (var i = 0; i < 5; i++) {
      gate.tryPin(uid: 'u1', pin: '000000', hash: hash, now: t0);
    }

    final locked = gate.tryPin(
      uid: 'u1',
      pin: '123456',
      hash: hash,
      now: t0.add(const Duration(seconds: 30)),
    );
    expect(locked.ok, isFalse);
    expect(locked.errorKey, 'locked');

    final after = gate.tryPin(
      uid: 'u1',
      pin: '123456',
      hash: hash,
      now: t0.add(const Duration(seconds: 61)),
    );
    expect(after.ok, isTrue);
  });
}
