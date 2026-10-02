import 'package:drive_fe/features/drive/screens/drive_screen.dart';
import 'package:drive_fe/features/user/screen/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'core/theme/app_colors.dart';
import 'data/repositories/drive_repository.dart';
import 'features/drive/bloc/drive_bloc.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DriveApp());
}

class DriveApp extends StatelessWidget {
  const DriveApp({super.key});
  @override
  Widget build(BuildContext context) {
    return RepositoryProvider(
      create: (_) => DriveRepository(),
      child: BlocProvider(
        create: (context) => DriveCubit(context.read<DriveRepository>()),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'Vault-Drive',
          themeMode: ThemeMode.system,
          theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent), scaffoldBackgroundColor: AppColors.cloud),
          darkTheme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent, brightness: Brightness.dark), scaffoldBackgroundColor: AppColors.ink),
          home: const AuthGate(),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}
class _AuthGateState extends State<AuthGate> {
  late Future<bool> _session;
  bool _driveLoaded = false;
  @override
  void initState() { super.initState(); _session = context.read<DriveRepository>().hasValidSession(); }
  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _session,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (snapshot.data == true) {
        if (!_driveLoaded) {
          _driveLoaded = true;
          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) context.read<DriveCubit>().load(); });
        }
        return const DriveScreen();
      }
      return const LoginScreen();
    },
  );
}
