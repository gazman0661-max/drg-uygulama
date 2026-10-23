import 'package:flutter/material.dart';

import '../../data/esma_data.dart';
import '../../theme/app_theme.dart';

/// Esmâü'l-Hüsnâ: 99 ismin Arapça yazılışı, okunuşu ve kısa anlamı.
class EsmaPage extends StatelessWidget {
  const EsmaPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text('Esmâü\'l-Hüsnâ')),
      body: ListView.separated(
        padding: const EdgeInsets.all(18),
        itemCount: esmaList.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final e = esmaList[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.ivory,
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.goldSoft),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: AppColors.gold),
                  child: Text('${i + 1}',
                      style: const TextStyle(
                          color: AppColors.deep,
                          fontWeight: FontWeight.w700,
                          fontSize: 13)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e[0],
                          style: const TextStyle(
                              fontFamily: 'Amiri',
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text(e[2],
                          style: const TextStyle(
                              fontSize: 12.5, color: AppColors.ink)),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(e[1],
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                        fontFamily: 'Amiri',
                        fontSize: 26,
                        color: AppColors.deep)),
              ],
            ),
          );
        },
      ),
    );
  }
}
