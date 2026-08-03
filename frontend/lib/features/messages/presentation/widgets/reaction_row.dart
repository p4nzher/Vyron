import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../domain/message.dart';

/// Mesaj balonunun altında beliren tepki "chip"leri. Kullanıcı zaten
/// tepki verdiyse marka gradyanıyla vurgulanır; dokunmak ekler/kaldırır
/// (bkz. `MessagesController.toggleReaction`).
class ReactionRow extends StatelessWidget {
  const ReactionRow({
    required this.reactions,
    required this.currentUserId,
    required this.onToggle,
    required this.onAddPressed,
    super.key,
  });

  final List<GroupedReaction> reactions;
  final String currentUserId;
  final ValueChanged<String> onToggle;
  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    if (reactions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final r in reactions)
            _ReactionChip(
              reaction: r,
              isMine: r.reactedByMe(currentUserId),
              onTap: () => onToggle(r.emoji),
            ),
          _AddReactionChip(onTap: onAddPressed),
        ],
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({required this.reaction, required this.isMine, required this.onTap});

  final GroupedReaction reaction;
  final bool isMine;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AppMotion.fast,
      curve: AppMotion.curve,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isMine ? AppColors.brandGradientStart.withOpacity(0.22) : AppColors.backgroundElevated,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: isMine ? AppColors.brandGradientStart : AppColors.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(reaction.emoji, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text('${reaction.count}', style: AppTextStyles.small),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AddReactionChip extends StatelessWidget {
  const _AddReactionChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.backgroundElevated,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: const Icon(Icons.add_reaction_outlined, size: 15, color: AppColors.textSecondary),
        ),
      ),
    );
  }
}
