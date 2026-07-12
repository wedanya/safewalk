import 'package:flutter/material.dart';

/// Drop this widget anywhere at the top of a page body to show
/// connectivity status and last-sync time automatically.
///
/// Usage:
///   Column(children: [
///     OfflineBanner(isOnline: _isOnline, lastSynced: _lastSynced, pendingCount: _pendingCount),
///     Expanded(child: ...rest of page...),
///   ])
class OfflineBanner extends StatelessWidget {
  final bool isOnline;
  final String lastSynced;
  final int pendingCount;
  final VoidCallback? onRetry;

  const OfflineBanner({
    super.key,
    required this.isOnline,
    this.lastSynced = '',
    this.pendingCount = 0,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    if (isOnline && pendingCount == 0) return const SizedBox.shrink();

    if (!isOnline) {
      return _buildBanner(
        color: const Color(0xFF2D2D2D),
        icon: Icons.wifi_off_rounded,
        iconColor: Colors.white70,
        message: "You're offline",
        sub: lastSynced.isNotEmpty ? "Showing cached data from $lastSynced" : "No cached data available",
        trailing: onRetry != null
            ? GestureDetector(
                onTap: onRetry,
                child: const Text("Retry", style: TextStyle(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold)),
              )
            : null,
      );
    }

    // Online but has pending reports waiting to sync
    return _buildBanner(
      color: const Color(0xFFFFF3CD),
      icon: Icons.sync_rounded,
      iconColor: Colors.orange,
      message: "$pendingCount report${pendingCount > 1 ? 's' : ''} pending upload",
      sub: "Will sync automatically when connected",
      trailing: onRetry != null
          ? GestureDetector(
              onTap: onRetry,
              child: const Text("Sync Now", style: TextStyle(color: Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
            )
          : null,
    );
  }

  Widget _buildBanner({
    required Color color,
    required IconData icon,
    required Color iconColor,
    required String message,
    required String sub,
    Widget? trailing,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: color,
      child: Row(children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message,
                style: TextStyle(color: color == const Color(0xFF2D2D2D) ? Colors.white : Colors.brown.shade800,
                    fontWeight: FontWeight.bold, fontSize: 12)),
            if (sub.isNotEmpty)
              Text(sub,
                  style: TextStyle(color: color == const Color(0xFF2D2D2D) ? Colors.white60 : Colors.brown.shade600,
                      fontSize: 11)),
          ]),
        ),
        ?trailing,
      ]),
    );
  }
}