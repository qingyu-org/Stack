import 'package:flutter_test/flutter_test.dart';
import 'package:mono_dash/domain/entities/panel_type.dart';
import 'package:mono_dash/domain/entities/server.dart';
import 'package:mono_dash/domain/entities/ssh_credentials.dart';

void main() {
  group('PanelType', () {
    test('defaults unknown or missing names to 1Panel', () {
      expect(PanelType.fromName(null), PanelType.onePanel);
      expect(PanelType.fromName('unknown'), PanelType.onePanel);
    });

    test('round-trips through Server JSON', () {
      final server = Server()
        ..host = '192.168.1.10'
        ..port = 10000
        ..panelType = PanelType.baota;

      final restored = Server.fromJson(server.toJson());

      expect(restored.panelType, PanelType.baota);
    });

    test('older saved servers without a type become 1Panel', () {
      final restored = Server.fromJson({'host': '192.168.1.10', 'port': 10000});

      expect(restored.panelType, PanelType.onePanel);
    });

    test('SSH metadata round-trips through Server JSON', () {
      final server = Server()
        ..host = '10.0.0.5'
        ..port = 22
        ..panelType = PanelType.bareMetal
        ..sshUsername = 'deploy'
        ..sshAuthType = SshAuthType.privateKey
        ..sshHostKey = 'ssh-ed25519 SHA256:abc';

      final restored = Server.fromJson(server.toJson());

      expect(restored.isSshServer, isTrue);
      expect(restored.sshUsername, 'deploy');
      expect(restored.sshAuthType, SshAuthType.privateKey);
      expect(restored.sshHostKey, 'ssh-ed25519 SHA256:abc');
    });
  });
}
