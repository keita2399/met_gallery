import 'bgm_audio_stub.dart' if (dart.library.js_interop) 'bgm_audio_web.dart';

class BgmTrack {
  final String title;
  final String composer;
  final String url;
  const BgmTrack({required this.title, required this.composer, required this.url});
}

class BgmService {
  static final BgmService _instance = BgmService._();
  static BgmService get instance => _instance;
  BgmService._();

  int _currentIndex = 0;
  bool _playing = false;

  // Vercelにホストされた著作権フリー音源
  static const tracks = <BgmTrack>[
    BgmTrack(
      title: 'ジムノペディ 第1番',
      composer: 'エリック・サティ',
      url: 'audio/gymnopedia.mp3',
    ),
    BgmTrack(
      title: '月の光',
      composer: 'クロード・ドビュッシー',
      url: 'audio/clair_de_lune.mp3',
    ),
    BgmTrack(
      title: 'アラベスク 第1番・第2番',
      composer: 'クロード・ドビュッシー',
      url: 'audio/arabesque.mp3',
    ),
  ];

  BgmTrack get currentTrack => tracks[_currentIndex];
  bool get isPlaying => _playing;

  Future<void> play() async {
    _playing = true;
    playAudioWeb(tracks[_currentIndex].url);
  }

  Future<void> pause() async {
    _playing = false;
    pauseAudioWeb();
  }

  Future<void> toggle() async {
    if (_playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> next() async {
    _currentIndex = (_currentIndex + 1) % tracks.length;
    _playing = true;
    playAudioWeb(tracks[_currentIndex].url);
  }

  Future<void> previous() async {
    _currentIndex = (_currentIndex - 1 + tracks.length) % tracks.length;
    _playing = true;
    playAudioWeb(tracks[_currentIndex].url);
  }
}
