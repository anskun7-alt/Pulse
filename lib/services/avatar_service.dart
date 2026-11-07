import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

class AvatarItem {
  final String id;
  final String name;
  final String series;
  final String category; // 'RDR2' | 'Hajime no Ippo' | 'Anime' | 'Pulse'
  final String assetPath;
  final String tagLine;
  final Color accentColor;

  const AvatarItem({
    required this.id,
    required this.name,
    required this.series,
    required this.category,
    required this.assetPath,
    required this.tagLine,
    required this.accentColor,
  });
}

class AvatarService {
  AvatarService._();
  static final AvatarService instance = AvatarService._();

  static const String _avatarKey = 'user_selected_avatar_id';
  static const String _userNameKey = 'user_profile_name';

  static const List<AvatarItem> allAvatars = [
    // ── Red Dead Redemption 2 ───────────────────────────────────────────────
    AvatarItem(
      id: 'rdr2_arthur',
      name: 'Arthur Morgan',
      series: 'Red Dead Redemption 2',
      category: 'RDR2',
      assetPath: 'assets/avatars/rdr2_arthur.png',
      tagLine: '"We\'re more ghosts than people."',
      accentColor: Color(0xFFE50914),
    ),
    AvatarItem(
      id: 'rdr2_john',
      name: 'John Marston',
      series: 'Red Dead Redemption 2',
      category: 'RDR2',
      assetPath: 'assets/avatars/rdr2_john.png',
      tagLine: '"I have a rendezvous with redemption."',
      accentColor: Color(0xFFFF5722),
    ),
    AvatarItem(
      id: 'rdr2_posse',
      name: 'Van der Linde Gang',
      series: 'Red Dead Redemption 2',
      category: 'RDR2',
      assetPath: 'assets/avatars/rdr2_cover.jpg',
      tagLine: '"Outlaws for life."',
      accentColor: Color(0xFFB71C1C),
    ),

    // ── Hajime no Ippo ──────────────────────────────────────────────────────
    AvatarItem(
      id: 'ippo_makunouchi',
      name: 'Ippo Makunouchi',
      series: 'Hajime no Ippo',
      category: 'Hajime no Ippo',
      assetPath: 'assets/avatars/ippo_cover.png',
      tagLine: '"What does it mean to be strong?"',
      accentColor: Color(0xFF2979FF),
    ),
    AvatarItem(
      id: 'ippo_gym',
      name: 'Kamogawa Gym',
      series: 'Hajime no Ippo',
      category: 'Hajime no Ippo',
      assetPath: 'assets/avatars/ippo_visual.png',
      tagLine: '"Takamura, Ippo & Coach Kamogawa."',
      accentColor: Color(0xFFFF9100),
    ),

    // ── Anime Legends ───────────────────────────────────────────────────────
    AvatarItem(
      id: 'anime_l',
      name: 'L Lawliet',
      series: 'Death Note',
      category: 'Anime',
      assetPath: 'assets/avatars/anime_l.png',
      tagLine: '"Justice will prevail."',
      accentColor: Color(0xFF00E5FF),
    ),
    AvatarItem(
      id: 'anime_light',
      name: 'Light Yagami',
      series: 'Death Note',
      category: 'Anime',
      assetPath: 'assets/avatars/anime_light.jpg',
      tagLine: '"I am the God of the new world."',
      accentColor: Color(0xFF8B5CF6),
    ),
    AvatarItem(
      id: 'anime_death_note',
      name: 'Death Note',
      series: 'Death Note',
      category: 'Anime',
      assetPath: 'assets/avatars/anime_death_note.jpg',
      tagLine: '"The human whose name is written shall die."',
      accentColor: Color(0xFF9E9E9E),
    ),
    AvatarItem(
      id: 'anime_levi',
      name: 'Levi Ackerman',
      series: 'Attack on Titan',
      category: 'Anime',
      assetPath: 'assets/avatars/anime_levi.png',
      tagLine: '"Give up on your dreams and die."',
      accentColor: Color(0xFF00B0FF),
    ),
    AvatarItem(
      id: 'anime_gojo',
      name: 'Satoru Gojo',
      series: 'Jujutsu Kaisen',
      category: 'Anime',
      assetPath: 'assets/avatars/anime_gojo.png',
      tagLine: '"Throughout heaven and earth, I alone am the honored one."',
      accentColor: Color(0xFF7C4DFF),
    ),
    AvatarItem(
      id: 'anime_cyberpunk',
      name: 'David Martinez',
      series: 'Cyberpunk: Edgerunners',
      category: 'Anime',
      assetPath: 'assets/avatars/anime_cyberpunk.jpg',
      tagLine: '"I\'m built different."',
      accentColor: Color(0xFFFFD600),
    ),

    // ── Pulse Classics ──────────────────────────────────────────────────────
    AvatarItem(
      id: 'pulse_classic',
      name: 'Neon Pulse',
      series: 'Pulse Media',
      category: 'Pulse',
      assetPath: 'assets/play-button.webp',
      tagLine: '"Pure electric sound."',
      accentColor: Color(0xFF00E5FF),
    ),
    AvatarItem(
      id: 'pulse_rdr2',
      name: 'Frontier Outlaw',
      series: 'Pulse Media',
      category: 'Pulse',
      assetPath: 'assets/rdr2_styled.webp',
      tagLine: '"Crimson frontier edition."',
      accentColor: Color(0xFFE50914),
    ),
  ];

  final ValueNotifier<AvatarItem> currentAvatar = ValueNotifier<AvatarItem>(allAvatars.first);
  final ValueNotifier<String> userName = ValueNotifier<String>('Arthur Morgan');

  void init() {
    try {
      final box = Hive.box('settings_box');
      final savedId = box.get(_avatarKey, defaultValue: 'rdr2_arthur') as String;
      final savedName = box.get(_userNameKey, defaultValue: 'Arthur Morgan') as String;

      final matched = allAvatars.firstWhere(
        (a) => a.id == savedId,
        orElse: () => allAvatars.first,
      );

      currentAvatar.value = matched;
      userName.value = savedName;
    } catch (_) {}
  }

  void setAvatar(AvatarItem avatar) {
    currentAvatar.value = avatar;
    try {
      final box = Hive.box('settings_box');
      box.put(_avatarKey, avatar.id);
    } catch (_) {}
  }

  void setUserName(String name) {
    userName.value = name;
    try {
      final box = Hive.box('settings_box');
      box.put(_userNameKey, name);
    } catch (_) {}
  }
}
