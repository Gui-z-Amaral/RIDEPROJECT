/// Configura a forma da URL na web, sem `#`.
///
/// Import condicional porque `flutter_web_plugins` só existe na web —
/// importá-lo direto quebraria a compilação do app nativo. É o mesmo princípio
/// da regra do projeto ("`kIsWeb` mora em service"): a diferença de plataforma
/// fica isolada aqui, e o `main` chama uma função só.
export 'url_strategy_stub.dart'
    if (dart.library.js_interop) 'url_strategy_web.dart';
