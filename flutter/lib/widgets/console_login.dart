// Dialog login console CSMDESK — muncul sebelum koneksi kalau belum login.
// Dipanggil dari connect() gate. UI theme ngikut aplikasi (dark signal green).
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../common.dart';
import '../models/console_auth.dart';

class ConsoleLoginDialog extends StatefulWidget {
  final Function()? onLoginSuccess;
  const ConsoleLoginDialog({super.key, this.onLoginSuccess});

  @override
  State<ConsoleLoginDialog> createState() => _ConsoleLoginDialogState();
}

class _ConsoleLoginDialogState extends State<ConsoleLoginDialog> {
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String _err = '';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _user.text = bind.mainGetLocalOption(key: kOptionConsoleUser);
  }

  void _submit() async {
    setState(() { _busy = true; _err = ''; });
    final r = await consoleLogin(_user.text.trim(), _pass.text);
    setState(() { _busy = false; });
    if (r.ok) {
      if (widget.onLoginSuccess != null) widget.onLoginSuccess!();
      Get.back();
    } else {
      setState(() { _err = r.error ?? 'login gagal'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : Colors.black87;
    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF11161F) : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      title: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: fg, letterSpacing: 1.2),
          children: const [
            TextSpan(text: 'CSMDESK '),
            TextSpan(text: 'LOGIN', style: TextStyle(color: Color(0xFF2BD47D))),
          ],
        ),
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Login konsol teknisi (username internal)', style: TextStyle(fontSize: 12, color: fg.withOpacity(0.6))),
            const SizedBox(height: 14),
            _field(_user, 'Username', false, fg),
            const SizedBox(height: 10),
            _field(_pass, 'Password', true, fg),
            const SizedBox(height: 6),
            if (_err.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(_err, style: const TextStyle(color: Color(0xFFE05252), fontSize: 13)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Get.back(),
          child: Text('Batal', style: TextStyle(color: fg.withOpacity(0.7))),
        ),
        ElevatedButton(
          onPressed: _busy ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2BD47D), foregroundColor: const Color(0xFF06281A)),
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('MASUK'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String hint, bool obscure, Color fg) {
    return TextField(
      controller: c,
      obscureText: obscure,
      autofocus: hint == 'Username',
      style: TextStyle(color: fg),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: fg.withOpacity(0.4)),
        filled: true,
        fillColor: fg.withOpacity(0.05),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: fg.withOpacity(0.2))),
        focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF2BD47D))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
      onSubmitted: (_) => _submit(),
    );
  }
}

/// Gate: panggil sebelum connect(). Returns true kalau boleh lanjut.
/// Belum login -> tampilkan dialog -> tunggu sukses -> lanjut.
Future<bool> requireConsoleLogin(BuildContext context, {Function()? onSuccess}) async {
  final (ok, _, _) = await consoleSessionState();
  if (ok) return true;
  var passed = false;
  await Get.dialog(
    ConsoleLoginDialog(onLoginSuccess: () { passed = true; onSuccess?.call(); }),
    barrierDismissible: false,
  );
  return passed;
}
