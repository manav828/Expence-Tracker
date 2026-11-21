import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// CheQ-style interactive "Slide to Pay" draggable track with
/// continuous speed animation, perfectly rounded stadium pill shape,
/// centered prompt text, and smooth spring-back physics.
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

class _SlideToPayTrackState extends State<SlideToPayTrack>
    with TickerProviderStateMixin {
  double _dragPosition = 0.0;
  bool _isCompleted = false;
  bool _isProcessing = false;

  // Controllers
  late final AnimationController _speedController;
  late final AnimationController _snapBackController;
  late Animation<double> _snapBackAnimation;

  static const _trackHeight = 54.0;
  static const _knobSize = 46.0;
  static const _padding = 4.0;
  static const _pillRadius = _trackHeight / 2; // 27.0 for perfect round stadium

  static const _primaryGreen = Color(0xFF00B865);
  static const _deepGreen = Color(0xFF008A4B);
  static const _emeraldDark = Color(0xFF065F46);

  @override
  void initState() {
    super.initState();

    // 1. Continuous high-speed sweep animation (left to right)
    _speedController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    // 2. Smooth spring snap-back controller
    _snapBackController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
  }

  @override
  void dispose() {
    _speedController.dispose();
    _snapBackController.dispose();
    super.dispose();
  }

  void _snapBackToZero(double fromPosition) {
    _snapBackAnimation = Tween<double>(begin: fromPosition, end: 0.0).animate(
      CurvedAnimation(parent: _snapBackController, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          _dragPosition = _snapBackAnimation.value;
        });
      });
    _snapBackController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: _trackHeight,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalWidth = constraints.maxWidth;
          final maxDistance = math.max(0.0, totalWidth - _knobSize - (_padding * 2));
          final progress = maxDistance > 0 ? (_dragPosition / maxDistance).clamp(0.0, 1.0) : 0.0;

          // Text stays 100% visible past 50-60%, only fading as knob reaches final 70%-95%
          final textOpacity = progress < 0.65
              ? 1.0
              : (1.0 - ((progress - 0.65) / 0.28)).clamp(0.0, 1.0);

          return Container(
            width: double.infinity,
            height: _trackHeight,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(_pillRadius),
              border: Border.all(color: const Color(0xFF6EE7B7), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00B865).withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.centerLeft,
              children: [
                // 1. Sliding progress fill behind knob
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: _dragPosition + _knobSize + _padding,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF34D399), _primaryGreen, _deepGreen],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(_pillRadius),
                    ),
                  ),
                ),

                // 2. High-speed shimmer sweep layer (continuous left -> right light streak)
                if (!_isCompleted)
                  Positioned.fill(
                    child: AnimatedBuilder(
                      animation: _speedController,
                      builder: (context, _) {
                        final animValue = _speedController.value;
                        // Sweep from -0.3 to 1.3 across the track
                        final startX = (animValue * 1.6) - 0.3;
                        return Opacity(
                          opacity: (1.0 - progress).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(_pillRadius),
                              gradient: LinearGradient(
                                begin: Alignment(startX * 2 - 1.0, 0),
                                end: Alignment((startX + 0.35) * 2 - 1.0, 0),
                                colors: [
                                  Colors.white.withValues(alpha: 0.0),
                                  Colors.white.withValues(alpha: 0.45),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // 3. Centered Placeholder Text & Animated Speed Chevrons
                if (!_isCompleted)
                  Positioned.fill(
                    child: Opacity(
                      opacity: textOpacity,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  '${widget.label} • ₹${widget.amount.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                    color: _emeraldDark,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                    letterSpacing: -0.2,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),

                              // Animated speed chevrons (sequential wave pulse in high speed)
                              AnimatedBuilder(
                                animation: _speedController,
                                builder: (context, _) {
                                  final val = _speedController.value;
                                  return Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: List.generate(3, (index) {
                                      // Stagger each chevron by 0.18 phase
                                      final phase = (val - (index * 0.18)) % 1.0;
                                      final chevronOpacity = 0.25 + (0.75 * math.sin(phase * math.pi).clamp(0.0, 1.0));
                                      final chevronShift = (1.0 - chevronOpacity) * 2.0;

                                      return Transform.translate(
                                        offset: Offset(chevronShift, 0),
                                        child: Opacity(
                                          opacity: chevronOpacity,
                                          child: const Icon(
                                            Icons.chevron_right_rounded,
                                            size: 16,
                                            color: _primaryGreen,
                                          ),
                                        ),
                                      );
                                    }),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                // 4. Draggable Knob (Circular thumb with forward arrow, turns into checkmark on complete)
                Positioned(
                  left: _padding + _dragPosition,
                  top: (_trackHeight - _knobSize) / 2, // Exactly 4.0 to center vertically
                  child: GestureDetector(
                    onHorizontalDragStart: (_) {
                      if (_isProcessing || _isCompleted) return;
                      _snapBackController.stop();
                    },
                    onHorizontalDragUpdate: (details) {
                      if (_isProcessing || _isCompleted) return;
                      setState(() {
                        _dragPosition = (_dragPosition + details.delta.dx).clamp(0.0, maxDistance);
                      });
                    },
                    onHorizontalDragEnd: (details) async {
                      if (_isProcessing || _isCompleted) return;
                      if (_dragPosition >= maxDistance * 0.75) {
                        // Trigger payment confirmation
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
                        // Spring snap back smoothly to starting position
                        _snapBackToZero(_dragPosition);
                      }
                    },
                    child: Container(
                      width: _knobSize,
                      height: _knobSize,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF34D399), _primaryGreen, _deepGreen],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: Colors.white, width: 2.0),
                        boxShadow: [
                          BoxShadow(
                            color: _primaryGreen.withValues(alpha: 0.45),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(1, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isProcessing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Icon(
                                _isCompleted ? Icons.check_rounded : Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
