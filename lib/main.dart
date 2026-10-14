import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'injection_container.dart' as di;
import 'features/pos/presentation/pos_page.dart';
import 'features/pos/domain/pos_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ZivloApp());
}

class ZivloApp extends StatefulWidget {
  const ZivloApp({super.key});
  @override
  State<ZivloApp> createState() => _ZivloAppState();
}

class _ZivloAppState extends State<ZivloApp> {
  late Future<void> _initialization;
  @override
  void initState() { super.initState(); _initialization = di.initializeDependencies(); }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Zivlo Perú',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF123C35)),
    home: FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(body: SafeArea(child: Center(child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.storage_outlined, size: 52),
            const SizedBox(height: 20),
            const Text('No pudimos abrir los datos del negocio', style: TextStyle(fontSize: 22), textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Text(snapshot.error is PosException ? (snapshot.error as PosException).message : 'Revisa el almacenamiento disponible y vuelve a intentar. No se reiniciaron los datos.', textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: () => setState(() => _initialization = di.initializeDependencies()), child: const Text('Volver a intentar')),
          ]),
        ))));
        if (snapshot.connectionState != ConnectionState.done) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        return MultiBlocProvider(providers: di.getBlocProviders(), child: const PosPage());
      },
    ),
  );
}
