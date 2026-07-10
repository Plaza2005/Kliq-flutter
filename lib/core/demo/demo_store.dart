import 'dart:math';

/// In-memory seeded dataset used when the app runs in demo mode.
/// All records are plain JSON maps shaped like the Node API responses,
/// so feature code cannot tell demo and live apart.
class DemoStore {
  DemoStore._() {
    _seed();
  }

  static final instance = DemoStore._();
  final _rng = Random(42);

  late Map<String, dynamic> me;
  final users = <Map<String, dynamic>>[];
  final posts = <Map<String, dynamic>>[];
  final comments = <String, List<Map<String, dynamic>>>{};
  final stories = <Map<String, dynamic>>[];
  final reels = <Map<String, dynamic>>[];
  final tubeVideos = <Map<String, dynamic>>[];
  final streamShows = <Map<String, dynamic>>[];
  final liveStreams = <Map<String, dynamic>>[];
  final products = <Map<String, dynamic>>[];
  final communities = <Map<String, dynamic>>[];
  final conversations = <Map<String, dynamic>>[];
  final messages = <String, List<Map<String, dynamic>>>{};
  final notifications = <Map<String, dynamic>>[];
  final walletTransactions = <Map<String, dynamic>>[];
  final likedPostIds = <String>{};
  final savedPostIds = <String>{};
  final followedUserIds = <String>{};

  Map<String, dynamic> wallet = {};

  int _idCounter = 1000;
  String nextId(String prefix) => '${prefix}_demo_${_idCounter++}';

  static const sampleVideos = [
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerBlazes.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerEscapes.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerFun.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ForBiggerJoyrides.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/Sintel.mp4',
    'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/TearsOfSteel.mp4',
  ];

  static String img(int seed, {int w = 800, int h = 800}) =>
      'https://picsum.photos/seed/kliq$seed/$w/$h';

  static String avatar(int n) => 'https://i.pravatar.cc/300?img=${(n % 70) + 1}';

  DateTime _ago({int days = 0, int hours = 0, int minutes = 0}) =>
      DateTime.now().subtract(
          Duration(days: days, hours: hours, minutes: minutes));

  void _seed() {
    // ── Users ──────────────────────────────────────────────────────────────
    const names = [
      ['ndapewa', 'Ndapewa Amukoto'],
      ['tjipangandjara', 'Tjipa Ngandjara'],
      ['maria_shilongo', 'Maria Shilongo'],
      ['dj_kavango', 'DJ Kavango'],
      ['windhoek_eats', 'Windhoek Eats'],
      ['nam_wildlife', 'Namibia Wildlife'],
      ['kuku_fashion', 'Kuku Fashion'],
      ['swakop_surfer', 'Swakop Surfer'],
      ['oshiwambo_kitchen', 'Oshiwambo Kitchen'],
      ['brave_warriors_fan', 'Brave Warriors Fan'],
      ['kalahari_tech', 'Kalahari Tech'],
      ['erongo_artist', 'Erongo Artist'],
    ];
    for (var i = 0; i < names.length; i++) {
      users.add({
        'id': 'u_demo_$i',
        'username': names[i][0],
        'displayName': names[i][1],
        'avatarUrl': avatar(i + 3),
        'bio': 'Creating on KLIQ 🇳🇦 · ${names[i][1]}',
        'isVerified': i < 5,
        'tier': i < 2 ? 3 : (i < 6 ? 2 : 1),
        'followerCount': 1200 + _rng.nextInt(90000),
        'followingCount': 80 + _rng.nextInt(900),
        'postCount': 12 + _rng.nextInt(120),
      });
    }
    followedUserIds.addAll(['u_demo_0', 'u_demo_2', 'u_demo_4', 'u_demo_5']);

    me = {
      'id': 'u_demo_me',
      'username': 'demo_creator',
      'displayName': 'Demo Creator',
      'email': 'demo@kliq.app',
      'avatarUrl': avatar(66),
      'bio': 'Exploring KLIQ in demo mode ✨',
      'isVerified': true,
      'tier': 3,
      'followerCount': 15400,
      'followingCount': 312,
      'postCount': 48,
      'onboardingComplete': true,
    };

    // ── Posts ──────────────────────────────────────────────────────────────
    const captions = [
      'Sunset over the dunes never gets old 🌅 #namibia #sossusvlei',
      'New drop coming this Friday 👀🔥 #fashion #kliq',
      'Kapana at Single Quarters — nothing beats it #windhoek #food',
      'Studio session all night 🎧 #music #producer',
      'Match day! Brave Warriors 🇳🇦⚽ #football',
      'Coastal mornings in Swakopmund 🌊 #swakop',
      'Behind the scenes of the new collection 📸',
      'Cheetah conservation update — she is thriving 🐆 #wildlife',
      'Threads: hot take — kapana > any restaurant. Discuss. 🔥',
      'Etosha at golden hour is a different planet ✨ #etosha',
      'New mural finished in Katutura today 🎨 #art',
      'Tech meetup this Saturday in Windhoek — who is coming? 💻',
    ];
    for (var i = 0; i < 24; i++) {
      final author = users[i % users.length];
      final isText = i % 8 == 7;
      final id = 'p_demo_$i';
      posts.add({
        'id': id,
        'author': author,
        'body': captions[i % captions.length],
        'mediaUrls': isText ? <String>[] : [img(i, w: 900, h: i % 3 == 0 ? 1100 : 900)],
        'mediaType': isText ? 'text' : 'image',
        'likeCount': 40 + _rng.nextInt(4000),
        'commentCount': 3 + _rng.nextInt(200),
        'shareCount': _rng.nextInt(80),
        'isLiked': false,
        'isSaved': false,
        'location': i % 4 == 0 ? 'Windhoek, Namibia' : null,
        'createdAt': _ago(hours: 2 + i * 5).toIso8601String(),
      });
      comments[id] = List.generate(3, (c) => {
            'id': 'c_${id}_$c',
            'author': users[(i + c + 1) % users.length],
            'body': ['🔥🔥🔥', 'Love this!', 'Amazing shot 👏', 'Where is this?'][c % 4],
            'likeCount': _rng.nextInt(50),
            'createdAt': _ago(hours: 1 + c).toIso8601String(),
          });
    }

    // ── Stories ────────────────────────────────────────────────────────────
    for (var i = 0; i < 7; i++) {
      stories.add({
        'id': 's_demo_$i',
        'author': users[i],
        'items': [
          {
            'id': 'si_demo_${i}_0',
            'mediaUrl': img(100 + i, w: 720, h: 1280),
            'mediaType': 'image',
            'createdAt': _ago(hours: i + 1).toIso8601String(),
          }
        ],
        'seen': i > 4,
      });
    }

    // ── Reels ──────────────────────────────────────────────────────────────
    for (var i = 0; i < 8; i++) {
      reels.add({
        'id': 'r_demo_$i',
        'author': users[(i + 2) % users.length],
        'videoUrl': sampleVideos[i % sampleVideos.length],
        'thumbnailUrl': img(200 + i, w: 720, h: 1280),
        'caption': captions[(i + 3) % captions.length],
        'soundName': 'Original audio · ${users[(i + 2) % users.length]['username']}',
        'likeCount': 200 + _rng.nextInt(20000),
        'commentCount': 10 + _rng.nextInt(800),
        'shareCount': _rng.nextInt(400),
        'viewCount': 1000 + _rng.nextInt(200000),
        'isLiked': false,
        'createdAt': _ago(days: i).toIso8601String(),
      });
    }

    // ── KliqTube ───────────────────────────────────────────────────────────
    const tubeTitles = [
      'Full Vlog: Road trip from Windhoek to Swakopmund',
      'How I produce Afro-house — full breakdown',
      'Namibia Wildlife Documentary: The Cheetahs of Otjiwarongo',
      'Cooking Oshifima like a pro — step by step',
      'Brave Warriors Highlights & Analysis',
      'Building a startup in Namibia — my story',
      'Fashion Week Windhoek 2026 — full show',
      'Surfing the Skeleton Coast',
    ];
    for (var i = 0; i < tubeTitles.length; i++) {
      tubeVideos.add({
        'id': 't_demo_$i',
        'author': users[(i + 1) % users.length],
        'title': tubeTitles[i],
        'description':
            'Full-length KliqTube upload. ${tubeTitles[i]} — enjoy and subscribe!',
        'videoUrl': sampleVideos[(i + 2) % sampleVideos.length],
        'thumbnailUrl': img(300 + i, w: 1280, h: 720),
        'duration': 300 + _rng.nextInt(2400),
        'viewCount': 500 + _rng.nextInt(120000),
        'likeCount': 50 + _rng.nextInt(9000),
        'createdAt': _ago(days: i * 3 + 1).toIso8601String(),
      });
    }

    // ── KliqStream (shows/series catalogue) ────────────────────────────────
    const shows = [
      ['Desert Kings', 'Drama'],
      ['Katutura Nights', 'Reality'],
      ['The Braai Master', 'Cooking'],
      ['Namib Untamed', 'Documentary'],
      ['Startup Hustle NA', 'Business'],
      ['Kwaito Chronicles', 'Music'],
    ];
    for (var i = 0; i < shows.length; i++) {
      streamShows.add({
        'id': 'ks_demo_$i',
        'title': shows[i][0],
        'category': shows[i][1],
        'description':
            '${shows[i][0]} — an original KliqStream ${shows[i][1].toLowerCase()} series.',
        'posterUrl': img(400 + i, w: 600, h: 900),
        'bannerUrl': img(450 + i, w: 1600, h: 900),
        'rating': 3.5 + _rng.nextInt(15) / 10.0,
        'year': 2024 + i % 3,
        'episodes': List.generate(6, (e) => {
              'id': 'kse_demo_${i}_$e',
              'title': 'Episode ${e + 1}',
              'videoUrl': sampleVideos[(i + e) % sampleVideos.length],
              'thumbnailUrl': img(460 + i * 10 + e, w: 1280, h: 720),
              'duration': 1200 + _rng.nextInt(1500),
            }),
        'inMyList': i < 2,
      });
    }

    // ── Live streams ───────────────────────────────────────────────────────
    const liveTitles = [
      ['Live from the studio 🎧 making beats', 'Music'],
      ['Match watch-along! Brave Warriors vs Ghana', 'Sports'],
      ['Cooking kapana LIVE — ask me anything', 'Food'],
    ];
    for (var i = 0; i < liveTitles.length; i++) {
      liveStreams.add({
        'id': 'live_demo_$i',
        'title': liveTitles[i][0],
        'category': liveTitles[i][1],
        'thumbnailUrl': img(500 + i, w: 1280, h: 720),
        'viewerCount': 40 + _rng.nextInt(2000),
        'startedAt': _ago(minutes: 12 + i * 9).toIso8601String(),
        'isLive': true,
        'user': users[i * 3],
      });
    }

    // ── Marketplace ────────────────────────────────────────────────────────
    const productNames = [
      ['Handwoven Basket — Oshiwambo design', 450],
      ['KLIQ Creator Hoodie', 650],
      ['Namib Desert Photo Print (A2)', 380],
      ['Afro-house Sample Pack Vol. 3', 200],
      ['Beaded Necklace — Himba style', 320],
      ['Kapana Spice Mix (3 pack)', 120],
      ['Preset Pack: Golden Hour Namibia', 150],
      ['Swakop Surf Co. Cap', 280],
      ['Digital Art Commission (portrait)', 900],
      ['Online Course: Content Creation 101', 1200],
    ];
    for (var i = 0; i < productNames.length; i++) {
      products.add({
        'id': 'prod_demo_$i',
        'seller': users[(i + 4) % users.length],
        'name': productNames[i][0],
        'description':
            '${productNames[i][0]} — sold directly through the KLIQ Marketplace.',
        'price': productNames[i][1],
        'currency': 'N\$',
        'imageUrls': [img(600 + i, w: 900, h: 900)],
        'category': i % 2 == 0 ? 'Physical' : 'Digital',
        'rating': 3.8 + _rng.nextInt(12) / 10.0,
        'salesCount': _rng.nextInt(300),
        'inStock': true,
      });
    }

    // ── Communities ────────────────────────────────────────────────────────
    const comms = [
      ['Namibia Creators Hub', 'For every creator in Namibia 🇳🇦', 4821],
      ['Windhoek Foodies', 'Kapana, braai & everything tasty', 2310],
      ['NamTech', 'Developers & founders of Namibia', 1105],
      ['Wildlife Photographers NA', 'Etosha and beyond 📷', 3407],
      ['Afro-house Producers', 'Beats, collabs, feedback', 1980],
    ];
    for (var i = 0; i < comms.length; i++) {
      communities.add({
        'id': 'com_demo_$i',
        'name': comms[i][0],
        'description': comms[i][1],
        'memberCount': comms[i][2],
        'avatarUrl': img(700 + i, w: 400, h: 400),
        'bannerUrl': img(750 + i, w: 1600, h: 600),
        'isJoined': i < 3,
        'isPrivate': i == 4,
        'channels': ['General', 'Announcements', 'Media', 'Events', 'Off-topic'],
      });
    }

    // ── Messaging ──────────────────────────────────────────────────────────
    for (var i = 0; i < 4; i++) {
      final other = users[i * 2];
      final convId = 'conv_demo_$i';
      conversations.add({
        'id': convId,
        'user': other,
        'lastMessage': ['See you at the meetup!', 'That reel was 🔥', 'Sending the files now', 'Thanks for the follow!'][i],
        'lastMessageAt': _ago(hours: i * 6 + 1).toIso8601String(),
        'unreadCount': i == 0 ? 2 : 0,
      });
      messages[convId] = [
        {
          'id': 'm_${convId}_0',
          'senderId': other['id'],
          'body': 'Hey! Loved your latest post 👏',
          'createdAt': _ago(hours: i * 6 + 3).toIso8601String(),
        },
        {
          'id': 'm_${convId}_1',
          'senderId': 'u_demo_me',
          'body': 'Thanks! Working on more content this week.',
          'createdAt': _ago(hours: i * 6 + 2).toIso8601String(),
        },
        {
          'id': 'm_${convId}_2',
          'senderId': other['id'],
          'body': conversations[i]['lastMessage'],
          'createdAt': conversations[i]['lastMessageAt'],
        },
      ];
    }

    // ── Notifications ──────────────────────────────────────────────────────
    const notifs = [
      ['like', 'liked your post'],
      ['follow', 'started following you'],
      ['comment', 'commented: This is amazing! 🔥'],
      ['gift', 'sent you a Diamond gift 💎'],
      ['sale', 'bought "Preset Pack: Golden Hour Namibia"'],
      ['like', 'liked your reel'],
      ['follow', 'started following you'],
      ['comment', 'commented: Where can I buy this?'],
    ];
    for (var i = 0; i < notifs.length; i++) {
      notifications.add({
        'id': 'n_demo_$i',
        'type': notifs[i][0],
        'actor': users[(i + 1) % users.length],
        'message': notifs[i][1],
        'read': i > 3,
        'createdAt': _ago(hours: i * 4 + 1).toIso8601String(),
      });
    }

    // ── Wallet ─────────────────────────────────────────────────────────────
    wallet = {
      'tokens': 2450,
      'diamonds': 830,
      'balance': 1265.50,
      'currency': 'N\$',
    };
    const txs = [
      ['gift_received', 'Received Crown gift from @ndapewa', 100],
      ['purchase', 'Bought 500 tokens', -500],
      ['sale', 'Marketplace sale: Creator Hoodie', 650],
      ['gift_sent', 'Sent Rocket gift to @dj_kavango', -200],
      ['payout', 'Withdrawal to bank', -800],
      ['subscription', 'Subscriber payment from @kuku_fashion', 45],
    ];
    for (var i = 0; i < txs.length; i++) {
      walletTransactions.add({
        'id': 'tx_demo_$i',
        'type': txs[i][0],
        'description': txs[i][1],
        'amount': txs[i][2],
        'createdAt': _ago(days: i, hours: 3).toIso8601String(),
      });
    }
  }

  Map<String, dynamic>? findUser(String idOrUsername) {
    if (idOrUsername == me['id'] || idOrUsername == me['username']) return me;
    for (final u in users) {
      if (u['id'] == idOrUsername || u['username'] == idOrUsername) return u;
    }
    return null;
  }
}
