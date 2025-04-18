import 'package:flutter/material.dart';
import 'kyc_info_screen.dart';

class KycIntroScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('KYC Verification')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'We need your personal information, NID, and photos to verify your identity.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => KycInfoScreen()));
              },
              child: Text('I Am Ready'),
            ),
          ],
        ),
      ),
    );
  }
}