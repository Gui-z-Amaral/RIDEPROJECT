import 'package:flutter_web_plugins/url_strategy.dart';

/// Tira o `#` da URL: `app.ride.dev.br/v/<id>` em vez de
/// `app.ride.dev.br/#/v/<id>`.
///
/// Não é cosmético, é o que faz o link compartilhado funcionar:
///  - com `#`, o Flutter iniciava sempre em `/` e caía no splash → o link de
///    uma viagem levava para a home (logado) ou para o login (deslogado);
///  - o fragmento depois do `#` **não é enviado ao servidor**, então o robô do
///    WhatsApp nunca receberia as tags Open Graph do evento — a prévia com
///    banner seria impossível.
///
/// Exige que o servidor devolva `index.html` para qualquer caminho (o Nginx já
/// faz isso com `try_files $uri $uri/ /index.html`); sem isso, recarregar uma
/// rota interna daria 404.
void configureUrlStrategy() => usePathUrlStrategy();
