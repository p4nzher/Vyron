import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../controllers/friends_providers.dart';

Future<void> showAddFriendSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: const SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: _AddFriendSheet(),
        ),
      ),
    ),
  );
}

class _AddFriendSheet extends ConsumerStatefulWidget {
  const _AddFriendSheet();

  @override
  ConsumerState<_AddFriendSheet> createState() => _AddFriendSheetState();
}

class _AddFriendSheetState extends ConsumerState<_AddFriendSheet> {
  final _tagController = TextEditingController();
  bool _isSending = false;
  String? _errorText;
  String? _successText;

  @override
  void dispose() {
    _tagController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final tag = _tagController.text.trim();
    if (!RegExp(r'^.{3,32}#\d{4}$').hasMatch(tag)) {
      setState(() {
        _errorText = 'Etiket "kullaniciadi#0000" formatında olmalıdır.';
        _successText = null;
      });
      return;
    }
    setState(() {
      _isSending = true;
      _errorText = null;
      _successText = null;
    });
    try {
      await ref.read(friendsRepositoryProvider).sendRequest(tag);
      ref.invalidate(outgoingRequestsProvider);
      ref.invalidate(friendsListProvider);
      setState(() => _successText = 'Arkadaşlık isteği gönderildi.');
      _tagController.clear();
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Arkadaş Ekle', style: AppTextStyles.heading(size: 20)),
          const SizedBox(height: 6),
          Text(
            'Kullanıcının tam etiketini gir — kullanıcı adının yanındaki 4 haneli numara da dahil.',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 20),
          AppTextField(
            label: 'Kullanıcı etiketi',
            controller: _tagController,
            hint: 'enes_dev#0472',
            errorText: _errorText,
            autofocus: true,
            onSubmitted: (_) => _submit(),
          ),
          if (_successText != null) ...[
            const SizedBox(height: 8),
            Text(_successText!, style: AppTextStyles.small.copyWith(color: AppColors.statusOnline)),
          ],
          const SizedBox(height: 20),
          GradientButton(
            label: 'İstek Gönder',
            icon: Icons.person_add_alt_1_rounded,
            isLoading: _isSending,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
