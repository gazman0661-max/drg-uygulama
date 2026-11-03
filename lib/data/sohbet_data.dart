/// ==========================================================
/// SOHBET VİDEOLARI VERİSİ
/// -------------------------------------------------------------
/// Videolarınızı YouTube'a "Liste dışı / Unlisted" olarak yükleyin.
/// Böylece video herkese açık aramada çıkmaz, ama linki/ID'si olan
/// (yani sizin uygulamanız) oynatabilir.
///
/// Her video için YouTube video ID'sini ekleyin. ID, video linkinin
/// şu kısmıdır: https://youtube.com/watch?v=BU_KISIM_ID
/// ==========================================================

class SohbetVideo {
  final String title;
  final String youtubeId;
  const SohbetVideo({required this.title, required this.youtubeId});

  bool get hasVideo => youtubeId.isNotEmpty;
}

const List<SohbetVideo> sohbetVideolar = [
  SohbetVideo(title: "1. Sohbet (örnek)", youtubeId: ""),
  SohbetVideo(title: "2. Sohbet (örnek)", youtubeId: ""),
  SohbetVideo(title: "3. Sohbet (örnek)", youtubeId: ""),
  SohbetVideo(title: "4. Sohbet (örnek)", youtubeId: ""),
  SohbetVideo(title: "5. Sohbet (örnek)", youtubeId: ""),
  SohbetVideo(title: "6. Sohbet (örnek)", youtubeId: ""),
  // ... 25-30 adete kadar aynı şekilde devam edin.
  // youtubeId boş bırakılırsa kart "Video eklenmedi" olarak görünür.
];
