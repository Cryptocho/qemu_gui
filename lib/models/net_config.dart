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

class GuestForward {
  final String guestIp;
  final int guestPort;
  final String hostIp;
  final int hostPort;

  GuestForward({
    required this.guestIp,
    required this.guestPort,
    required this.hostIp,
    required this.hostPort,
  });

  Map<String, dynamic> toJson() => {
        'guestIp': guestIp,
        'guestPort': guestPort,
        'hostIp': hostIp,
        'hostPort': hostPort,
      };

  factory GuestForward.fromJson(Map<String, dynamic> json) => GuestForward(
        guestIp: json['guestIp'],
        guestPort: json['guestPort'],
        hostIp: json['hostIp'],
        hostPort: json['hostPort'],
      );

  @override
  String toString() => 'guestfwd=tcp:$guestIp:$guestPort-tcp:$hostIp:$hostPort';
}

class NetConfig {
  final String id;
  final List<PortForward> portForwards;
  final List<GuestForward> guestForwards;
  final String? smbPath;

  NetConfig({
    required this.id,
    this.portForwards = const [],
    this.guestForwards = const [],
    this.smbPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'portForwards': portForwards.map((e) => e.toJson()).toList(),
        'guestForwards': guestForwards.map((e) => e.toJson()).toList(),
        'smbPath': smbPath,
      };

  factory NetConfig.fromJson(Map<String, dynamic> json) => NetConfig(
        id: json['id'],
        portForwards: (json['portForwards'] as List? ?? [])
            .map((e) => PortForward.fromJson(e))
            .toList(),
        guestForwards: (json['guestForwards'] as List? ?? [])
            .map((e) => GuestForward.fromJson(e))
            .toList(),
        smbPath: json['smbPath'],
      );
}
