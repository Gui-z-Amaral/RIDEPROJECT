import '../models/user_model.dart';
import '../models/location_model.dart';
import '../models/trip_model.dart';
import '../models/ride_model.dart';
import '../models/stop_model.dart';
import '../models/message_model.dart';

class MockData {
  static final UserModel currentUser = UserModel(
    id: 'u1',
    name: 'Rafael Moto',
    username: '@rafamoto',
    bio: 'Motociclista apaixonado. Honda CB 500F 2022. Adoro estradas sinuosas e cafés à beira da estrada.',
    motoModel: 'Honda CB 500F',
    motoYear: '2022',
    friendsCount: 24,
    tripsCount: 47,
    isOnline: true,
    photos: [],
  );

  static final List<UserModel> users = [
    UserModel(id: 'u2', name: 'Ana Wheels', username: '@anawheels', motoModel: 'Yamaha MT-07', motoYear: '2023', friendsCount: 18, tripsCount: 32, isOnline: true),
    UserModel(id: 'u3', name: 'Carlos Strada', username: '@carlostrada', motoModel: 'BMW R 1250 GS', motoYear: '2021', friendsCount: 35, tripsCount: 89, isOnline: false),
    UserModel(id: 'u4', name: 'Lena Torque', username: '@lenatorque', motoModel: 'Ducati Monster', motoYear: '2022', friendsCount: 12, tripsCount: 21, isOnline: true),
    UserModel(id: 'u5', name: 'Marco Speed', username: '@marcospeed', motoModel: 'KTM 790 Duke', motoYear: '2020', friendsCount: 29, tripsCount: 63, isOnline: true),
    UserModel(id: 'u6', name: 'Julia Asfalto', username: '@juliaasfalto', motoModel: 'Honda Africa Twin', motoYear: '2023', friendsCount: 41, tripsCount: 77, isOnline: false),
    UserModel(id: 'u7', name: 'Pedro Curva', username: '@pedrocurva', motoModel: 'Kawasaki Z900', motoYear: '2021', friendsCount: 16, tripsCount: 28, isOnline: true),
    UserModel(id: 'u8', name: 'Sofia Pista', username: '@sofiapista', motoModel: 'Triumph Street Triple', motoYear: '2022', friendsCount: 22, tripsCount: 44, isOnline: false),
  ];

  static List<UserModel> get friends => users.sublist(0, 5);

  static final List<StopModel> suggestedStops = [
    StopModel(
      id: 's1',
      name: 'Mirante da Serra',
      description: 'Vista panorâmica incrível da serra. Ponto obrigatório para motociclistas.',
      category: 'Mirante',
      location: LocationModel(lat: -27.5, lng: -48.5, address: 'Serra Catarinense, SC'),
      rating: 4.8,
    ),
    StopModel(
      id: 's2',
      name: 'Café do Motoqueiro',
      description: 'Café especializado para motociclistas com garagem coberta e cardápio regional.',
      category: 'Gastronômico',
      location: LocationModel(lat: -27.3, lng: -48.9, address: 'Florianópolis, SC'),
      rating: 4.6,
    ),
    StopModel(
      id: 's3',
      name: 'Posto BR Km 420',
      description: 'Posto com área de descanso, lanchonete e banheiros limpos.',
      category: 'Posto',
      location: LocationModel(lat: -26.9, lng: -49.1, address: 'BR-101, SC'),
      rating: 4.2,
    ),
    StopModel(
      id: 's4',
      name: 'Cachoeira do Veu',
      description: 'Trilha de 20 min até cachoeira. Estacionamento para motos na entrada.',
      category: 'Natureza',
      location: LocationModel(lat: -26.7, lng: -49.4, address: 'Blumenau, SC'),
      rating: 4.9,
    ),
    StopModel(
      id: 's5',
      name: 'Restaurante Serra Verde',
      description: 'Culinária regional. Famoso pelo frango caipira com polenta.',
      category: 'Gastronômico',
      location: LocationModel(lat: -28.1, lng: -49.0, address: 'Lages, SC'),
      rating: 4.7,
    ),
  ];

  static final List<TripModel> trips = [
    TripModel(
      id: 't1',
      title: 'Serra Catarinense',
      description: 'Viagem épica pelas serras de SC. Curvas incríveis, paisagens de tirar o fôlego.',
      origin: LocationModel(lat: -27.5954, lng: -48.5480, address: 'Florianópolis, SC', label: 'Partida'),
      destination: LocationModel(lat: -27.8167, lng: -50.3333, address: 'Lages, SC', label: 'Destino'),
      waypoints: [
        LocationModel(lat: -27.5969, lng: -48.5480, address: 'BR-282', label: 'Parada 1'),
      ],
      stops: [MockData.suggestedStops[0], MockData.suggestedStops[1]],
      participants: [MockData.users[0], MockData.users[1]],
      creator: currentUser,
      status: TripStatus.planned,
      routeType: RouteType.scenic,
      scheduledAt: DateTime.now().add(const Duration(days: 3)),
      estimatedDistance: 248.5,
      estimatedDuration: '3h 20min',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    TripModel(
      id: 't2',
      title: 'Litoral Norte',
      description: 'Rota pelo litoral norte com paradas nas melhores praias.',
      origin: LocationModel(lat: -27.5954, lng: -48.5480, address: 'Florianópolis, SC'),
      destination: LocationModel(lat: -26.9, lng: -48.6, address: 'Itajaí, SC'),
      participants: [MockData.users[2], MockData.users[3]],
      creator: MockData.users[0],
      status: TripStatus.planned,
      routeType: RouteType.gastronomic,
      scheduledAt: DateTime.now().add(const Duration(days: 7)),
      estimatedDistance: 95.0,
      estimatedDuration: '1h 45min',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),
    TripModel(
      id: 't3',
      title: 'Vale Europeu',
      description: 'Pedalando pelo vale com arquitetura alemã e italiana.',
      origin: LocationModel(lat: -26.9, lng: -49.1, address: 'Blumenau, SC'),
      destination: LocationModel(lat: -26.4, lng: -49.3, address: 'Pomerode, SC'),
      participants: [MockData.users[1], MockData.users[4]],
      creator: currentUser,
      status: TripStatus.completed,
      routeType: RouteType.scenic,
      estimatedDistance: 40.0,
      estimatedDuration: '50min',
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
    ),
  ];

  static final List<RideModel> rides = [
    RideModel(
      id: 'r1',
      title: 'Rolê da sexta',
      meetingPoint: LocationModel(lat: -27.5954, lng: -48.5480, address: 'Praça XV, Florianópolis', label: 'Ponto de encontro'),
      participants: [MockData.users[0], MockData.users[1], MockData.users[2]],
      creator: currentUser,
      status: RideStatus.scheduled,
      scheduledAt: DateTime.now().add(const Duration(days: 2, hours: 3)),
      isImmediate: false,
      createdAt: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    RideModel(
      id: 'r2',
      title: 'Rolê rápido',
      meetingPoint: LocationModel(lat: -27.6, lng: -48.55, address: 'Lagoa da Conceição, Florianópolis'),
      participants: [MockData.users[3]],
      creator: currentUser,
      status: RideStatus.waiting,
      isImmediate: true,
      createdAt: DateTime.now().subtract(const Duration(minutes: 10)),
    ),
  ];

  static List<MessageModel> getMessages(String chatId) {
    final messages = [
      MessageModel(id: 'm1', senderId: 'u2', senderName: 'Ana Wheels', content: 'Galera, tá confirmado o rolê de sexta?', sentAt: DateTime.now().subtract(const Duration(hours: 2)), chatId: chatId),
      MessageModel(id: 'm2', senderId: 'u1', senderName: 'Rafael Moto', content: 'Confirmado! Saindo às 18h da Praça XV', sentAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 45)), chatId: chatId),
      MessageModel(id: 'm3', senderId: 'u3', senderName: 'Carlos Strada', content: 'Estarei lá! Vou de BMW hoje 🏍️', sentAt: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)), chatId: chatId),
      MessageModel(id: 'm4', senderId: 'u2', senderName: 'Ana Wheels', content: 'Ótimo! Alguém sabe se vai chover?', sentAt: DateTime.now().subtract(const Duration(hours: 1)), chatId: chatId),
      MessageModel(id: 'm5', senderId: 'u1', senderName: 'Rafael Moto', content: 'Previsão tá boa, sol o dia todo 🌞', sentAt: DateTime.now().subtract(const Duration(minutes: 45)), chatId: chatId),
    ];
    return messages;
  }
}
