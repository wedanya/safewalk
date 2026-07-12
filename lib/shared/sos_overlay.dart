import 'dart:async';
import 'package:flutter/material.dart';
import 'sos_service.dart';

class SosOverlay {
  static void show(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _SosDialog(),
    );
  }
}

class _SosDialog extends StatefulWidget {
  const _SosDialog();
  @override State<_SosDialog> createState() => _SosDialogState();
}

class _SosDialogState extends State<_SosDialog> {
  int _countdown = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _countdown--);
      if (_countdown <= 0) {
        _timer?.cancel();
        Navigator.of(context, rootNavigator: true).pop();
        SosService.instance.callNearestContact(context);
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(children: [
        Icon(Icons.sos_rounded, color: Colors.red, size: 30),
        SizedBox(width: 10),
        Text('SOS!', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 22)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('Calling emergency contact in $_countdown seconds...',
            style: const TextStyle(color: Colors.white70, fontSize: 15)),
        const SizedBox(height: 14),
        LinearProgressIndicator(
          value: _countdown / 5,
          color: Colors.red,
          backgroundColor: Colors.white12,
          borderRadius: BorderRadius.circular(4),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey, fontSize: 15)),
        ),
        ElevatedButton(
          onPressed: () {
            _timer?.cancel();
            Navigator.of(context, rootNavigator: true).pop();
            SosService.instance.callNearestContact(context);
          },
          style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Call Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }
}