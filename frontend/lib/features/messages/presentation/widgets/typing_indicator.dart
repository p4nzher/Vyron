import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Kanalın/DM'in altında beliren "... yazıyor" göstergesi. Socket'ten gelen
/// `typing:start`/`typing:stop` olaylarıyla beslenir (bkz.
/// `MessagesController.typingUsernames`).
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({required this.usernames, super.key});

  final Set<String> usernames;

  @override
  Widget build(BuildContext context) {
    if (usernames.isEmpty) return const SizedBox.shrink();

    final text = switch (usernames.length) {
      1 => '${usernames.first} yazıyor…',
      2 => '${usernames.join(' ve ')} yazıyor…',
      _ => '${usernames.length} kişi yazıyor…',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _TypingDots(),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.small,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = (_controller.value + (i * 0.2)) % 1.0;
            final scale = 0.5 + (0.5 * (phase < 0.5 ? phase * 2 : (1 - phase) * 2));
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(color: AppColors.brandAccent, shape: BoxShape.circle),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
