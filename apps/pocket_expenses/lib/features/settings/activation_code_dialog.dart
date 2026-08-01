import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/subscription_provider.dart';

Future<void> showActivationCodeDialog(BuildContext context, WidgetRef ref) {
  final controller = TextEditingController();
  bool isLoading = false;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Código de Ativação'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'Código',
            prefixIcon: Icon(Icons.vpn_key),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: isLoading
                ? null
                : () async {
                    setState(() => isLoading = true);
                    final message = await ref
                        .read(subscriptionActionsProvider)
                        .redeem(controller.text);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor:
                              message == 'Premium ativado com sucesso!'
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      );
                    }
                  },
            child: isLoading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Ativar'),
          ),
        ],
      ),
    ),
  );
}
