import 'dart:convert';
import 'dart:developer';

import 'package:dart_minecraft/dart_minecraft.dart';
import 'package:dart_minecraft/src/packet/packets/response_packet.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SLP',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
          colorScheme: ColorScheme.fromSwatch(
        primarySwatch: Colors.teal,
      )),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class Server {
  Server(this.uri, {int? port, this.nick, int? timeoutSeconds})
      : port = port ?? 25565,
        timeoutSeconds = timeoutSeconds ?? 10;

  static const _divider = ',';
  static const _implictly_null = '@_NULL_@';

  String uri;
  int port;
  int timeoutSeconds;

  String? nick;

  String serialize() {
    return [uri, port, timeoutSeconds, nick ?? _implictly_null].join(_divider);
  }

  static Server fromSerialized(String data) {
    final split = data.split(_divider);
    final nickStr = split[3];
    return Server(split[0],
        port: int.parse(split[1]),
        timeoutSeconds: int.parse(split[2]),
        nick: nickStr == _implictly_null ? null : nickStr);
  }

  Future<ResponsePacket?> fetch() {
    return ping(
      uri,
      port: port,
      timeout: Duration(seconds: timeoutSeconds),
    );
  }
}

class _MyHomePageState extends State<MyHomePage> {
  static const String _prefKey = "SERVER_LIST_SAVED_SERVERS";

  final List<Server> _servers = [];
  bool _isFetching = true;

  late final SharedPreferences _prefs;

  _MyHomePageState() {
    SharedPreferences.getInstance().then((value) {
      _prefs = value;

      final fetched = _fetchServers();
      if (fetched != null) {
        _servers.addAll(fetched);
      }

      setState(() {
        _isFetching = false;
      });
    });
  }

  List<Server>? _fetchServers() {
    final servers = _prefs.getStringList(_prefKey)?.map((e) => Server.fromSerialized(e)).toList();
    return servers;
  }

  void _saveServers() {
    _prefs.setStringList(_prefKey, _servers.map((e) => e.serialize()).toList());
  }

  void _addServer(Server server) {
    setState(() {
      _servers.add(server);
      _saveServers();
    });
  }

  void _refreshServers() {
    setState(() {
      _isFetching = true;
    });

    _saveServers();
    _servers.clear();
    final fetched = _fetchServers();
    if (fetched != null) {
      _servers.addAll(fetched);
    }
    setState(() {
      _isFetching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    void snackbar(String msg) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('SLP : 서버 목록'),
            IconButton(
              onPressed: _refreshServers,
              icon: const Icon(Icons.refresh),
            )
          ],
        ),
      ),
      body: Center(
        child: _isFetching
            ? const RefreshProgressIndicator()
            : _servers.isEmpty
                ? Container(
                    child: const Text('하단의 버튼을 사용하여 서버를 추가해 주세요.'),
                  )
                : ListView.builder(
                    itemBuilder: (ctx, idx) {
                      final server = _servers[idx];
                      return FutureBuilder(
                          future: server.fetch(),
                          initialData: null,
                          builder: (ctx, snapshot) {
                            final hasError = snapshot.hasError;
                            final hasData = snapshot.hasData;

                            if (hasError) {
                              final error = snapshot.error;
                              log("오류 발생 : ");
                              log(error.toString());
                              snackbar(error.toString());
                            }

                            final data = snapshot.data;
                            final resp = data?.response;

                            final success = hasData && data != null && resp != null;
                            final ping = data?.ping;

                            final version = success ? resp.version.name : null;
                            final faviconBlob = success ? resp.favicon : null;
                            final motd = success && resp.description.description.isNotEmpty
                                ? resp.description.description
                                : null;

                            final Color pingColor;
                            if (ping == null) {
                              pingColor = Colors.redAccent;
                            } else if (ping <= 60) {
                              pingColor = Colors.greenAccent;
                            } else if (ping <= 120) {
                              pingColor = Colors.lightGreenAccent;
                            } else if (ping <= 200) {
                              pingColor = Colors.yellow;
                            } else {
                              pingColor = Colors.orangeAccent;
                            }

                            final players = resp?.players;

                            // region Creating Widgets

                            final faviconWidget = (faviconBlob != null)
                                ? faviconBlob.isNotEmpty
                                    ? SizedBox(
                                        width: 55,
                                        height: 55,
                                        child: Image.memory(base64Decode(faviconBlob.split(',')[1])),
                                      )
                                    : null
                                : null;

                            final nameWidget = Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                (!success && !hasError)
                                    ? const Padding(
                                        padding: EdgeInsets.fromLTRB(0, 0, 7, 0),
                                        child: SizedBox(
                                          width: 45,
                                          height: 45,
                                          child: RefreshProgressIndicator(),
                                        ),
                                      )
                                    : const SizedBox(),
                                server.nick != null
                                    ? Text(server.nick!,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 20,
                                        ))
                                    : Text.rich(TextSpan(children: [
                                        TextSpan(
                                            text: server.uri,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 20,
                                            )),
                                        TextSpan(
                                          text: server.port == 25565 ? ' ' : ' :${server.port}',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold, fontSize: 20, color: Colors.grey),
                                        ),
                                      ]))
                              ],
                            );
                            final pingWidget = Text(
                              ping == null ? '' : '${ping}ms',
                              style: TextStyle(fontSize: 14, color: pingColor),
                            );
                            final playerCountWidget = success && players != null
                                ? Text.rich(TextSpan(
                                    children: [
                                      TextSpan(text: players.online.toString(), style: const TextStyle(fontSize: 25)),
                                      TextSpan(
                                          text: ' / ${players.max.toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: Colors.grey))
                                    ],
                                  ))
                                : const SizedBox();

                            // endregion

                            return Card(
                              shadowColor: pingColor,
                              elevation: 2,
                              child: InkWell(
                                borderRadius: const BorderRadius.all(Radius.circular(3)),
                                onTap: !success
                                    ? null
                                    : () => showDialog(
                                        context: ctx,
                                        builder: (ctx) {
                                          final items = <Widget>[
                                            Text('버전 : ${version ?? '알 수 없음'}'),
                                            Text('MOTD : ${motd ?? '알 수 없음'}'),
                                            Text('지연시간 : ${ping == null ? '알 수 없음' : '${ping}ms'}'),
                                          ];

                                          if (players != null) {
                                            items.add(Text('현재 플레이어 : ${players.online}'));
                                            items.add(Text('최대 플레이어 : ${players.max}'));
                                            final playerSamples = players.sample;

                                            if (playerSamples.isNotEmpty) {
                                              items.add(const Text('플레이어 :'));

                                              for (final p in playerSamples) {
                                                items.add(Text('${p.name}'));
                                              }
                                            }
                                          }

                                          return Dialog(
                                            child: Padding(
                                              padding: const EdgeInsets.all(10),
                                              child: Column(
                                                mainAxisAlignment: MainAxisAlignment.center,
                                                mainAxisSize: MainAxisSize.min,
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: items,
                                              ),
                                            ),
                                          );
                                        }),
                                onLongPress: () => showDialog(
                                    context: ctx,
                                    builder: (ctx) => Dialog(
                                          child: Padding(
                                            padding: const EdgeInsets.fromLTRB(10, 12, 10, 2),
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              crossAxisAlignment: CrossAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text('해당 서버를 삭제하시겠습니까?'),
                                                Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    TextButton(
                                                        onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
                                                    TextButton(
                                                        onPressed: () {
                                                          setState(() {
                                                            _servers.remove(server);
                                                            _saveServers();
                                                          });
                                                          Navigator.pop(ctx);
                                                        },
                                                        child: const Text('삭제')),
                                                  ],
                                                )
                                              ],
                                            ),
                                          ),
                                        )),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.all(0),
                                    leading: faviconWidget,
                                    title: nameWidget,
                                    subtitle: Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: success
                                            ? Text(motd ?? version ?? '.')
                                            : hasError
                                                ? const Row(
                                                    children: [
                                                      Icon(
                                                        Icons.error,
                                                        color: Colors.redAccent,
                                                        size: 17,
                                                      ),
                                                      Text(
                                                        ' 연결 실패',
                                                        style: TextStyle(
                                                          color: Colors.redAccent,
                                                        ),
                                                      ),
                                                    ],
                                                  )
                                                : null),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        playerCountWidget,
                                        const SizedBox(height: 5),
                                        pingWidget,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          });
                    },
                    itemCount: _servers.length,
                    padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 3),
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (ctx) {
          final key = GlobalKey<FormState>();

          String? address;
          String? port;
          String? nick;
          String? timeout;

          void snackbar(String msg) {
            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
          }

          return Scaffold(
            appBar: AppBar(
              title: const Text('새 서버 추가'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(10),
              child: Form(
                key: key,
                child: Column(
                  children: [
                    // Address
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '서버 주소',
                        helperText: '포트를 제외한 서버 주소',
                        hintText: 'example.com',
                      ),
                      onChanged: (s) => address = s,
                      validator: (s) {
                        if (s == null) return '주소를 입력해주세요';
                        if (s.contains(':')) return '포트는 아래 필드에 입력해주세요!';
                        return null;
                      },
                    ),

                    // Port
                    const SizedBox(height: 25),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '포트',
                        helperText: "주소의 ':' 뒤의 숫자 (없을 경우 25565)",
                        hintText: '25565',
                      ),
                      onChanged: (s) => port = s,
                      validator: (s) {
                        if (s != null && s.isNotEmpty && int.tryParse(s) == null) {
                          return '포트가 유효하지 않습니다.';
                        }
                        return null;
                      },
                    ),

                    // Nick
                    const SizedBox(height: 25),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '서버 이름 (선택사항)',
                        helperText: '목록에 주소 대신 표시될 이름',
                        hintText: '반야생 서버',
                      ),
                      onChanged: (s) => nick = s,
                    ),

                    // Timeout
                    const SizedBox(height: 25),
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: '타임아웃 (선택사항)',
                        helperText: '연결을 시도할 최대 대기 시간 (초) [ 기본값 : 30초 ]',
                        hintText: '10',
                      ),
                      onChanged: (s) => timeout = s,
                      validator: (s) {
                        if (s != null && s.isNotEmpty && int.tryParse(s) == null) {
                          return '시간이 유효하지 않습니다.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 25),
                    TextButton(
                        onPressed: () {
                          final valid = key.currentState!.validate();
                          log('valid : $valid');
                          if (!valid) return;

                          if (address == null) {
                            snackbar('주소가 유효하지 않습니다!');
                            return;
                          }

                          final _port = port == null ? 25565 : int.tryParse(port!) ?? 25565;

                          final _timeout = timeout == null ? null : int.tryParse(timeout!);

                          final server = Server(
                            address!,
                            port: _port,
                            nick: nick,
                            timeoutSeconds: _timeout,
                          );

                          if (_servers.any((element) => element.uri == server.uri && element.port == server.port)) {
                            snackbar('동일한 설정의 서버가 이미 존재합니다.');
                            return;
                          }

                          _addServer(server);
                          snackbar('서버가 추가되었습니다!');
                          Navigator.pop(ctx);
                        },
                        child: const Text('추가'))
                  ],
                ),
              ),
            ),
          );
        })),
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods
    );
  }
}
