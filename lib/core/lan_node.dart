/// 局域网互传的传输层：UDP 广播把「我在、这是我的配对码」喊出去，
/// 再用一个临时的 HTTP 服务收包。
///
/// 为什么这么朴素：
/// - 不引 mDNS 包：多一个依赖，多一层平台权限，收益只是名字好看一点。
/// - 不做 TLS：同一 WiFi 内 + 6 位配对码已能挡住"顺手点开"的人；
///   要挡同网段的主动嗅探需要端到端加密，那是云同步阶段的事。
/// - 端口用固定 UDP 广播口 + 随机 HTTP 口：广播口必须固定才能互相发现，
///   收包口随机可以避免两台以上设备抢同一个端口。
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// 广播口。改了就不互通了，两端必须是同一个版本。
const int kLanUdpPort = 47821;

/// 广播前缀，带版本号，避免旧版本客户端误读新格式。
const String kLanBeacon = 'ENVX1';

/// 一次发现的存活时间：超过这个时间没再收到广播，就从列表里剔除。
const Duration kPeerTtl = Duration(seconds: 12);

/// 广播间隔。
const Duration kBeaconInterval = Duration(seconds: 3);

/// 一台被发现的对端。
class LanPeerInfo {
  const LanPeerInfo({
    required this.code,
    required this.name,
    required this.host,
    required this.port,
    required this.lastSeen,
  });

  /// 对端的配对码（对方主动喊出来的，用来在发送时校验）。
  final String code;
  final String name;
  final String host;
  final int port;
  final DateTime lastSeen;

  LanPeerInfo touched(DateTime now) => LanPeerInfo(
        code: code,
        name: name,
        host: host,
        port: port,
        lastSeen: now,
      );

  String get endpoint => 'http://$host:$port';
}

/// 收到一个包时抛给 UI 的回调。
typedef PackReceiver = Future<void> Function(String packJson, String fromName);

/// 本机的局域网节点：对外广播自己，也接收别人推来的包。
class LanNode {
  LanNode({
    required this.code,
    required this.deviceName,
    required this.photosDir,
  });

  /// 本机配对码；对端必须带对这个码才能把包推过来。
  final String code;

  /// 显示给别人看的设备名。
  final String deviceName;

  /// 接收后图片落盘的目录（由调用方给出，便于测试替换）。
  final String photosDir;

  RawDatagramSocket? _udp;
  HttpServer? _http;
  Timer? _beacon;
  Timer? _sweep;
  final Map<String, LanPeerInfo> _peers = {};
  final StreamController<List<LanPeerInfo>> _peerStream =
      StreamController<List<LanPeerInfo>>.broadcast();

  /// 收到包后的处理（由 UI 注入：解析 → 写库 → 提示）。
  PackReceiver? onPackReceived;

  /// 本机 HTTP 服务实际监听的端口。
  int get httpPort => _http?.port ?? 0;

  /// 发现到的其他设备（每 3 秒推送一次快照）。
  Stream<List<LanPeerInfo>> get peers => _peerStream.stream;

  List<LanPeerInfo> get peersSnapshot {
    final now = DateTime.now();
    return _peers.values
        .where((p) => now.difference(p.lastSeen) < kPeerTtl)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  bool get isRunning => _http != null;

  Future<void> start() async {
    if (isRunning) return;

    _http = await HttpServer.bind(InternetAddress.anyIPv4, 0);
    _http!.listen(_handleHttp, onError: (Object _) {});

    _udp = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      kLanUdpPort,
      reuseAddress: true,
    );
    _udp!.broadcastEnabled = true;
    _udp!.listen(_handleUdp, onError: (Object _) {});

    _beacon = Timer.periodic(kBeaconInterval, (_) => _sendBeacon());
    _sweep = Timer.periodic(const Duration(seconds: 4), (_) => _emit());
    _sendBeacon();
    _emit();
  }

  Future<void> stop() async {
    _beacon?.cancel();
    _sweep?.cancel();
    _beacon = null;
    _sweep = null;
    _udp?.close();
    _udp = null;
    await _http?.close(force: true);
    _http = null;
    _peers.clear();
    _emit();
  }

  void _sendBeacon() {
    final socket = _udp;
    if (socket == null || _http == null) return;
    final payload = '$kLanBeacon|$code|$deviceName|${_http!.port}';
    try {
      socket.send(
        utf8.encode(payload),
        InternetAddress('255.255.255.255'),
        kLanUdpPort,
      );
    } on Object {
      // 广播在某些网络（如热点隔离）下会失败，静默即可：发现不了还会有人手动输地址。
    }
  }

  void _handleUdp(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    final dg = _udp?.receive();
    if (dg == null) return;
    final text = utf8.decode(dg.data, allowMalformed: true);
    final parts = text.split('|');
    if (parts.length != 4 || parts[0] != kLanBeacon) return;

    final code = parts[1];
    final name = parts[2];
    final port = int.tryParse(parts[3]);
    if (port == null || port <= 0) return;

    // 自己发的广播会打回自己，跳过（同码同端口）。
    if (code == this.code && name == deviceName && port == _http?.port) return;

    final host = dg.address.address;
    final now = DateTime.now();
    final key = '$host:$port';
    final existing = _peers[key];
    _peers[key] = existing == null
        ? LanPeerInfo(
            code: code, name: name, host: host, port: port, lastSeen: now)
        : existing.touched(now);
    _emit();
  }

  void _emit() {
    if (_peerStream.isClosed) return;
    _peerStream.add(peersSnapshot);
  }

  Future<void> _handleHttp(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.method == 'GET' && request.uri.path == '/info') {
        response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'name': deviceName, 'version': 1}));
        await response.close();
        return;
      }

      if (request.method == 'POST' && request.uri.path == '/push') {
        final given = request.headers.value('x-envx-code') ?? '';
        if (!_codeOk(given)) {
          response
            ..statusCode = HttpStatus.forbidden
            ..write('code');
          await response.close();
          return;
        }
        final body = await utf8.decodeStream(request);
        final from = request.headers.value('x-envx-from') ?? '对方设备';
        final receiver = onPackReceived;
        if (receiver == null) {
          response
            ..statusCode = HttpStatus.serviceUnavailable
            ..write('not-ready');
          await response.close();
          return;
        }
        await receiver(body, from);
        response
          ..statusCode = HttpStatus.ok
          ..write('ok');
        await response.close();
        return;
      }

      response.statusCode = HttpStatus.notFound;
      await response.close();
    } on Object catch (e) {
      try {
        response
          ..statusCode = HttpStatus.internalServerError
          ..write('$e');
        await response.close();
      } on Object {
        // 连接已断，无事可做。
      }
    }
  }

  bool _codeOk(String given) {
    if (given.length != code.length) return false;
    var diff = 0;
    for (var i = 0; i < code.length; i++) {
      diff |= code.codeUnitAt(i) ^ given.codeUnitAt(i);
    }
    return diff == 0;
  }

  /// 把一个包推给对端。返回 null 表示成功，否则是失败原因（给用户看的话术）。
  Future<String?> pushTo(LanPeerInfo peer, String packJson) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..idleTimeout = const Duration(seconds: 8);
    try {
      final req = await client
          .postUrl(Uri.parse('${peer.endpoint}/push'))
          .timeout(const Duration(seconds: 8));
      req.headers.set('x-envx-code', peer.code);
      req.headers.set('x-envx-from', deviceName);
      req.headers.contentType = ContentType.json;
      req.add(utf8.encode(packJson));
      final res = await req.close().timeout(const Duration(seconds: 20));
      final text = await utf8.decodeStream(res).timeout(
            const Duration(seconds: 10),
          );
      if (res.statusCode == HttpStatus.ok) return null;
      if (res.statusCode == HttpStatus.forbidden) return '配对码不对，对方拒绝了这次传输';
      return '对方返回 ${res.statusCode}：$text';
    } on TimeoutException {
      return '对方没响应（超时）。确认两台设备在同一个 WiFi，且都停在这一页';
    } on Object catch (e) {
      return '连不上对方：$e';
    } finally {
      client.close(force: true);
    }
  }

  Future<void> dispose() async {
    await stop();
    await _peerStream.close();
  }
}
