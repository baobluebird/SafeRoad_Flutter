import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:pothole/screens/detection/cracks.dart';
import 'package:pothole/screens/detection/holes.dart';
import 'dart:ui' as ui;

import 'package:pothole/screens/detection/road.dart';
import 'package:pothole/screens/detection/search.dart';

import 'damage.dart';

class ListDetectionScreen extends StatefulWidget {
  const ListDetectionScreen({Key? key}) : super(key: key);

  @override
  State<ListDetectionScreen> createState() => _ListDetectionScreenState();
}

class _ListDetectionScreenState extends State<ListDetectionScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Image _largeHoleIcon;
  late Image _largeCrackIcon;
  late Image _maintainIcon;
  late Image _damageIcon;
  bool _isLoading = true;

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))!.buffer.asUint8List();
  }

  Future<void> _loadCustomIcons() async {
    final Uint8List largeHole = await getBytesFromAsset('assets/images/large_hole.png', 40);
    final Uint8List largeCrack = await getBytesFromAsset('assets/images/large_crack.png', 35);
    final Uint8List maintain = await getBytesFromAsset('assets/images/fix_road.png', 35);
    final Uint8List damage = await getBytesFromAsset('assets/images/damage.png', 35);
    setState(() {
      _largeHoleIcon = Image.memory(largeHole);
      _largeCrackIcon = Image.memory(largeCrack);
      _maintainIcon = Image.memory(maintain);
      _damageIcon = Image.memory(damage);
    });
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await Future.wait([
      _loadCustomIcons(),
      Future(() {
        _tabController = TabController(length: 5, vsync: this);
      }),
    ]);
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : DefaultTabController(
        length: 2,
        child: Column(

          children: [
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(icon: _largeHoleIcon, text: 'Ổ gà'),
                Tab(icon: _largeCrackIcon, text: 'Vết Nứt'),
                Tab(icon: _maintainIcon, text: 'Bảo trì'),
                Tab(icon: _damageIcon, text: 'Damage'),
                Tab(icon: const Icon(Icons.search), text: 'Search'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  HolesScreen(),
                  CrackScreen(),
                  MaintainRoadScreen(),
                  DamageRoadScreen(),
                  SearchScreen()
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
