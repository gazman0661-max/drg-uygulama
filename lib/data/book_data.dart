/// ==========================================================
/// KİTAP VERİSİ
/// Kitap, taranmış sayfa görüntüleri olarak gösterilir (yazı orijinaliyle
/// birebir aynı kalır). Görüntüler assets/book/page_001.jpg, page_002.jpg …
/// şeklinde numaralıdır.
///
/// Sayfa eklemek/değiştirmek için:
///  1) Yeni görüntüleri assets/book/ içine aynı adlandırmayla koyun
///     (page_061.jpg …),
///  2) Aşağıdaki [bookPageCount] değerini güncelleyin.
/// ==========================================================

const int bookPageCount = 60;

String bookPageAsset(int index) =>
    'assets/book/page_${(index + 1).toString().padLeft(3, '0')}.jpg';
