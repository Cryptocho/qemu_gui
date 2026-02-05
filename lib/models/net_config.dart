enum NetProtocol { tcp, udp }

class PortForward {
  final NetProtocol protocol;
  final int hostPort;
  final int guestPort;

  PortForward({
    required this.protocol,
    required this.hostPort,
    required this.guestPort,
  });

  Map<String, dynamic> toJson() => {
        'protocol': protocol.name,
        'hostPort': hostPort,
        'guestPort': guestPort,
      };

  factory PortForward.fromJson(Map<String, dynamic> json) => PortForward(
        protocol: NetProtocol.values.byName(json['protocol']),
        hostPort: json['hostPort'],
        guestPort: json['guestPort'],
      );

  @override
  String toString() => 'hostfwd=${protocol.name}::$hostPort-:$guestPort';
}

class NetConfig {
  final String id;
  final List<PortForward> portForwards;
  final String? smbPath;

  NetConfig({
    required this.id,
    this.portForwards = const [],
    this.smbPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'portForwards': portForwards.map((e) => e.toJson()).toList(),
        'smbPath': smbPath,
      };

  factory NetConfig.fromJson(Map<String, dynamic> json) => NetConfig(
        id: json['id'],
        portForwards: (json['portForwards'] as List)
            .map((e) => PortForward.fromJson(e))
            .toList(),
        smbPath: json['smbPath'],
      );
}
