import 'package:flutter/material.dart';

class GreenChampionUi {
  GreenChampionUi._();

  static const Color primary = Color(0xFF2E7D32);
  static const Color primaryDark = Color(0xFF1F5B25);
  static const Color pending = Color(0xFFF39C12);
  static const Color verified = Color(0xFF2E7D32);
  static const Color canvas = Color(0xFFF2F8F3);
  static const Color card = Colors.white;

  static BoxDecoration heroDecoration = const BoxDecoration(
    gradient: LinearGradient(
      colors: <Color>[Color(0xFF2E7D32), Color(0xFF66BB6A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.all(Radius.circular(20)),
  );

  static Widget sectionTitle(
    String title, {
    String? subtitle,
    Widget? trailing,
  }) {
    final List<Widget>? subtitleWidgets = subtitle == null
        ? null
        : <Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF617166),
              ),
            ),
          ];
    final List<Widget>? trailingWidgets = trailing == null ? null : <Widget>[trailing];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF1D2B1E),
                ),
              ),
              ...?subtitleWidgets,
            ],
          ),
        ),
        ...?trailingWidgets,
      ],
    );
  }

  static Widget statTile({
    required String label,
    required String value,
    required IconData icon,
    required Color tone,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: <Widget>[
          CircleAvatar(
            radius: 18,
            backgroundColor: tone.withValues(alpha: 0.18),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF617166),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    color: tone,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
