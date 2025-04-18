import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart' as io_client;
import 'package:crypto/crypto.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img; // For cropping
import 'kyc_selfie_screen.dart';
import '../main.dart';

class KycNidScreen extends StatefulWidget {
  final String name;
  final String profession;
  final DateTime dob;
  final String email;
  final String phone;
  final int currentStep;

  KycNidScreen({
    required this.name,
    required this.profession,
    required this.dob,
    required this.email,
    required this.phone,
    required this.currentStep,
  });

  @override
  _KycNidScreenState createState() => _KycNidScreenState();
}

class _KycNidScreenState extends State<KycNidScreen> {
  File? _frontImage;
  File? _backImage;
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isFlashOn = false;

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
        cameras[0],
        ResolutionPreset.max,
        imageFormatGroup: ImageFormatGroup.jpeg,
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

  Future<File> _cropImageTo640x480(File imageFile) async {
    final image = img.decodeImage(await imageFile.readAsBytes())!;
    final aspectRatio = 640 / 480;
    int cropWidth, cropHeight;
    if (image.width / image.height > aspectRatio) {
      cropHeight = image.height;
      cropWidth = (cropHeight * aspectRatio).round();
    } else {
      cropWidth = image.width;
      cropHeight = (cropWidth / aspectRatio).round();
    }
    final croppedImage = img.copyCrop(
      image,
      x: (image.width - cropWidth) ~/ 2,
      y: (image.height - cropHeight) ~/ 2,
      width: cropWidth,
      height: cropHeight,
    );
    final resizedImage = img.copyResize(croppedImage, width: 640, height: 480); // Or 1280x960
    final tempDir = Directory.systemTemp;
    final resizedFile = File('${tempDir.path}/${imageFile.path.split('/').last.replaceAll('.jpg', '_cropped.jpg')}');
    await resizedFile.writeAsBytes(img.encodeJpg(resizedImage));
    return resizedFile;
  }

  Future<void> _takePicture(bool isFront) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Camera not initialized');
      return;
    }

    try {
      await _initializeControllerFuture;
      await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      final XFile image = await _cameraController!.takePicture();
      final croppedImage = await _cropImageTo640x480(File(image.path));
      setState(() {
        if (isFront) {
          _frontImage = croppedImage;
        } else {
          _backImage = croppedImage;
        }
      });
      await _cameraController!.setFlashMode(FlashMode.off);
      Navigator.pop(context);
    } catch (e) {
      print('Error taking picture: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to take picture: $e')),
      );
    }
  }

  Future<void> _pickFromGallery(bool isFront) async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (pickedFile != null) {
        final croppedImage = await _cropImageTo640x480(File(pickedFile.path));
        setState(() {
          if (isFront) {
            _frontImage = croppedImage;
          } else {
            _backImage = croppedImage;
          }
        });
      }
    } catch (e) {
      print('Gallery picker error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick from gallery: $e')),
      );
    }
  }

  Future<void> _showImageSourceOptions(bool isFront) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _initializeCamera();
      if (_cameraController == null) return;
    }

    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.camera),
            title: Text('Take Photo'),
            onTap: () async {
              Navigator.pop(context);
              await _showCameraPreview(isFront);
            },
          ),
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Pick from Gallery'),
            onTap: () async {
              Navigator.pop(context);
              await _pickFromGallery(isFront);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showCameraPreview(bool isFront) async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      await _initializeCamera();
      if (_cameraController == null) return;
    }

    await showDialog(
      context: context,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.all(16),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.8,
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: ClipRect(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CameraPreview(_cameraController!),
                      AspectRatio(
                        aspectRatio: 640 / 480,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white, width: 2),
                            color: Colors.black.withOpacity(0.2),
                          ),
                          child: CustomPaint(
                            painter: GridPainter(),
                            child: Container(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 8),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Ensure all text on the ID is visible within the box. If not, please recapture.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    backgroundColor: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      _isFlashOn ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _isFlashOn = !_isFlashOn;
                      });
                      _cameraController!.setFlashMode(
                        _isFlashOn ? FlashMode.torch : FlashMode.off,
                      );
                    },
                  ),
                  SizedBox(width: 20),
                  ElevatedButton(
                    onPressed: () => _takePicture(isFront),
                    child: Text('Capture'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _proceed() {
    if (_frontImage == null || _backImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please capture or upload both NID images')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KycSelfieScreen(
          name: widget.name,
          profession: widget.profession,
          dob: widget.dob,
          email: widget.email,
          phone: widget.phone,
          frontImage: _frontImage!,
          backImage: _backImage!,
          currentStep: 2,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('KYC - NID')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LinearProgressIndicator(value: 0.66),
              SizedBox(height: 16),
              Text(
                'NID Front Page',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showImageSourceOptions(true),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: _frontImage == null
                      ? Center(
                    child: Text(
                      'Tap to add Front Image',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      _frontImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                'NID Back Page',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              GestureDetector(
                onTap: () => _showImageSourceOptions(false),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey, width: 2),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[200],
                  ),
                  child: _backImage == null
                      ? Center(
                    child: Text(
                      'Tap to add Back Image',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  )
                      : ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: Image.file(
                      _backImage!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _proceed,
                child: Text('Next'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.0;


    for (int i = 1; i < 3; i++) {
      double x = size.width * i / 3;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }


    for (int i = 1; i < 2; i++) {
      double y = size.height * i / 2;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }


    final rectPaint = Paint()
      ..color = Colors.red.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final rect = Rect.fromLTWH(
      size.width * 0.05,
      size.height * 0.05,
      size.width * 0.9,
      size.height * 0.9,
    );
    canvas.drawRect(rect, rectPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}