import 'package:flutter/material.dart' hide Text;
import '../l10n/app_text.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';

import '../data/sohbet_data.dart';
import '../theme/app_theme.dart';

class SohbetlerPage extends StatelessWidget {
  const SohbetlerPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Sohbetler',
              style: TextStyle(
                  fontFamily: 'Amiri', fontSize: 22, color: AppColors.ink)),
          const SizedBox(height: 14),
          Expanded(
            child: GridView.builder(
              itemCount: sohbetVideolar.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.95,
              ),
              itemBuilder: (context, i) {
                final v = sohbetVideolar[i];
                return _VideoCard(video: v);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({required this.video});
  final SohbetVideo video;

  void _open(BuildContext context) {
    if (!video.hasVideo) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Video eklenmedi'),
          content: const Text(
              'Bu video için henüz bir YouTube ID eklenmedi.\nsohbet_data.dart dosyasından ekleyebilirsiniz.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tamam')),
          ],
        ),
      );
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      settings: const RouteSettings(name: 'SohbetVideoSayfasi'),
      builder: (_) => _VideoPlayerPage(video: video),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.ivory,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _open(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.goldSoft),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.deep, Color(0xFF1C5A50)],
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    video.hasVideo ? '▶' : '➕',
                    style: const TextStyle(
                        fontSize: 26, color: AppColors.goldSoft),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 8),
                child: Text(
                  video.hasVideo
                      ? video.title
                      : '${video.title} (Video eklenmedi)',
                  style: const TextStyle(fontSize: 12, color: AppColors.ink),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// YouTube "liste dışı / unlisted" videoyu tam ekran benzeri bir sayfada
/// oynatır (HTML'deki video-player-overlay karşılığı)
class _VideoPlayerPage extends StatefulWidget {
  const _VideoPlayerPage({required this.video});
  final SohbetVideo video;

  @override
  State<_VideoPlayerPage> createState() => _VideoPlayerPageState();
}

class _VideoPlayerPageState extends State<_VideoPlayerPage> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController(
      initialVideoId: widget.video.youtubeId,
      flags: const YoutubePlayerFlags(autoPlay: true),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.video.title),
        backgroundColor: AppColors.deep,
      ),
      body: Center(
        child: YoutubePlayer(
          controller: _controller,
          showVideoProgressIndicator: true,
        ),
      ),
    );
  }
}
