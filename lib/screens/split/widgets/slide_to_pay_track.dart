import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// CheQ-style interactive "Slide to Pay" draggable track.
class SlideToPayTrack extends StatefulWidget {
  final double amount;
  final String label;
  final Future<void> Function() onPayCompleted;

  const SlideToPayTrack({
    super.key,
    required this.amount,
    this.label = 'Slide to Mark as Paid',
    required this.onPayCompleted,
  });

  @override
  State<SlideToPayTrack> createState() => _SlideToPayTrackState();
}

class _SlideToPayTrackState extends State<SlideToPayTrack> {
  double _dragPosition = 0.0;
  bool _isCompleted = false;
  bool _isProcessing = false;

  static const _primaryGreen = Color(0xFF00B865);
  static const _deepGreen = Color(0xFF008A4B);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const knobSize = 44.0;
        final maxDistance = constraints.maxWidth - knobSize - 8.0;

        return Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF0FBF6),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFF6EE7B7), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              // 1. Sliding progress background
              Container(
                width: _dragPosition + (knobSize / 2),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF6EE7B7), _primaryGreen],
                  ),
                  borderRadius: BorderRadius.circular(26),
                ),
              ),

              // 2. Center Prompt Text (fades as slider moves)
              if (!_isCompleted)
                Positioned.fill(
                  child: Opacity(
                    opacity: (1.0 - (_dragPosition / (maxDistance > 0 ? maxDistance * 0.75 : 1.0))).clamp(0.0, 1.0),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 24),
                          Text(
                            '${widget.label} • ₹${widget.amount.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Color(0xFF065F46),
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF059669)),
                          const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF34D399)),
                        ],
                      ),
                    ),
                  ),
                ),

              // 3. Success state banner
              if (_isCompleted)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      color: _primaryGreen,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    child: const Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 6),
                          Text(
                            'Payment Marked as Settled!',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // 4. Draggable Knob
              if (!_isCompleted)
                Positioned(
                  left: 4 + _dragPosition,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_isProcessing || _isCompleted) return;
                      setState(() {
                        _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDistance);
                      });
                    },
                    onHorizontalDragEnd: (details) async {
                      if (_isProcessing || _isCompleted) return;
                      if (_dragPosition >= maxDistance * 0.75) {
                        // Successfully dragged
                        HapticFeedback.mediumImpact();
                        setState(() {
                          _dragPosition = maxDistance;
                          _isProcessing = true;
                          _isCompleted = true;
                        });
                        try {
                          await widget.onPayCompleted();
                        } catch (_) {
                          if (mounted) {
                            setState(() {
                              _isCompleted = false;
                              _isProcessing = false;
                              _dragPosition = 0;
                            });
                          }
                        }
                      } else {
                        // Snap back
                        setState(() {
                          _dragPosition = 0;
                        });
                      }
                    },
                    child: Container(
                      width: knobSize,
                      height: knobSize,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF34D399), _primaryGreen, _deepGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryGreen.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
