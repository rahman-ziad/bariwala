import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:permission_handler/permission_handler.dart';
import 'Home.dart';
import '../main.dart';

class KycSelfieScreen extends StatefulWidget {
  final String name;
  final String profession;
  final DateTime dob;
  final String email;
  final String phone;
  final File frontImage;
  final File backImage;
  final int currentStep;

  KycSelfieScreen({
    required this.name,
    required this.profession,
    required this.dob,
    required this.email,
    required this.phone,
    required this.frontImage,
    required this.backImage,
    required this.currentStep,
  });

  @override
  _KycSelfieScreenState createState() => _KycSelfieScreenState();
}

class _KycSelfieScreenState extends State<KycSelfieScreen> {
  File? _selfieImage;
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cloudflare R2 Credentials
  final String _accessKeyId = '42c95c02a80fb6ce3b78679bbee52bc5';
  final String _secretAccessKey = '6aa3ac83380866f23b38012a43f15cdade4369123f613d7260868de9792808c7';
  final String _endpoint = 'https://d4954d83c98b55ffd16035570f81ca94.r2.cloudflarestorage.com';
  final String _bucketName = 'user-auth-img'; // Replace with your actual R2 bucket name

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    if (!await _checkAndRequestCameraPermission()) return;

    try {
      if (cameras.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No cameras available')),
        );
        return;
      }
      _cameraController = CameraController(
        cameras[1], // Front camera for selfie
        ResolutionPreset.medium, // Approx 640x480
      );
      _initializeControllerFuture = _cameraController!.initialize();
      if (mounted) setState(() {});
    } catch (e) {
      print('Camera initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to initialize camera: $e')),
      );
    }
  }

  Future<bool> _checkAndRequestCameraPermission() async {
    final status = await Permission.camera.status;
    if (status.isGranted) return true;

    final result = await Permission.camera.request();
    if (result.isGranted) return true;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Camera permission is required')),
    );
    return false;
  }

  Future<void> _takePicture() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Camera not initialized');
      return;
    }

    try {
      await _initializeControllerFuture;
      final image = await _cameraController!.takePicture();
      setState(() {
        _selfieImage = File(image.path);
      });
      Navigator.pop(context);
    } catch (e) {
      print('Error taking picture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take picture: $e')),
      );
    }
  }

  Future<void> _showCameraPreview() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _initializeCamera();
      if (_cameraController == null) return;
    }

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_cameraController!);
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              },
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _takePicture,
              child: Text('Capture'),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _uploadToCloudflareR2(File file, String uid, String fileName) async {
    try {
      final filePath = '$uid/images/$fileName'; // e.g., uid/images/nid_front.jpg
      final uri = Uri.parse('$_endpoint/$_bucketName/$filePath');
      final fileBytes = await file.readAsBytes();
      final contentSha256 = sha256.convert(fileBytes).toString();

      // Format date for S3 (YYYYMMDD'T'HHMMSS'Z')
      final now = DateTime.now().toUtc();
      final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z';
      final dateStamp = date.substring(0, 8); // YYYYMMDD for scope

      // S3 authentication headers
      final canonicalRequest = 'PUT\n/$_bucketName/$filePath\n\ncontent-sha256:$contentSha256\nhost:${uri.host}\nx-amz-content-sha256:$contentSha256\nx-amz-date:$date\n\ncontent-sha256;host;x-amz-content-sha256;x-amz-date\n$contentSha256';
      final stringToSign = 'AWS4-HMAC-SHA256\n$date\n$dateStamp/auto/s3/aws4_request\n${sha256.convert(utf8.encode(canonicalRequest)).toString()}';
      final signingKey = _getSignatureKey(_secretAccessKey, dateStamp, 'auto', 's3');
      final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

      final response = await http.put(
        uri,
        headers: {
          'Authorization': 'AWS4-HMAC-SHA256 Credential=$_accessKeyId/$dateStamp/auto/s3/aws4_request, SignedHeaders=content-sha256;host;x-amz-content-sha256;x-amz-date, Signature=$signature',
          'x-amz-date': date,
          'x-amz-content-sha256': contentSha256,
          'content-sha256': contentSha256,
          'Host': uri.host,
          'Content-Type': 'image/jpeg',
        },
        body: fileBytes,
      );

      if (response.statusCode == 200) {
        print('Upload successful: $filePath');
        return fileName; // Return just the fileName to match original Firestore structure
      } else {
        print('Upload failed: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      print('Cloudflare R2 upload error: $e');
      return null;
    }
  }

  List<int> _getSignatureKey(String key, String dateStamp, String regionName, String serviceName) {
    final kDate = Hmac(sha256, utf8.encode('AWS4$key')).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(regionName)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(serviceName)).bytes;
    return Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
  }

  // Replace the _submitKyc method
  Future<void> _submitKyc() async {
    final user = _auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not authenticated')),
      );
      return;
    }

    if (_selfieImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please capture a selfie')),
      );
      return;
    }

    try {
      final uid = user.uid;

      // Upload all images concurrently
      final uploadResults = await Future.wait([
        _uploadToCloudflareR2(widget.frontImage, uid, 'nid_front.jpg'),
        _uploadToCloudflareR2(widget.backImage, uid, 'nid_back.jpg'),
        _uploadToCloudflareR2(_selfieImage!, uid, 'selfie.jpg'),
      ]);

      final frontUrl = uploadResults[0];
      final backUrl = uploadResults[1];
      final selfieUrl = uploadResults[2];

      if (frontUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload front image')),
        );
        return;
      }
      if (backUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload back image')),
        );
        return;
      }
      if (selfieUrl == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload selfie')),
        );
        return;
      }

      await _firestore.collection('users').doc(user.uid).set({
        'name': widget.name,
        'profession': widget.profession,
        'dob': widget.dob.toIso8601String(),
        'email': widget.email,
        'phone': widget.phone,
        'idType': 'NID',
        'kycImages': {
          'front': frontUrl,
          'back': backUrl,
          'selfie': selfieUrl,
        },
        'kycUploaded': true,
        'isVerified': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
              (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('KYC submission error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting KYC: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('KYC - Selfie')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              LinearProgressIndicator(value: 1.0), // Step 3 of 3
              SizedBox(height: 16),
              Text('Take a Selfie', style: TextStyle(fontSize: 18)),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: _showCameraPreview,
                child: Text('Take Selfie with Camera'),
              ),
              if (_selfieImage != null) ...[
                SizedBox(height: 16),
                Image.file(_selfieImage!, height: 200, fit: BoxFit.cover),
              ],
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitKyc,
                child: Text('Submit KYC'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}