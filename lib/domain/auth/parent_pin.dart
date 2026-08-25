import 'dart:convert';

import 'package:crypto/crypto.dart';

bool isSixDigitPin(String pin) => RegExp(r'^\d{6}$').hasMatch(pin);

String hashParentPin({required String uid, required String pin}) {
  return sha256.convert(utf8.encode('$uid$pin')).toString();
}

bool verifyParentPin({
  required String uid,
  required String pin,
  required String hash,
}) {
  return hashParentPin(uid: uid, pin: pin) == hash;
}

class PinTryResult {
  const PinTryResult({required this.ok, this.errorKey});

  final bool ok;
  final String? errorKey;
}

class PinGate {
  int _failures = 0;
  DateTime? _lockedUntil;

  PinTryResult tryPin({
    required String uid,
    required String pin,
    required String hash,
    required DateTime now,
  }) {
    if (_lockedUntil != null && now.isBefore(_lockedUntil!)) {
      return const PinTryResult(ok: false, errorKey: 'locked');
    }

    if (_lockedUntil != null && !now.isBefore(_lockedUntil!)) {
      _failures = 0;
      _lockedUntil = null;
    }

    if (verifyParentPin(uid: uid, pin: pin, hash: hash)) {
      _failures = 0;
      return const PinTryResult(ok: true);
    }

    _failures += 1;
    if (_failures >= 5) {
      _lockedUntil = now.add(const Duration(minutes: 1));
    }

    return const PinTryResult(ok: false, errorKey: 'wrong');
  }
}
