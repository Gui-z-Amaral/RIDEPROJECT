import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // A chave NÃO fica no código. Ela vem do Info.plist, que por sua vez a lê
    // de ios/Flutter/Maps.xcconfig — um arquivo git-ignored, como o
    // android/local.properties e o web/env.js.
    //
    // Antes havia uma chave embutida aqui, e ela acabou num repositório
    // público. Ver "RideApp — segredos que não podem ser perdidos".
    if let key = Bundle.main.object(forInfoDictionaryKey: "GoogleMapsApiKey") as? String,
       !key.isEmpty, !key.hasPrefix("$(") {
      GMSServices.provideAPIKey(key)
    } else {
      // Sem chave o mapa não desenha. Falhar em silêncio aqui renderia horas
      // de procura por um mapa cinza sem explicação.
      NSLog("[RideApp] GoogleMapsApiKey ausente — crie ios/Flutter/Maps.xcconfig a partir do .example")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
