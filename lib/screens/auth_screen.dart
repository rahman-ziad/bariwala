import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';
import 'kyc_intro_screen.dart';
import 'home.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String _phoneNumber = '';
  String _otpCode = '';
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _verificationId;
  bool _showOtpField = false;

  Future<void> _verifyPhoneNumber() async {
    try {
      print('Attempting to verify phone: $_phoneNumber');
      await _auth.verifyPhoneNumber(
        phoneNumber: _phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          await _navigateBasedOnKycStatus(context);
        },
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.code} - ${e.message}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Verification Failed: ${e.message}')),
          );
        },
        codeSent: (String verificationId, int? resendToken) {
          print('Code sent. Verification ID: $verificationId');
          setState(() {
            _verificationId = verificationId;
            _showOtpField = true;
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      print('Error in verifyPhoneNumber: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Phone verification error: $e')),
      );
    }
  }

  Future<void> _verifyOTP() async {
    if (_verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please verify phone number first')),
      );
      return;
    }

    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpCode,
      );
      await _auth.signInWithCredential(credential);
      await _navigateBasedOnKycStatus(context);
    } on FirebaseAuthException catch (e) {
      print('Firebase Auth Error: ${e.code} - ${e.message}');
      String errorMessage;
      switch (e.code) {
        case 'invalid-verification-code':
          errorMessage = 'Invalid OTP. Please try again.';
          break;
        case 'session-expired':
          errorMessage = 'Session expired. Please start over.';
          break;
        default:
          errorMessage = 'Authentication error: ${e.message}';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      print('Unexpected error in OTP verification: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unexpected error: $e')),
      );
    }
  }

  Future<void> _navigateBasedOnKycStatus(BuildContext context) async {
    final user = _auth.currentUser;
    if (user != null) {
      try {
        final docSnapshot = await _firestore.collection('users').doc(user.uid).get();
        if (docSnapshot.exists) {
          final data = docSnapshot.data() as Map<String, dynamic>?;
          if (data?['kycUploaded'] == true) {
            print('KYC already uploaded, navigating to HomeScreen');
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => HomeScreen()));
          } else {
            print('KYC not uploaded, navigating to KycIntroScreen');
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => KycIntroScreen()));
          }
        } else {
          print('No user document found, navigating to KycIntroScreen');
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => KycIntroScreen()));
        }
      } catch (e) {
        print('Error checking KYC status: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking KYC status: $e')),
        );
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => KycIntroScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text('Authentication')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!_showOtpField) ...[
              IntlPhoneField(
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  border: OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[300],
                ),
                initialCountryCode: 'BD',
                onChanged: (phone) {
                  setState(() {
                    _phoneNumber = phone.completeNumber;
                  });
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _verifyPhoneNumber,
                child: Text('Send OTP'),
              ),
            ] else ...[
              OtpTextField(
                numberOfFields: 6,
                borderColor: Colors.blue,
                focusedBorderColor: Colors.blue,
                showFieldAsBox: true,
                fieldWidth: 45,
                borderWidth: 2,
                filled: true,
                onCodeChanged: (String code) {
                  _otpCode = code;
                },
                onSubmit: (String verificationCode) {
                  _otpCode = verificationCode;
                  _verifyOTP();
                },
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _verifyOTP,
                child: Text('Verify OTP'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}