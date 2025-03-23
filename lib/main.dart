import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pothole/page/login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await openHiveBox('mybox');
  runApp(const MyApp());
}

Future<void> openHiveBox(String boxName) async {
  if (!kIsWeb && !Hive.isBoxOpen(boxName))
    Hive.init((await getApplicationDocumentsDirectory()).path);
  await Hive.openBox(boxName);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Road Safety App',
      debugShowCheckedModeBanner: false,
      home: Login(),
    );
  }
}