import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:pothole/screens/detection/list_detections.dart';

import '../screens/user/admin.dart';
import '../screens/tab/maintain_map.dart';
import '../screens/tab/management.dart';
import '../screens/tab/map.dart';
import '../screens/user/profile_user.dart';
import '../screens/tab/track.dart';
import '../screens/tab/video.dart';
import '../services/user_service.dart';
import 'login.dart';

class CustomPageRoute<T> extends MaterialPageRoute<T> {
  CustomPageRoute({
    required WidgetBuilder builder,
    RouteSettings? settings,
  }) : super(builder: builder, settings: settings);

  @override
  RectTween? createRectTween(Rect? begin, Rect? end) {
    return null; // Tắt hoạt hình Hero
  }
}

class AdminHome extends StatefulWidget {
  const AdminHome({Key? key}) : super(key: key);

  @override
  State<AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<AdminHome> {
  final myBox = Hive.box('myBox');
  late String storedToken;
  final List<Widget> tabs = [
    MapScreen(),
    TrackingMapScreen(),
    ListDetectionScreen(),
    MaintainMapScreen(),
    ManagementScreen(),
    VideoScreen(),
  ];
  int currentTabIndex = 0;
  String serverMessage = '';
  String _nameUser = '';

  Future<void> clearHiveBox(String boxName) async {
    var box = await Hive.openBox(boxName);
    await box.clear();
  }

  Future<void> _logout(String token) async {
    try {
      final Map<String, dynamic> response = await LogoutService.logout(token);

      print('Response status: ${response['status']}');
      print('Response body: ${response['message']}');
      if (response['status'] == "OK") {
        setState(() {
          serverMessage = response['message'];
        });
        print(serverMessage);
      } else if (mounted) {
        setState(() {
          serverMessage = response['message'];
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          serverMessage = 'Error: $error';
        });
        print('Error: $error');
        print(serverMessage);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _nameUser = myBox.get('name', defaultValue: '');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white60,
          centerTitle: true,
          title: Text('DUTSAFEROAD',
          style: GoogleFonts.bebasNeue(
            textStyle: const TextStyle(
              fontSize: 30,
              color: Colors.black,
              letterSpacing: 1.5,
            ),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              decoration: const BoxDecoration(
                color: Colors.blue,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipOval(
                    child: Container(
                      width: 80,
                      height: 80,
                      color: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _nameUser,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              title: const Text('Profile'),
              leading: const Icon(Icons.person),
              onTap: () async {
                Navigator.push(
                  context,
                  CustomPageRoute(
                    builder: (context) => const ProfileUserScreen(),
                    settings: const RouteSettings(arguments: null),
                  ),
                );
              },
            ),
            ListTile(
              title: const Text('Log out'),
              leading: const Icon(
                Icons.logout,
              ),
              onTap: () async {
                storedToken = await myBox.get('token', defaultValue: '');
                if (storedToken != '') {
                  await _logout(storedToken);
                  await clearHiveBox('myBox');
                } else {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const Login()),
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Logout successfully'),
                    duration: const Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const Login()),
                );
              },
            ),
          ],
        ),
      ),
      body: IndexedStack(
        index: currentTabIndex,
        children: tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: currentTabIndex,
        onTap: (currentIndex) {
          setState(() {
            currentTabIndex = currentIndex;
          });
        },
        selectedLabelStyle: const TextStyle(color: Colors.black45),
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Map',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.drive_eta),
            label: 'Drive',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'List',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.add_road),
            label: 'Maintain',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.manage_accounts),
            label: 'Manage',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.video_collection_outlined),
            label: 'RTSP',
          ),
        ],
      ),
    ),
    );
  }
}