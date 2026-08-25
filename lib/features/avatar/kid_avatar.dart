import 'package:english_app/domain/wallet/wallet.dart';
import 'package:flutter/material.dart';

class KidAvatar extends StatelessWidget {
  const KidAvatar({
    required this.equipped,
    this.onTap,
    super.key,
  });

  final Equipped equipped;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(64),
      onTap: onTap,
      child: SizedBox(
        height: 128,
        width: 128,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              Icons.sentiment_satisfied,
              size: 104,
              color: Theme.of(context).colorScheme.primary,
            ),
            if (equipped.hat != null)
              const Positioned(
                top: 2,
                child: Icon(Icons.forest, size: 34, color: Colors.green),
              ),
            if (equipped.glasses != null)
              const Positioned(
                top: 42,
                child: Icon(Icons.visibility, size: 34, color: Colors.black87),
              ),
            if (equipped.clothes != null)
              const Positioned(
                bottom: 0,
                child: Icon(Icons.checkroom, size: 38, color: Colors.blue),
              ),
          ],
        ),
      ),
    );
  }
}
