import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/admin/admin_panel.dart';
import 'screens/home/quizzes_list_screen.dart';
import 'screens/home/quiz_play_screen.dart';

// Providers
import 'state/auth_state.dart';
import 'state/quiz_state.dart';

class QuizApp extends StatelessWidget {
  const QuizApp({super.key});

  @override
  Widget build(BuildContext context) {
    final Color seed = const Color(0xFF6C63FF);
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    final ThemeData baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(
        primary: const Color(0xFF00C2FF),
        secondary: const Color(0xFFB388FF),
        tertiary: const Color(0xFF7C4DFF),
      ),
      scaffoldBackgroundColor: const Color(0xFF0B1020),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0E1530),
        elevation: 0,
        centerTitle: true,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF161B33),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        hintStyle: TextStyle(color: Colors.white.withOpacity(0.6)),
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF161B33),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF00C2FF),
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState()),
        ChangeNotifierProvider(create: (_) => QuizState()),
      ],
      child: MaterialApp(
        title: 'Quizbit',
        debugShowCheckedModeBanner: false,
        theme: baseTheme,
        home: const SplashScreen(),
        routes: {
          LoginScreen.route: (_) => const LoginScreen(),
          SignupScreen.route: (_) => const SignupScreen(),
          HomeShell.route: (_) => const HomeShell(),
          ProfileScreen.route: (_) => const ProfileScreen(),
          AdminPanelScreen.route: (_) => const AdminPanelScreen(),
          QuizzesListScreen.route: (_) => const QuizzesListScreen(),
          QuizPlayScreen.route: (_) => const QuizPlayScreen(),
        },
      ).animate().fadeIn(duration: 400.ms),
    );
  }
}
