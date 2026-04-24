// Testes de MessageModel — principalmente o getter `hasImage` que
// decide se a bolha de chat renderiza texto, imagem ou ambos.
import 'package:flutter_test/flutter_test.dart';
import 'package:ride_app/core/models/message_model.dart';

MessageModel _msg({String content = 'oi', String? imageUrl}) {
  return MessageModel(
    id: 'm-1',
    senderId: 'u',
    senderName: 'Ana',
    content: content,
    imageUrl: imageUrl,
    sentAt: DateTime(2025, 1, 1, 12, 0),
  );
}

void main() {
  group('MessageModel.hasImage', () {
    test('true quando imageUrl é não-null e não-vazio', () {
      expect(_msg(imageUrl: 'https://cdn/x.jpg').hasImage, isTrue);
    });

    test('false quando imageUrl é null', () {
      expect(_msg().hasImage, isFalse);
    });

    test('false quando imageUrl é string vazia', () {
      expect(_msg(imageUrl: '').hasImage, isFalse);
    });
  });

  group('MessageModel defaults', () {
    test('isRead default é false', () {
      expect(_msg().isRead, isFalse);
    });

    test('sentAt é preservado', () {
      final m = _msg();
      expect(m.sentAt, DateTime(2025, 1, 1, 12, 0));
    });
  });
}
