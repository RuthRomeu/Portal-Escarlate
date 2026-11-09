import 'package:flutter/foundation.dart';

/// URL base do gateway do back-end.
///
/// Por que três URLs diferentes?
/// - Web (kIsWeb): o browser já está na mesma máquina que o gateway,
///   então `localhost:3000` funciona diretamente.
/// - Android Emulator: o emulador roda numa VM isolada. Dentro dela,
///   `localhost` aponta para a própria VM, não para a máquina host.
///   O Android reserva `10.0.2.2` como alias fixo para a máquina host.
/// - iOS Simulator: roda no mesmo processo que o Mac, então
///   `localhost` funciona normalmente.
///
/// Em produção, substitua pela URL pública do gateway (ex: https://api.seudominio.com).
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    if (kIsWeb) return 'http://localhost:3000';

    // kDebugMode = true em dev, false em release.
    // Em release, a URL de produção deve vir de uma variável de build
    // (--dart-define=API_URL=https://...).
    const fromBuildEnv = String.fromEnvironment('API_URL');
    if (fromBuildEnv.isNotEmpty) return fromBuildEnv;

    if (defaultTargetPlatform == TargetPlatform.android) {
      // 10.0.2.2 é o alias do Android Emulator para a máquina host.
      return 'http://10.0.2.2:3000';
    }

    // iOS Simulator, macOS, Linux, Windows.
    return 'http://localhost:3000';
  }
}
