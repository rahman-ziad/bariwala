import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart' as geolocator;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_screen.dart';
import 'membership_screen.dart';
import 'my_properties_screen.dart';
import 'home_tab_screen.dart';
import 'wishlist_screen.dart';
import 'profile_screen.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 2; // Home in middle
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String _userLocation = 'Fetching your location...';
  final String _barikoiApiKey = 'bkoi_3b6583584c58bee36ae766bb9cfe4e807f0e94f90ad1196baf1d73a1a8b8840f';
  geolocator.Position? _lastPosition;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
  }

  Future<void> _fetchUserLocation() async {
    try {
      bool serviceEnabled = await geolocator.Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _userLocation = 'Location services disabled.');
        return;
      }

      geolocator.LocationPermission permission = await geolocator.Geolocator.checkPermission();
      if (permission == geolocator.LocationPermission.denied) {
        permission = await geolocator.Geolocator.requestPermission();
        if (permission != geolocator.LocationPermission.whileInUse && permission != geolocator.LocationPermission.always) {
          setState(() => _userLocation = 'Please grant location permission.');
          return;
        }
      }

      if (permission == geolocator.LocationPermission.deniedForever) {
        setState(() => _userLocation = 'Permission denied forever.');
        return;
      }

      geolocator.Position position = await geolocator.Geolocator.getCurrentPosition(
        desiredAccuracy: geolocator.LocationAccuracy.high,
        forceAndroidLocationManager: true,
      ).timeout(Duration(seconds: 10), onTimeout: () {
        throw Exception('Location fetch timed out');
      });

      final prefs = await SharedPreferences.getInstance();
      double? cachedLat = prefs.getDouble('last_lat');
      double? cachedLng = prefs.getDouble('last_lng');
      String? cachedJson = prefs.getString('last_json');

      bool locationChanged = cachedLat == null || cachedLng == null ||
          geolocator.Geolocator.distanceBetween(cachedLat, cachedLng, position.latitude, position.longitude) > 10;

      if (!locationChanged && cachedJson != null && cachedJson != '{}') {
        final data = jsonDecode(cachedJson);
        setState(() {
          _userLocation = '${data['place']['area']}, ${data['place']['city']}\n${data['place']['address_components']['house'] ?? ''} ${data['place']['address_components']['road'] ?? ''}';
          _lastPosition = geolocator.Position(
            latitude: cachedLat,
            longitude: cachedLng,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        });
        return;
      }

      final url =
          'https://barikoi.xyz/v2/api/search/reverse/geocode?api_key=$_barikoiApiKey&longitude=${position.longitude}&latitude=${position.latitude}&district=true&post_code=true&country=true&sub_district=true&union=true&pauroshova=true&location_type=true&division=true&address=true&area=true&bangla=true';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String displayText = '${data['place']['area']}, ${data['place']['city']}\n${data['place']['address_components']['house'] ?? ''} ${data['place']['address_components']['road'] ?? ''}';
        setState(() {
          _userLocation = displayText;
          _lastPosition = position;
        });
        await prefs.setDouble('last_lat', position.latitude);
        await prefs.setDouble('last_lng', position.longitude);
        await prefs.setString('last_json', jsonEncode(data));
      } else {
        setState(() {
          _userLocation = 'Lat: ${position.latitude}, Lng: ${position.longitude}';
          _lastPosition = position;
        });
        await prefs.setDouble('last_lat', position.latitude);
        await prefs.setDouble('last_lng', position.longitude);
        await prefs.setString('last_json', '{}');
      }
    } catch (e) {
      print('Location error: $e');
      setState(() => _userLocation = 'Error: $e');
    }
  }

  Future<void> _logout() async {
    try {
      await _auth.signOut();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => AuthScreen()),
            (Route<dynamic> route) => false,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Logout failed: $e')));
    }
  }

  void _showLocationBottomSheet(BuildContext context) {
    LatLng currentLocation = _lastPosition != null
        ? LatLng(_lastPosition!.latitude, _lastPosition!.longitude)
        : LatLng(23.8103, 90.4125);

    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: 500,
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Your Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Expanded(
                child: FlutterMap(
                  options: MapOptions(
                    center: currentLocation,
                    zoom: 14.0,
                    onTap: (tapPosition, point) async {
                      await _updateLocation(geolocator.Position(
                        latitude: point.latitude,
                        longitude: point.longitude,
                        timestamp: DateTime.now(),
                        accuracy: 0,
                        altitude: 0,
                        heading: 0,
                        speed: 0,
                        speedAccuracy: 0,
                        altitudeAccuracy: 0,
                        headingAccuracy: 0,
                      ));
                      Navigator.pop(context);
                    },
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      subdomains: ['a', 'b', 'c'],
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 40.0,
                          height: 40.0,
                          point: currentLocation,
                          child: Icon(Icons.location_pin, color: Colors.red, size: 40.0),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton.icon(
                icon: Icon(Icons.my_location),
                label: Text('Use my current location'),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                onPressed: () async {
                  geolocator.Position position = await geolocator.Geolocator.getCurrentPosition(
                    desiredAccuracy: geolocator.LocationAccuracy.high,
                    forceAndroidLocationManager: true,
                  );
                  await _updateLocation(position);
                  Navigator.pop(context);
                },
              ),
              SizedBox(height: 8),
              ElevatedButton(
                child: Text('Update new address'),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _updateLocation(geolocator.Position position) async {
    setState(() => _userLocation = 'Fetching new location...');
    final url =
        'https://barikoi.xyz/v2/api/search/reverse/geocode?api_key=$_barikoiApiKey&longitude=${position.longitude}&latitude=${position.latitude}&district=true&post_code=true&country=true&sub_district=true&union=true&pauroshova=true&location_type=true&division=true&address=true&area=true&bangla=true';
    final response = await http.get(Uri.parse(url));
    final prefs = await SharedPreferences.getInstance();
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String newDisplay = '${data['place']['area']}, ${data['place']['city']}\n${data['place']['address_components']['house'] ?? ''} ${data['place']['address_components']['road'] ?? ''}';
      setState(() {
        _userLocation = newDisplay;
        _lastPosition = position;
      });
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lng', position.longitude);
      await prefs.setString('last_json', jsonEncode(data));
    } else {
      setState(() => _userLocation = 'Lat: ${position.latitude}, Lng: ${position.longitude}');
      await prefs.setDouble('last_lat', position.latitude);
      await prefs.setDouble('last_lng', position.longitude);
      await prefs.setString('last_json', '{}');
    }
  }

  List<Widget> _buildTabContent() {
    return [
      MembershipScreen(),
      MyPropertiesScreen(),
      HomeTabScreen(),
      WishlistScreen(),
      ProfileScreen(onLogout: _logout),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 2
          ? AppBar(
        automaticallyImplyLeading: false,
        title: GestureDetector(
          onTap: () => _showLocationBottomSheet(context),
          child: Row(
            children: [
              Icon(Icons.location_on, color: Colors.black, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: TextStyle(color: Colors.black),
                    children: [
                      TextSpan(
                        text: _userLocation.split('\n')[0],
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: '\n${_userLocation.split('\n').length > 1 ? _userLocation.split('\n')[1] : ''}',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      )
          : null,
      body: _buildTabContent()[_selectedIndex], // Back to no animation
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(
            icon: _selectedIndex == 0
                ? CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue,
              child: Icon(Icons.card_membership, color: Colors.white),
            )
                : Icon(Icons.card_membership),
            label: 'Pro',
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 1
                ? CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue,
              child: Icon(Icons.home_work, color: Colors.white),
            )
                : Icon(Icons.home_work),
            label: 'My Prop',
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 2
                ? CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue,
              child: Icon(Icons.home, color: Colors.white),
            )
                : Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 3
                ? CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue,
              child: Icon(Icons.favorite, color: Colors.white),
            )
                : Icon(Icons.favorite),
            label: 'Wishlist',
          ),
          BottomNavigationBarItem(
            icon: _selectedIndex == 4
                ? CircleAvatar(
              radius: 20,
              backgroundColor: Colors.blue,
              child: Icon(Icons.person, color: Colors.white),
            )
                : Icon(Icons.person),
            label: 'Profile',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        showUnselectedLabels: true, // Keep labels visible
      ),
    );
  }
}