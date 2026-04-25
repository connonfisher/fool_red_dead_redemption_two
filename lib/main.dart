import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:webview_windows/webview_windows.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Red Dead Redemption 2',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.brown),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _webviewController = WebviewController();
  HttpServer? _server;
  String? _indexUrl;
  bool _isReady = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final videoDir = Directory('${tempDir.path}/rdr2_intro');
      if (await videoDir.exists()) {
        await videoDir.delete(recursive: true);
      }
      await videoDir.create();

      final introFile = File('${videoDir.path}/head.mp4');
      final introBytes = await rootBundle.load('assets/videos/head.mp4');
      await introFile.writeAsBytes(introBytes.buffer.asUint8List());

      final indexFile = File('${videoDir.path}/index.html');
      await indexFile.writeAsString('''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; }
    html, body { width: 100%; height: 100%; background: black; overflow: hidden; display: flex; justify-content: center; align-items: center; }
    video { max-width: 100%; max-height: 100%; object-fit: contain; }
    .volume-btn {
      position: fixed;
      top: 20px;
      right: 20px;
      background: rgba(0,0,0,0.7);
      color: white;
      border: 2px solid white;
      padding: 10px 20px;
      font-size: 18px;
      cursor: pointer;
      border-radius: 5px;
      z-index: 1000;
    }
  </style>
</head>
<body>
  <button class="volume-btn" id="volumeBtn">🔇 开启声音</button>
  <video id="video" autoplay playsinline>
    <source src="head.mp4" type="video/mp4">
  </video>
  <script>
    var video = document.getElementById('video');
    var volumeBtn = document.getElementById('volumeBtn');
    var soundEnabled = false;
    
    video.muted = true;
    
    video.onended = function() {
      window.location.href = 'about:blank#ended';
    };
    video.onerror = function() {
      window.location.href = 'about:blank#ended';
    };
    setTimeout(function() {
      window.location.href = 'about:blank#ended';
    }, 15000);
    
    volumeBtn.onclick = function() {
      if (soundEnabled) {
        video.muted = true;
        soundEnabled = false;
        volumeBtn.innerHTML = '🔇 开启声音';
      } else {
        video.muted = false;
        soundEnabled = true;
        volumeBtn.innerHTML = '🔊 关闭声音';
      }
    };
    
    video.play().catch(function(error) {
      video.muted = true;
      video.play();
    });
  </script>
</body>
</html>''');

      final staticHandler = createStaticHandler(
        videoDir.path,
        defaultDocument: 'index.html',
      );
      _server = await shelf_io.serve(staticHandler, 'localhost', 0);

      _indexUrl = 'http://localhost:${_server!.port}/index.html';

      await _webviewController.initialize();

      _webviewController.url.listen((url) {
        if (url != null && url.contains('#ended')) {
          _goToMainScreen();
        }
      });

      await _webviewController.loadUrl(_indexUrl!);

      setState(() {
        _isReady = true;
      });
    } catch (e) {
      Future.delayed(const Duration(seconds: 3), () {
        _goToMainScreen();
      });
    }
  }

  void _goToMainScreen() {
    try {
      _server?.close();
    } catch (e) {}

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const MainScreen()),
      );
    }
  }

  @override
  void dispose() {
    try {
      _server?.close();
    } catch (e) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _isReady
          ? Webview(_webviewController)
          : const Center(
              child: Text(
                'Red Dead Redemption 2',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool _showFlash = false;
  bool _showVideo = false;
  final _webviewController = WebviewController();
  HttpServer? _server;
  String? _gameIndexUrl;

  @override
  void initState() {
    super.initState();
    _startFlashCycle();
    _initServer();
  }

  Future<void> _initServer() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final videoDir = Directory('${tempDir.path}/rdr2_game');
      if (await videoDir.exists()) {
        await videoDir.delete(recursive: true);
      }
      await videoDir.create();

      final gameFile = File('${videoDir.path}/play.mp4');
      final gameBytes = await rootBundle.load('assets/videos/play.mp4');
      await gameFile.writeAsBytes(gameBytes.buffer.asUint8List());

      final indexFile = File('${videoDir.path}/index.html');
      await indexFile.writeAsString('''<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    * { margin: 0; padding: 0; }
    html, body { width: 100%; height: 100%; background: black; overflow: hidden; display: flex; justify-content: center; align-items: center; }
    video { max-width: 100%; max-height: 100%; object-fit: contain; }
    .volume-btn {
      position: fixed;
      top: 20px;
      left: 20px;
      background: rgba(0,0,0,0.7);
      color: white;
      border: 2px solid white;
      padding: 10px 20px;
      font-size: 18px;
      cursor: pointer;
      border-radius: 5px;
      z-index: 1000;
    }
  </style>
</head>
<body>
  <button class="volume-btn" id="volumeBtn">🔇 开启声音</button>
  <video id="video" autoplay playsinline controls>
    <source src="play.mp4" type="video/mp4">
  </video>
  <script>
    var video = document.getElementById('video');
    var volumeBtn = document.getElementById('volumeBtn');
    var soundEnabled = false;
    
    video.muted = true;
    
    volumeBtn.onclick = function() {
      if (soundEnabled) {
        video.muted = true;
        soundEnabled = false;
        volumeBtn.innerHTML = '🔇 开启声音';
      } else {
        video.muted = false;
        soundEnabled = true;
        volumeBtn.innerHTML = '🔊 关闭声音';
      }
    };
    
    video.play().catch(function(error) {
      video.muted = true;
      video.play();
    });
  </script>
</body>
</html>''');

      final staticHandler = createStaticHandler(
        videoDir.path,
        defaultDocument: 'index.html',
      );
      _server = await shelf_io.serve(staticHandler, 'localhost', 0);

      _gameIndexUrl = 'http://localhost:${_server!.port}/index.html';

      await _webviewController.initialize();
    } catch (e) {}
  }

  void _startFlashCycle() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 3));
      if (mounted && !_showVideo) {
        setState(() => _showFlash = true);
        await Future.delayed(const Duration(milliseconds: 400));
        if (mounted && !_showVideo) {
          setState(() => _showFlash = false);
        }
      }
    }
  }

  Future<void> _playGameVideo() async {
    if (_gameIndexUrl == null) return;

    try {
      await _webviewController.loadUrl(_gameIndexUrl!);

      setState(() {
        _showVideo = true;
      });
    } catch (e) {}
  }

  void _closeVideo() {
    setState(() {
      _showVideo = false;
    });
  }

  @override
  void dispose() {
    try {
      _server?.close();
    } catch (e) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (!_showVideo) ...[
            Image.asset('assets/images/main_background.jpg', fit: BoxFit.cover),
            if (_showFlash)
              Image.asset(
                'assets/images/flash_background.jpg',
                fit: BoxFit.cover,
              ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 200),
                  _buildButton('开始游戏', () {
                    _playGameVideo();
                  }),
                  const SizedBox(height: 30),
                  _buildButton('退出到桌面', () {
                    try {
                      exit(0);
                    } catch (e) {}
                  }),
                ],
              ),
            ),
          ],
          if (_showVideo)
            Stack(
              fit: StackFit.expand,
              children: [
                Webview(_webviewController),
                Positioned(
                  top: 20,
                  right: 20,
                  child: ElevatedButton(
                    onPressed: _closeVideo,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black.withValues(alpha: 0.7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      side: const BorderSide(color: Colors.white, width: 2),
                    ),
                    child: const Text('关闭', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.7),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        side: const BorderSide(color: Colors.white, width: 2),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 3,
        ),
      ),
    );
  }
}
