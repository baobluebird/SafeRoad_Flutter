import 'package:flutter/material.dart';
import 'package:flutter_vlc_player/flutter_vlc_player.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

class VideoScreen extends StatefulWidget {
  const VideoScreen({super.key});

  @override
  State<VideoScreen> createState() => _VideoScreenState();
}

class _VideoScreenState extends State<VideoScreen> {
  VlcPlayerController? _videoPlayerController;
  bool _isLoading = true;
  String _errorMessage = '';
  final TextEditingController _urlController = TextEditingController();
  final _box = Hive.box('myBox'); // không khai báo kiểu cụ thể

  @override
  void initState() {
    super.initState();
    _loadSavedUrls(); // Lấy danh sách URL từ Hive khi ứng dụng khởi động
  }



  // Lấy danh sách URL đã lưu từ Hive
  Future<void> _loadSavedUrls() async {
    List<String> savedUrls = List<String>.from(_box.get('savedUrls', defaultValue: []));
    //print list
    debugPrint('Saved URLs: $savedUrls');
    if (savedUrls != null && savedUrls.isNotEmpty) {
      _urlController.text = savedUrls.last; // Gợi ý URL cuối cùng đã lưu
    }
  }

  // Lưu URL vào Hive (cập nhật danh sách URL đã kết nối thành công)
  Future<void> _saveUrl(String url) async {
    List<String> savedUrls = List<String>.from(_box.get('savedUrls', defaultValue: []));

    if (!savedUrls.contains(url)) {
      savedUrls.add(url); // Chỉ thêm nếu chưa có trong danh sách
      await _box.put('savedUrls', savedUrls);
      debugPrint('Saved URL: $url');
    } else {
      debugPrint('URL already exists, not saved: $url');
    }
  }


  // Khởi tạo VlcPlayer với URL nhập vào
  void _initializePlayer(String url) {
    _videoPlayerController = VlcPlayerController.network(
      url,
      hwAcc: HwAcc.full,
      autoPlay: true,
      options: VlcPlayerOptions(
        advanced: VlcAdvancedOptions([
          VlcAdvancedOptions.networkCaching(10000),
          VlcAdvancedOptions.liveCaching(10000),
          VlcAdvancedOptions.fileCaching(10000),
          VlcAdvancedOptions.clockJitter(0),
        ]),
        rtp: VlcRtpOptions([VlcRtpOptions.rtpOverRtsp(true)]),
        subtitle: VlcSubtitleOptions([VlcSubtitleOptions.boldStyle(true)]),
        http: VlcHttpOptions([VlcHttpOptions.httpReconnect(true)]),
        video: VlcVideoOptions([VlcVideoOptions.dropLateFrames(true), VlcVideoOptions.skipFrames(true)]),
        extras: ['--rtsp-tcp', '--verbose=2'],
      ),
    );

    _videoPlayerController!.addListener(() {
      if (mounted) {
        setState(() {
          _isLoading = !_videoPlayerController!.value.isInitialized;
          if (_videoPlayerController!.value.hasError) {
            _errorMessage = _videoPlayerController!.value.errorDescription ?? 'Unknown error';
          }
        });
      }
    });

    _videoPlayerController!.addOnInitListener(() async {
      await _videoPlayerController!.startRendererScanning();
    });

    _videoPlayerController!.addOnRendererEventListener((type, id, name) {
      debugPrint("Renderer Event: type: $type, id: $id, name: $name");
    });
  }

  // Start streaming from the entered URL
  void _startStream() {
    if (_videoPlayerController?.value.isInitialized ?? false) {
      _videoPlayerController?.stop();
    }
    _initializePlayer(_urlController.text.trim());
    _saveUrl(_urlController.text.trim()); // Lưu URL đã kết nối thành công
    setState(() {
      _errorMessage = '';
    });
  }

  // Stop stream and reset all
  void _stopStream() {
    _videoPlayerController?.stop();
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    // Reset widget state and reload everything
    _reloadState();
  }

  // Reload state (reloads widget)
  void _reloadState() {
    setState(() {
      _videoPlayerController = null;
      _urlController.clear();
    });
  }

  @override
  void dispose() {
    _videoPlayerController?.stopRendererScanning();
    _videoPlayerController?.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Video Player
            Container(
              height: 300,
              color: Colors.black,
              child: _videoPlayerController == null
                  ? const Center(child: CircularProgressIndicator(color: Colors.white))
                  : VlcPlayer(
                controller: _videoPlayerController!,
                aspectRatio: 16 / 9,
                placeholder: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            ),
            // Error Message
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Error: $_errorMessage',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            // Input URL and connect
            if (_isLoading)
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Nhập URL RTSP',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _startStream,
                      child: const Text('Xem'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            // Playback controls
            if (!_isLoading) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  FloatingActionButton(
                    onPressed: () async {
                      if (_videoPlayerController!.value.isPlaying) {
                        await _videoPlayerController!.pause();
                      } else {
                        await _videoPlayerController!.play();
                      }
                      setState(() {});
                    },
                    child: Icon(
                      _videoPlayerController!.value.isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                  ),
                  const SizedBox(width: 20),
                  FloatingActionButton(
                    onPressed: _stopStream,
                    child: const Icon(Icons.stop),
                  ),
                ],
              ),
            ],
            // Display the list of saved URLs
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Danh sách URL đã kết nối:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ValueListenableBuilder(
                    valueListenable: _box.listenable(),
                    builder: (context, Box box, _) {
                      final List<String> savedUrls = List<String>.from(box.get('savedUrls', defaultValue: []));

                      if (savedUrls.isEmpty) {
                        return const Text("Chưa có URL nào được lưu");
                      }

                      return ListView.builder(
                        shrinkWrap: true,
                        itemCount: savedUrls.length,
                        itemBuilder: (context, index) {
                          return ListTile(
                            title: Text(savedUrls[index]),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                savedUrls.removeAt(index);
                                await _box.put('savedUrls', savedUrls);
                                setState(() {});
                              },
                            ),
                            onTap: () {
                              _urlController.text = savedUrls[index];
                            },
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
