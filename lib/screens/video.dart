import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  late VlcPlayerController _videoPlayerController;
  bool _isLoading = true;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  void _initializePlayer() {
    _videoPlayerController = VlcPlayerController.network(
      'rtsp://192.168.11.214:8554/live.sdp', // Xác nhận IP và cổng
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(10000), // Cache 10 giây
          VlcAdvancedOptions.liveCaching(10000),
          VlcAdvancedOptions.fileCaching(10000),
          VlcAdvancedOptions.clockJitter(0),
        ]),
        rtp: VlcRtpOptions([
          VlcRtpOptions.rtpOverRtsp(true),
        ]),
        subtitle: VlcSubtitleOptions([
          VlcSubtitleOptions.boldStyle(true),
        ]),
        http: VlcHttpOptions([
          VlcHttpOptions.httpReconnect(true),
        ]),
        video: VlcVideoOptions([
          VlcVideoOptions.dropLateFrames(true),
          VlcVideoOptions.skipFrames(true),
        ]),
        extras: [
          '--rtsp-tcp', // Buộc dùng TCP
          '--verbose=2', // Log chi tiết
        ],
      ),
    );

    _videoPlayerController.addListener(() {
      if (mounted) {
        setState(() {
          _isLoading = !_videoPlayerController.value.isInitialized;
          if (_videoPlayerController.value.hasError) {
            _errorMessage = _videoPlayerController.value.errorDescription ?? 'Unknown error';
          }
        });
      }
    });

    _videoPlayerController.addOnInitListener(() async {
      await _videoPlayerController.startRendererScanning();
    });

    _videoPlayerController.addOnRendererEventListener((type, id, name) {
      debugPrint("Renderer Event: type: $type, id: $id, name: $name");
    });
  }

  @override
  void dispose() {
    _videoPlayerController.stopRendererScanning();
    _videoPlayerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('RTSP Player'),
      ),
      body: Column(
        children: [
          Container(
            height: 300,
            color: Colors.black,
            child: VlcPlayer(
              controller: _videoPlayerController,
              aspectRatio: 16 / 9,
              placeholder: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
          ),
          if (_errorMessage.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Error: $_errorMessage',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FloatingActionButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                  if (_videoPlayerController.value.isPlaying) {
                    await _videoPlayerController.pause();
                  } else {
                    await _videoPlayerController.play();
                  }
                  setState(() {});
                },
                child: Icon(
                  _videoPlayerController.value.isPlaying
                      ? Icons.pause
                      : Icons.play_arrow,
                ),
              ),
              const SizedBox(width: 20),
              FloatingActionButton(
                onPressed: _isLoading
                    ? null
                    : () async {
                  await _videoPlayerController.stop();
                  await _videoPlayerController.play();
                  setState(() {});
                },
                child: const Icon(Icons.replay),
              ),
            ],
          ),
        ],
      ),
    );
  }
}