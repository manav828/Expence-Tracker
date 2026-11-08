import 'package:flutter/material.dart';

/// High-end executive shimmer skeleton screen for Dashboard.
/// Prevents flashing empty / 0-data states during cold start or initial cloud sync.
class DashboardShimmer extends StatefulWidget {
  const DashboardShimmer({super.key});

  @override
  State<DashboardShimmer> createState() => _DashboardShimmerState();
}

class _DashboardShimmerState extends State<DashboardShimmer> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // 1. Executive Header & Greeting Row
            _buildGreetingRowSkeleton(),
            const SizedBox(height: 16),

            // 2. Cash Flow / Outflow Card Skeleton
            _buildCashFlowCardSkeleton(),
            const SizedBox(height: 16),

            // 3. Category Allocation Donut Skeleton
            _buildCategoryDonutSkeleton(),
            const SizedBox(height: 20),

            // 4. Trajectory Card Skeleton
            _buildTrajectorySkeleton(),
            const SizedBox(height: 20),

            // 5. Recent Verified Ledger Skeleton
            _buildLedgerSkeleton(),
          ],
        );
      },
    );
  }

  Widget _shimmerBox({
    required double width,
    required double height,
    double borderRadius = 8,
    BoxShape shape = BoxShape.rectangle,
  }) {
    final gradient = LinearGradient(
      begin: Alignment(-2.0 + 4.0 * _controller.value, 0.0),
      end: Alignment(-1.0 + 4.0 * _controller.value, 0.0),
      colors: const [
        Color(0xFFEFF1F5),
        Color(0xFFFAFAFC),
        Color(0xFFEFF1F5),
      ],
      stops: const [0.0, 0.5, 1.0],
    );

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? BorderRadius.circular(borderRadius) : null,
        gradient: gradient,
      ),
    );
  }

  Widget _buildGreetingRowSkeleton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _shimmerBox(width: 170, height: 26, borderRadius: 12),
        _shimmerBox(width: 95, height: 24, borderRadius: 20),
      ],
    );
  }

  Widget _buildCashFlowCardSkeleton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x0A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _shimmerBox(width: 32, height: 32, shape: BoxShape.circle),
                  const SizedBox(width: 10),
                  _shimmerBox(width: 140, height: 16, borderRadius: 6),
                ],
              ),
              _shimmerBox(width: 70, height: 24, borderRadius: 12),
            ],
          ),
          const SizedBox(height: 18),
          _shimmerBox(width: 90, height: 12, borderRadius: 4),
          const SizedBox(height: 8),
          _shimmerBox(width: 150, height: 32, borderRadius: 8),
          const SizedBox(height: 10),
          _shimmerBox(width: 210, height: 11, borderRadius: 4),
        ],
      ),
    );
  }

  Widget _buildCategoryDonutSkeleton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x0A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _shimmerBox(width: 20, height: 20, borderRadius: 4),
                  const SizedBox(width: 8),
                  _shimmerBox(width: 130, height: 16, borderRadius: 6),
                ],
              ),
              _shimmerBox(width: 60, height: 20, borderRadius: 10),
            ],
          ),
          const SizedBox(height: 24),
          Center(
            child: SizedBox(
              width: 140,
              height: 140,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  _shimmerBox(width: 140, height: 140, shape: BoxShape.circle),
                  Container(
                    width: 90,
                    height: 90,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  _shimmerBox(width: 50, height: 14, borderRadius: 4),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _shimmerBox(width: 75, height: 22, borderRadius: 8),
              const SizedBox(width: 8),
              _shimmerBox(width: 85, height: 22, borderRadius: 8),
              const SizedBox(width: 8),
              _shimmerBox(width: 70, height: 22, borderRadius: 8),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrajectorySkeleton() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0x0A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _shimmerBox(width: 150, height: 16, borderRadius: 6),
              _shimmerBox(width: 65, height: 20, borderRadius: 10),
            ],
          ),
          const SizedBox(height: 16),
          _shimmerBox(width: double.infinity, height: 120, borderRadius: 14),
        ],
      ),
    );
  }

  Widget _buildLedgerSkeleton() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _shimmerBox(width: 140, height: 16, borderRadius: 6),
            _shimmerBox(width: 50, height: 14, borderRadius: 4),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(3, (i) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x0A000000)),
            ),
            child: Row(
              children: [
                _shimmerBox(width: 42, height: 42, shape: BoxShape.circle),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmerBox(width: 110, height: 14, borderRadius: 4),
                      const SizedBox(height: 6),
                      _shimmerBox(width: 80, height: 10, borderRadius: 3),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _shimmerBox(width: 60, height: 14, borderRadius: 4),
                    const SizedBox(height: 4),
                    _shimmerBox(width: 45, height: 12, borderRadius: 4),
                  ],
                ),
              ],
            ),
          ),
        )),
      ],
    );
  }
}
