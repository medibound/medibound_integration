import 'dart:async';
import 'dart:io' show HttpServer;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:medibound_integration/medibound_integration.dart';

const _html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Epic Authentication</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body { margin: 0; padding: 0; }
    main {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      font-family: -apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif;
    }
    #icon { font-size: 96pt; }
    #text { padding: 2em; max-width: 260px; text-align: center; }
    #button a {
      display: inline-block;
      padding: 12px 24px;
      color: white;
      border-radius: 6px;
      background-color: #0066cc;
      text-decoration: none;
      font-size: 16px;
      font-weight: 600;
    }
    #button a:active { background-color: #0052a3; }
  </style>
</head>
<body>
  <main>
    <div id="icon">🏥</div>
    <div id="text">Press the button below to complete Epic authentication.</div>
    <div id="button"><a href="CALLBACK_URL_HERE">Complete Authentication</a></div>
  </main>
</body>
</html>
''';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _integration = EpicIntegration(
    clientId: 'your-client-id', // Replace with your Epic client ID
    clientSecret: 'your-client-secret', // Replace with your Epic client secret
    redirectUri: kIsWeb 
      ? '${Uri.base.origin}/callback' 
      : 'http://localhost:43823/callback',
    epicBaseUrl: 'https://fhir.epic.com/interconnect-fhir-oauth/api/FHIR/R4',
  );

  String _status = 'Not connected';
  bool _isLoading = false;
  HttpServer? _server;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _startServer();
    }
  }

  @override
  void dispose() {
    _server?.close();
    super.dispose();
  }

  Future<void> _startServer() async {
    _server = await HttpServer.bind('127.0.0.1', 43823);
    _server?.listen((req) async {
      if (req.uri.path == '/callback') {
        req.response.headers.add('Content-Type', 'text/html');
        req.response.write(
          _html.replaceFirst(
            'CALLBACK_URL_HERE',
            'medibound://success?code=${Uri.encodeComponent(req.uri.queryParameters['code'] ?? '')}',
          ),
        );
        await req.response.close();
      }
    });
  }

  Future<void> _linkWithEpic() async {
    setState(() {
      _isLoading = true;
      _status = 'Connecting...';
    });

    try {
      final tokens = await _integration.launchOAuth(
        callbackUrlScheme: kIsWeb ? Uri.base.origin : 'medibound',
        preferEphemeral: false,
      );

      setState(() {
        _status = 'Connected successfully!\nAccess Token: ${tokens['access_token']?.substring(0, 10)}...';
      });
    } on PlatformException catch (e) {
      setState(() {
        _status = 'Connection failed: ${e.message}';
      });
    } catch (e) {
      setState(() {
        _status = 'Connection failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Epic Integration Test',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Epic Integration Test'),
          backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Test Epic Integration',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _linkWithEpic,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.link),
                  label: Text(_isLoading ? 'Connecting...' : 'Link with Epic'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _status,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 