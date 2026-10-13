import 'dart:async';
import 'package:flutter/material.dart';
import '../core/premium_status.dart';

class PremiumBadge extends StatefulWidget {
  final bool premium;
  final bool diamond;
  final String? until;
  final String? diamondUntil;
  final bool compact;
  final DateTime Function()? clock;

  const PremiumBadge({
    super.key,
    required this.premium,
    this.diamond = false,
    this.until,
    this.diamondUntil,
    this.compact = false,
    this.clock,
  });

  @override
  State<PremiumBadge> createState() => _PremiumBadgeState();
}

class _PremiumBadgeState extends State<PremiumBadge>
    with WidgetsBindingObserver {
  Timer? _expiry;
  DateTime get _now => widget.clock?.call() ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _expiry?.cancel();
    final now = _now;
    final dates =
        [widget.until, widget.diamondUntil]
            .map((date) => DateTime.tryParse(date ?? ''))
            .whereType<DateTime>()
            .where((date) => date.isAfter(now))
            .toList()
          ..sort();
    if (dates.isNotEmpty) {
      final remaining = dates.first.difference(now);
      final delay = remaining > const Duration(days: 1)
          ? const Duration(days: 1)
          : remaining;
      _expiry = Timer(delay, () {
        if (mounted) {
          setState(() {});
          _schedule();
        }
      });
    }
  }

  @override
  void didUpdateWidget(PremiumBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() {});
      _schedule();
    }
  }

  @override
  void dispose() {
    _expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = _now;
    if (!PremiumStatus.active(widget.premium, widget.until, now)) {
      return const SizedBox.shrink();
    }
    final diamond = PremiumStatus.active(
      widget.diamond,
      widget.diamondUntil ?? widget.until,
      now,
    );
    return Semantics(
      label: diamond ? 'Diamond premium member' : 'Premium member',
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.compact ? 6 : 10,
          vertical: widget.compact ? 3 : 5,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF087CF5), Color(0xFF0659B3)],
          ),
          borderRadius: BorderRadius.circular(widget.compact ? 4 : 20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              diamond ? Icons.diamond_rounded : Icons.workspace_premium_rounded,
              size: widget.compact ? 10 : 13,
              color: Colors.white,
            ),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                diamond ? 'DIAMOND' : 'PREMIUM',
                maxLines: 1,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: widget.compact ? 8 : 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
