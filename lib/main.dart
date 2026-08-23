import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'providers/app_provider.dart';
import 'services/local_storage_service.dart';
import 'services/memorize_audio_handler.dart';
import 'services/supabase_service.dart';
import 'screens/player_screen.dart';
import 'theme/app_colors.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await AudioService.init(
    builder: () => MemorizeAudioHandler(),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.memorize.audio',
      androidNotificationChannelName: 'Memorize Playback',
      androidNotificationChannelDescription: 'Phrase audio playback',
      androidStopForegroundOnPause: false,
      androidNotificationIcon: 'mipmap/ic_launcher',
      notificationColor: Color(0xFF0B307B),
    ),
  );

  final session = await AudioSession.instance;
  await session.configure(const AudioSessionConfiguration(
    avAudioSessionCategory: AVAudioSessionCategory.playback,
    avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.none,
    avAudioSessionMode: AVAudioSessionMode.spokenAudio,
    avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
    avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
    androidAudioAttributes: AndroidAudioAttributes(
      contentType: AndroidAudioContentType.speech,
      usage: AndroidAudioUsage.media,
    ),
    androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
    androidWillPauseWhenDucked: false,
  ));
  await session.setActive(true);

  await LocalStorageService.init();

  await Supabase.initialize(
    url: SupabaseService.apiUrl,
    anonKey: SupabaseService.apiKey,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: AppColors.stageBg,
      systemNavigationBarIconBrightness: Brightness.light,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: const MemorizeApp(),
    ),
  );
}

class MemorizeApp extends StatelessWidget {
  const MemorizeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Memorize',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0B307B),
          primary: const Color(0xFF0B307B),
          secondary: const Color(0xFF2A84CA),
        ),
        scaffoldBackgroundColor: AppColors.stageBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
        ),
      ),
      home: const PlayerScreen(),
    );
  }
}
