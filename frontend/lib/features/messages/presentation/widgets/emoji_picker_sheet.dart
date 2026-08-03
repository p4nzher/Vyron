import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';

/// Hem mesaj input'undaki "emoji ekle" butonu hem de tepki (reaction)
/// seçicisi için paylaşılan alt-sayfa (bottom sheet). `emoji_picker_flutter`
/// varsayılan yapılandırmasını kullanır — sürüm değişiklikleriyle kırılgan
/// olmaması için `Config` bilinçli olarak minimal tutulmuştur.
Future<void> showEmojiPickerSheet(BuildContext context, {required ValueChanged<String> onSelected}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.backgroundSecondary,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return SizedBox(
        height: 320,
        child: EmojiPicker(
          onEmojiSelected: (category, emoji) => onSelected(emoji.emoji),
          config: const Config(),
        ),
      );
    },
  );
}
