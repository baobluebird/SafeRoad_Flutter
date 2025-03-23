import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../screens/map.dart';
import '../screens/map_for_user.dart';
import '../screens/track.dart';
import '../services/login_service.dart';
import 'login.dart';

class UserHome extends StatefulWidget {
  const UserHome({Key? key}) : super(key: key);

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  final myBox = Hive.box('myBox');
  late String storedToken;
  var Tabs = [];
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
    Tabs = [
      MapUserScreen(),
      TrackingMapScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Road Safety'),
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
                    const CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: Colors.blue,
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
        body: Tabs[currentTabIndex],
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
              label: 'Tracking',
            ),
          ],
        ),
      ),
    );
  }
}
