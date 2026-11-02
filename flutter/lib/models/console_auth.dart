// CSMDESK console auth untuk client desktop.
// Simpan kredensial di LocalOption (config RustDesk lokal), verifikasi ke
// console via HTTP sebelum koneksi diizinkan. Fallback offline: kredensial
// terakhir yang sukses diverifikasi di-cache (dengan timestamp) supaya
// teknisi tetap bisa kerja kalau console sedang down — max 7 hari.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_hbb/models/platform_model.dart';

const String kOptionConsoleServer = "csmdesk-console-server";
const String kOptionConsoleUser = "csmdesk-console-user";
const String kOptionConsoleToken = "csmdesk-console-token";
const String kOptionConsoleTokenTime = "csmdesk-console-token-time";
const String kOptionConsoleRole = "csmdesk-console-role";
const String kOptionConsoleFullName = "csmdesk-console-full-name";

// Fallback cache max age (jam). Setelah lewat, wajib online lagi.
const int kTokenMaxAgeHours = 7 * 24;

String consoleServer() {
  // default: server yang sama dgn rendezvous, port console
  final custom = bind.mainGetLocalOption(key: kOptionConsoleServer);
  if (custom.isNotEmpty) return custom;
  final hbbs = bind.mainGetOption(key: 'custom-rendezvous-server');
  if (hbbs.isNotEmpty) return 'http://$hbbs:21120';
  return 'http://10.34.0.38:21120';
}

class ConsoleAuthResult {
  final bool ok;
  final String? error;
  final Map<String, dynamic>? user;
  ConsoleAuthResult(this.ok, {this.error, this.user});
}

Future<ConsoleAuthResult> consoleLogin(String username, String password) async {
  final server = consoleServer();
  try {
    final req = await HttpClient().postUrl(Uri.parse('$server/api/client-auth/login'));
    req.headers.contentType = ContentType.json;
    req.add(utf8.encode(jsonEncode({'username': username, 'password': password})));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (res.statusCode == 200 && data['ok'] == true) {
      final token = data['token'] as String;
      final role = data['role'] as String;
      // verify + ambil profile
      final prof = await _verify(token);
      if (prof == null) {
        return ConsoleAuthResult(false, error: 'verifikasi token gagal');
      }
      await bind.mainSetLocalOption(key: kOptionConsoleUser, value: username);
      await bind.mainSetLocalOption(key: kOptionConsoleToken, value: token);
      await bind.mainSetLocalOption(
          key: kOptionConsoleTokenTime,
          value: DateTime.now().millisecondsSinceEpoch.toString());
      await bind.mainSetLocalOption(key: kOptionConsoleRole, value: role);
      await bind.mainSetLocalOption(
          key: kOptionConsoleFullName,
          value: (prof['user']?['full_name'] ?? username).toString());
      return ConsoleAuthResult(true, user: prof['user']);
    }
    return ConsoleAuthResult(false, error: data['error'] ?? 'login gagal (${res.statusCode})');
  } catch (e) {
    return ConsoleAuthResult(false, error: 'console tidak terjangkau: $e');
  }
}

Future<Map<String, dynamic>?> _verify(String token) async {
  try {
    final req = await HttpClient().postUrl(Uri.parse('${consoleServer()}/api/client-auth/verify'));
    req.headers.contentType = ContentType.json;
    req.headers.set('Authorization', 'Bearer $token');
    req.add(utf8.encode('{}'));
    final res = await req.close();
    if (res.statusCode != 200) return null;
    final body = await res.transform(utf8.decoder).join();
    return jsonDecode(body) as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
}

/// Status login sekarang. Returns:
///  ok             -> token masih valid (atau fallback cache dalam masa tenggang)
///  need_login     -> belum login / token expired
///  offline_grace  -> console gak terjangkau tapi fallback cache masih berlaku
Future<(bool ok, bool offlineGrace, Map<String, dynamic>? user)> consoleSessionState() async {
  final token = bind.mainGetLocalOption(key: kOptionConsoleToken);
  if (token.isEmpty) return (false, false, null);
  final tStr = bind.mainGetLocalOption(key: kOptionConsoleTokenTime);
  final t = int.tryParse(tStr) ?? 0;
  final ageH = (DateTime.now().millisecondsSinceEpoch - t) / 3600000.0;
  if (ageH > kTokenMaxAgeHours) return (false, false, null);

  final prof = await _verify(token);
  if (prof != null && prof['ok'] == true) {
    return (true, false, prof['user']);
  }
  // console down -> fallback cache (dalam masa tenggang)
  final cachedUser = {
    'username': bind.mainGetLocalOption(key: kOptionConsoleUser),
    'full_name': bind.mainGetLocalOption(key: kOptionConsoleFullName),
    'role': bind.mainGetLocalOption(key: kOptionConsoleRole),
  };
  return (true, true, cachedUser);
}

Future<void> consoleLogout() async {
  await bind.mainSetLocalOption(key: kOptionConsoleToken, value: '');
  await bind.mainSetLocalOption(key: kOptionConsoleTokenTime, value: '');
}

/// Daftar client yang boleh diakses oleh teknisi yang login.
Future<List<Map<String, dynamic>>?> consoleMyClients() async {
  final token = bind.mainGetLocalOption(key: kOptionConsoleToken);
  if (token.isEmpty) return null;
  try {
    final req = await HttpClient().getUrl(Uri.parse('${consoleServer()}/api/client-auth/my-clients'));
    req.headers.set('Authorization', 'Bearer $token');
    final res = await req.close();
    if (res.statusCode != 200) return null;
    final body = await res.transform(utf8.decoder).join();
    final data = jsonDecode(body) as Map<String, dynamic>;
    if (data['ok'] != true) return null;
    return (data['clients'] as List).cast<Map<String, dynamic>>();
  } catch (_) {
    return null;
  }
}
