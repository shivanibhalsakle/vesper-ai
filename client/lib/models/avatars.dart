/// The illustrated avatars a user can pick instead of uploading a photo.
///
/// The id is what the backend stores, so ids must never change once shipped
/// (they are lowercase letters, digits and underscores, which is what the API
/// accepts). The artwork lives in `assets/avatars/GROUP/ID.webp` and is made
/// by tool/build_avatars.py.
class AvatarOption {
  final String id;
  final String label;
  final String asset;

  const AvatarOption(this.id, this.label, this.asset);
}

class AvatarGroup {
  final String id;
  final String title;
  final List<AvatarOption> avatars;

  const AvatarGroup(this.id, this.title, this.avatars);
}

/// The groups in the order they are shown.
const kAvatarGroups = [
  AvatarGroup('wanderlust', 'Wanderlust', [
    AvatarOption('wanderlust_01', 'Smiling traveller in sunglasses',
        'assets/avatars/wanderlust/wanderlust_01.webp'),
    AvatarOption('wanderlust_02', 'Photographer with a camera',
        'assets/avatars/wanderlust/wanderlust_02.webp'),
    AvatarOption('wanderlust_03', 'Hiker in a beanie',
        'assets/avatars/wanderlust/wanderlust_03.webp'),
    AvatarOption('wanderlust_04', 'Dreamer resting her chin on her hand',
        'assets/avatars/wanderlust/wanderlust_04.webp'),
    AvatarOption('wanderlust_05', 'Curly-haired adventurer',
        'assets/avatars/wanderlust/wanderlust_05.webp'),
    AvatarOption('wanderlust_06', 'Winking explorer in a cap',
        'assets/avatars/wanderlust/wanderlust_06.webp'),
    AvatarOption('wanderlust_07', 'Thoughtful wanderer in a sun hat',
        'assets/avatars/wanderlust/wanderlust_07.webp'),
    AvatarOption('wanderlust_08', 'Bearded mountaineer',
        'assets/avatars/wanderlust/wanderlust_08.webp'),
  ]),
  AvatarGroup('wilderness', 'Wilderness', [
    AvatarOption('wilderness_snake', 'Explorer snake in a hat',
        'assets/avatars/wilderness/wilderness_snake.webp'),
    AvatarOption('wilderness_monkey', 'Monkey with a golden compass',
        'assets/avatars/wilderness/wilderness_monkey.webp'),
    AvatarOption('wilderness_retriever', 'Golden retriever at sunset',
        'assets/avatars/wilderness/wilderness_retriever.webp'),
    AvatarOption('wilderness_wolf', 'Howling wolf',
        'assets/avatars/wilderness/wilderness_wolf.webp'),
    AvatarOption('wilderness_panda', 'Panda on a lakeside bench',
        'assets/avatars/wilderness/wilderness_panda.webp'),
    AvatarOption('wilderness_tiger', 'Tiger on the savanna',
        'assets/avatars/wilderness/wilderness_tiger.webp'),
    AvatarOption('wilderness_beaver', 'Beaver by the lake',
        'assets/avatars/wilderness/wilderness_beaver.webp'),
    AvatarOption('wilderness_cat', 'Content cat in a red scarf',
        'assets/avatars/wilderness/wilderness_cat.webp'),
    AvatarOption('wilderness_dolphin', 'Dolphin on the reef',
        'assets/avatars/wilderness/wilderness_dolphin.webp'),
    AvatarOption('wilderness_horse', 'Galloping horse',
        'assets/avatars/wilderness/wilderness_horse.webp'),
  ]),
  AvatarGroup('moods', 'Moods', [
    AvatarOption('moods_pastel', 'Pastel mood', 'assets/avatars/moods/moods_pastel.webp'),
    AvatarOption('moods_magenta', 'Magenta mood', 'assets/avatars/moods/moods_magenta.webp'),
    AvatarOption('moods_ocean', 'Ocean mood', 'assets/avatars/moods/moods_ocean.webp'),
    AvatarOption('moods_peach', 'Peach mood', 'assets/avatars/moods/moods_peach.webp'),
    AvatarOption('moods_mint', 'Mint mood', 'assets/avatars/moods/moods_mint.webp'),
    AvatarOption('moods_vanilla', 'Vanilla mood', 'assets/avatars/moods/moods_vanilla.webp'),
  ]),
];

/// The avatar with this id, or null (no id, or one this version doesn't
/// know, such as one from a newer app).
AvatarOption? avatarById(String? id) {
  if (id == null) return null;
  for (final group in kAvatarGroups) {
    for (final avatar in group.avatars) {
      if (avatar.id == id) return avatar;
    }
  }
  return null;
}
