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
  SohbetVideo(title: "1. Sohbet", youtubeId: "lMrhxfKBIhg"),
  SohbetVideo(title: "2. Sohbet", youtubeId: "DQwDAAhYdJI"),
  SohbetVideo(title: "3. Sohbet", youtubeId: "3T7wDbhx3HU"),
  SohbetVideo(title: "4. Sohbet", youtubeId: "0cy6Abs-zvs"),
  SohbetVideo(title: "5. Sohbet", youtubeId: "MI3m_j5dQYg"),
  SohbetVideo(title: "6. Sohbet", youtubeId: "gOYdMum4ZrM"),
  SohbetVideo(title: "7. Sohbet", youtubeId: "uSjH7SG1Juk"),
  SohbetVideo(title: "8. Sohbet", youtubeId: "UPajL_YBi-M"),
  // Yeni video eklemek için yukarıdaki satırlardan birini kopyalayın.
];
