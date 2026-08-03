import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/glass_container.dart';
import '../../../../core/widgets/gradient_button.dart';
import '../controllers/servers_providers.dart';

/// Rayın "+" butonuna basıldığında açılan sayfa — "Sunucu Oluştur" ve
/// "Davetle Katıl" arasında basit bir sekme geçişi. Backend her iki akışı da
/// (`POST /servers`, `POST /invites/:code/join`) doğrudan destekler.
Future<void> showCreateOrJoinServerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const _CreateOrJoinServerSheet(),
  );
}

class _CreateOrJoinServerSheet extends StatefulWidget {
  const _CreateOrJoinServerSheet();

  @override
  State<_CreateOrJoinServerSheet> createState() => _CreateOrJoinServerSheetState();
}

class _CreateOrJoinServerSheetState extends State<_CreateOrJoinServerSheet> {
  bool _showJoin = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: GlassContainer(
            padding: const EdgeInsets.all(20),
            child: _showJoin
                ? _JoinServerForm(onBack: () => setState(() => _showJoin = false))
                : _CreateServerForm(onWantsJoin: () => setState(() => _showJoin = true)),
          ),
        ),
      ),
    );
  }
}

class _CreateServerForm extends ConsumerStatefulWidget {
  const _CreateServerForm({required this.onWantsJoin});
  final VoidCallback onWantsJoin;

  @override
  ConsumerState<_CreateServerForm> createState() => _CreateServerFormState();
}

class _CreateServerFormState extends ConsumerState<_CreateServerForm> {
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    if (name.length < 2) {
      setState(() => _errorText = 'Sunucu adı en az 2 karakter olmalıdır.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final server = await ref.read(serversRepositoryProvider).create(
            name: name,
            description: _descriptionController.text.trim(),
          );
      ref.invalidate(serverListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go(AppRoutes.serverPath(server.id));
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Sunucunu oluştur', style: AppTextStyles.heading(size: 20)),
        const SizedBox(height: 6),
        Text(
          'Sunucun kendi @everyone rolü ve varsayılan metin/sesli kanallarıyla hazır gelir.',
          style: AppTextStyles.caption,
        ),
        const SizedBox(height: 20),
        AppTextField(
          label: 'Sunucu adı',
          controller: _nameController,
          hint: 'Örn. Vyron Topluluğu',
          errorText: _errorText,
          autofocus: true,
          maxLength: 100,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: 'Açıklama (opsiyonel)',
          controller: _descriptionController,
          hint: 'Bu sunucu ne hakkında?',
          maxLines: 2,
          maxLength: 300,
        ),
        const SizedBox(height: 20),
        GradientButton(label: 'Sunucu Oluştur', icon: Icons.add_rounded, isLoading: _isLoading, onPressed: _submit),
        const SizedBox(height: 12),
        TextButton(
          onPressed: widget.onWantsJoin,
          child: Text('Zaten bir davetin mi var? Katıl', style: AppTextStyles.bodyMedium),
        ),
      ],
    );
  }
}

class _JoinServerForm extends ConsumerStatefulWidget {
  const _JoinServerForm({required this.onBack});
  final VoidCallback onBack;

  @override
  ConsumerState<_JoinServerForm> createState() => _JoinServerFormState();
}

class _JoinServerFormState extends ConsumerState<_JoinServerForm> {
  final _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _errorText = 'Davet kodu veya linki gerekli.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      // Kullanıcı tam link yapıştırmış olabilir (`https://vyron.app/invite/XXXX`)
      // — sondaki segmenti kod olarak alıyoruz.
      final normalized = code.split('/').where((s) => s.isNotEmpty).last;
      final server = await ref.read(invitesRepositoryProvider).join(normalized);
      ref.invalidate(serverListProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      context.go(AppRoutes.serverPath(server.id));
    } on ApiException catch (e) {
      setState(() => _errorText = e.message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textSecondary),
            ),
            Text('Davetle katıl', style: AppTextStyles.heading(size: 20)),
          ],
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text('Bir davet linki veya kodu gir.', style: AppTextStyles.caption),
        ),
        const SizedBox(height: 20),
        AppTextField(
          label: 'Davet linki / kodu',
          controller: _codeController,
          hint: 'https://vyron.app/invite/AB12CD34',
          errorText: _errorText,
          autofocus: true,
        ),
        const SizedBox(height: 20),
        GradientButton(label: 'Katıl', icon: Icons.login_rounded, isLoading: _isLoading, onPressed: _submit),
      ],
    );
  }
}
