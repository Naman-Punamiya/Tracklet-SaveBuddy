import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeExpenseCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SwipeExpenseCard({
    super.key,
    required this.child,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<SwipeExpenseCard> createState() => _SwipeExpenseCardState();
}

class _SwipeExpenseCardState extends State<SwipeExpenseCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  double maxSlide = 120;
  double openThreshold = 85;
  double offset = 0;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );

    _animation = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    )..addListener(() {
        setState(() {
          offset = _animation.value;
        });
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progress = (offset.abs() / maxSlide).clamp(0.0, 1.0);
    return Stack(
      children: [
        // LEFT (Delete)
        Positioned.fill(
          child: Container(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 16),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withValues(alpha: progress * 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 85,
              height: 65,
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Transform.scale(
                scale: 0.7 + progress * 0.3,
                child: Opacity(
                  opacity: progress,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                      SizedBox(height: 2),
                      Text(
                        "Delete",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        // RIGHT (Edit)
        Positioned.fill(
          child: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF3B82F6).withValues(alpha: progress * 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: 85,
              height: 65,
              decoration: BoxDecoration(
                color: const Color(0xFF3B82F6),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Transform.scale(
                scale: 0.7 + progress * 0.3,
                child: Opacity(
                  opacity: progress,
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.edit_outlined, color: Colors.white, size: 22),
                      SizedBox(height: 2),
                      Text(
                        "Edit",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),

        GestureDetector(
          onHorizontalDragUpdate: (details) {
            setState(() {
              double delta = details.delta.dx;

              if (offset.abs() > 60) {
                delta *= 0.55;
              }
              if (offset.abs() > 90) {
                delta *= 0.40;
              }
              if (offset.abs() > 110) {
                delta *= 0.25;
              }

              offset += delta;

              if (offset > maxSlide) offset = maxSlide;
              if (offset < -maxSlide) offset = -maxSlide;
            });
          },
          onHorizontalDragEnd: (_) {
            if (offset >= openThreshold) {
              HapticFeedback.mediumImpact();
              widget.onDelete();
              animateTo(0);
              return;
            }

            if (offset <= -openThreshold) {
              HapticFeedback.mediumImpact();
              widget.onEdit();
              animateTo(0);
              return;
            }

            animateTo(0);
          },
          child: Transform.translate(
            offset: Offset(offset, 0),
            child: Transform.scale(
              scale: offset == 0 ? 1.0 : 0.985,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(
                        0,
                        0,
                        0,
                        offset == 0 ? 0.05 : 0.15,
                      ),
                      blurRadius: offset == 0 ? 8 : 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: widget.child,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> animateTo(double value) async {
    _animation = Tween<double>(begin: offset, end: value).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    )..addListener(() {
        setState(() {
          offset = _animation.value;
        });
      });

    await _controller.forward(from: 0);
  }
}
