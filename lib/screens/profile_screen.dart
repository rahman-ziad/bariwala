import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  final VoidCallback onLogout;
  ProfileScreen({required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Profile', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          SizedBox(height: 20),
          Text('Manage your account details here.', style: TextStyle(fontSize: 16)),
          SizedBox(height: 20),
          ElevatedButton(onPressed: onLogout, child: Text('Logout')),
        ],
      ),
    );
  }
}