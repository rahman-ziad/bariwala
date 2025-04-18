import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'Home.dart';
import 'package:uuid/uuid.dart';

class CreatePostScreen extends StatefulWidget {
  @override
  _CreatePostScreenState createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  LatLng _selectedLocation = LatLng(23.8103, 90.4125);
  LatLng? _lastFetchedLocation;
  String _locationText = 'Tap to select location';
  final String _barikoiApiKey = 'bkoi_3b6583584c58bee36ae766bb9cfe4e807f0e94f90ad1196baf1d73a1a8b8840f';
  final TextEditingController _floorController = TextEditingController();
  final TextEditingController _roomsController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _rentController = TextEditingController();
  final TextEditingController _liftChargeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  bool _isRentNegotiable = false;
  bool _utilityIncluded = false;
  bool _parkingAvailable = false;
  bool _liftAvailable = false;
  DateTime _availableFrom = DateTime.now();
  String _homeType = 'Family';
  List<File> _propertyImages = [];
  bool _agreeTerms = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => _locationText = 'Please enable location services.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => _locationText = 'Location permission denied.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => _locationText = 'Location permission denied forever.');
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      LatLng newLocation = LatLng(position.latitude, position.longitude);
      await _updateLocation(newLocation);
    } catch (e) {
      setState(() {
        _locationText = 'Failed to fetch current location: $e';
        _selectedLocation = LatLng(23.8103, 90.4125);
      });
    }
  }

  Future<void> _pickLocation() async {
    showModalBottomSheet(
      context: context,
      builder: (context) => LocationPicker(
        initialLocation: _selectedLocation,
        onLocationSelected: (LatLng location) async {
          await _updateLocation(location);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _updateLocation(LatLng newLocation) async {
    if (_lastFetchedLocation != null &&
        _lastFetchedLocation!.latitude == newLocation.latitude &&
        _lastFetchedLocation!.longitude == newLocation.longitude) {
      return;
    }

    setState(() {
      _selectedLocation = newLocation;
      _locationText = 'Fetching address...';
    });

    try {
      final url = 'https://barikoi.xyz/v2/api/search/reverse/geocode'
          '?api_key=$_barikoiApiKey'
          '&longitude=${newLocation.longitude}'
          '&latitude=${newLocation.latitude}'
          '&district=true'
          '&post_code=true'
          '&country=true'
          '&sub_district=true'
          '&union=true'
          '&pauroshova=true'
          '&location_type=true'
          '&division=true'
          '&address=true'
          '&area=true'
          '&bangla=true';
      final response = await http.get(Uri.parse(url));
      print('API URL: $url');
      print('API Response Status: ${response.statusCode}');
      print('API Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _locationText = data['place']['address'] ??
              'Lat: ${newLocation.latitude}, Lng: ${newLocation.longitude}';
          _lastFetchedLocation = newLocation;
        });
      } else {
        setState(() {
          _locationText = 'Failed to fetch address: ${response.statusCode} - ${response.body}';
          _lastFetchedLocation = newLocation;
        });
      }
    } catch (e) {
      setState(() {
        _locationText = 'Error fetching address: $e';
        _lastFetchedLocation = newLocation;
      });
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null && _propertyImages.length + pickedFiles.length <= 5) {
      setState(() {
        _propertyImages.addAll(pickedFiles.map((xFile) => File(xFile.path)));
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Maximum 5 images allowed')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Create Property Post')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _pickImages,
              child: Text('Upload Property Pictures (up to 5)'),
            ),
            SizedBox(height: 10),
            _propertyImages.isEmpty
                ? Container(
              height: 200,
              width: double.infinity,
              color: Colors.grey[300],
              child: Center(child: Text('No images uploaded yet')),
            )
                : Container(
              height: 200,
              width: double.infinity,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _propertyImages.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Image.file(
                      _propertyImages[index],
                      width: 150,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 10),
            Text('First photo will be thumbnail', style: TextStyle(fontSize: 12)),
            SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: Text(_locationText)),
                IconButton(
                  icon: Icon(Icons.location_on),
                  onPressed: _pickLocation,
                ),
              ],
            ),
            TextField(controller: _floorController, decoration: InputDecoration(labelText: 'Floor')),
            TextField(controller: _roomsController, decoration: InputDecoration(labelText: 'Number of Rooms')),
            TextField(controller: _areaController, decoration: InputDecoration(labelText: 'Area (sq ft, optional)')),
            TextField(controller: _phoneController, decoration: InputDecoration(labelText: 'Contact Info (Phone & WhatsApp)')),
            TextField(controller: _rentController, decoration: InputDecoration(labelText: 'Rent')),
            SwitchListTile(
              title: Text('Rent Negotiable'),
              value: _isRentNegotiable,
              onChanged: (val) => setState(() => _isRentNegotiable = val),
            ),
            SwitchListTile(
              title: Text('Utility Bills Included'),
              value: _utilityIncluded,
              onChanged: (val) => setState(() => _utilityIncluded = val),
            ),
            SwitchListTile(
              title: Text('Parking Available'),
              value: _parkingAvailable,
              onChanged: (val) => setState(() => _parkingAvailable = val),
            ),
            SwitchListTile(
              title: Text('Lift Available'),
              value: _liftAvailable,
              onChanged: (val) => setState(() => _liftAvailable = val),
            ),
            if (_liftAvailable)
              TextField(controller: _liftChargeController, decoration: InputDecoration(labelText: 'Lift Charge')),
            ListTile(
              title: Text('Available From: ${_availableFrom.toString().split(' ')[0]}'),
              trailing: Icon(Icons.calendar_today),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _availableFrom,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (date != null) setState(() => _availableFrom = date);
              },
            ),
            DropdownButtonFormField<String>(
              value: _homeType,
              items: ['Family', 'Bachelor'].map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (val) => setState(() => _homeType = val!),
              decoration: InputDecoration(labelText: 'Home Type'),
            ),
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            CheckboxListTile(
              title: Text('I agree to all terms and conditions'),
              value: _agreeTerms,
              onChanged: (val) => setState(() => _agreeTerms = val!),
            ),
            ElevatedButton(
              onPressed: _agreeTerms
                  ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VerificationScreen(
                      postData: {
                        'location': _locationText,
                        'floor': _floorController.text,
                        'rooms': _roomsController.text,
                        'area': _areaController.text,
                        'contact': _phoneController.text,
                        'rent': _rentController.text,
                        'isRentNegotiable': _isRentNegotiable,
                        'utilityIncluded': _utilityIncluded,
                        'parkingAvailable': _parkingAvailable,
                        'liftAvailable': _liftAvailable,
                        'liftCharge': _liftChargeController.text,
                        'availableFrom': _availableFrom,
                        'homeType': _homeType,
                        'description': _descriptionController.text,
                        'images': _propertyImages,
                        'lat': _selectedLocation.latitude,
                        'long': _selectedLocation.longitude,
                      },
                    ),
                  ),
                );
              }
                  : null,
              child: Text('Next'),
            ),
          ],
        ),
      ),
    );
  }
}

class LocationPicker extends StatefulWidget {
  final LatLng initialLocation;
  final Function(LatLng) onLocationSelected;

  const LocationPicker({required this.initialLocation, required this.onLocationSelected});

  @override
  _LocationPickerState createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late LatLng _currentLocation;
  late LatLng _selectedLocation;

  @override
  void initState() {
    super.initState();
    _currentLocation = widget.initialLocation;
    _selectedLocation = widget.initialLocation;
    _getCurrentLocation();
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        _selectedLocation = _currentLocation;
      });
    } catch (e) {
      print('Error fetching location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 500,
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            'Current Location',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                center: _currentLocation,
                zoom: 15.0,
                onTap: (tapPosition, point) {
                  setState(() {
                    _selectedLocation = point;
                  });
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
                      point: _selectedLocation,
                      child: Icon(
                        Icons.location_pin,
                        color: Colors.red,
                        size: 40.0,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SizedBox(height: 10),
          Column(
            children: [
              ElevatedButton(
                onPressed: () => widget.onLocationSelected(_currentLocation),
                child: Text('Use Current Location'),
              ),
              SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => widget.onLocationSelected(_selectedLocation),
                child: Text('Confirm New Location'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class VerificationScreen extends StatefulWidget {
  final Map<String, dynamic> postData;
  const VerificationScreen({required this.postData});

  @override
  _VerificationScreenState createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  List<File> _verificationDocs = [];
  String _verificationType = 'Utility Bills';
  bool _isUploading = false;

  // Cloudflare R2 Credentials (working from KycSelfieScreen)

  final String _accessKeyId = '56c8a2692163341f6f9971118ed825f7';
  final String _secretAccessKey = '021802c9458d513ae0850efc8864ec53777683da044c288845d37d01272d450e';
  final String _endpoint = 'https://d4954d83c98b55ffd16035570f81ca94.r2.cloudflarestorage.com';
  final String _bucketName = 'post';
  Future<void> _pickDocs() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _verificationDocs.add(File(pickedFile.path)));
    }
  }

  Future<String?> _uploadToCloudflareR2(File file, String userId, String uuid, String fileName) async {
    try {
      final filePath = '$userId/$uuid/$fileName'; // e.g., post/userid/uuid/userid_img1.jpg
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
        return fileName;
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

  Future<void> _submitPost() async {
    setState(() => _isUploading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User not authenticated')),
      );
      setState(() => _isUploading = false);
      return;
    }

    if (_verificationDocs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please upload at least one verification document')),
      );
      setState(() => _isUploading = false);
      return;
    }

    try {
      final uuid = Uuid().v4();
      final postId = '${widget.postData['lat']}=${widget.postData['long']}=$uuid'; // lat=long=uuid=

      // Upload property images
      final imageFutures = <Future<String?>>[];
      for (int i = 0; i < widget.postData['images'].length; i++) {
        final image = widget.postData['images'][i] as File;
        final fileName = '${user.uid}_image${i + 1}.jpg';
        imageFutures.add(_uploadToCloudflareR2(image, user.uid, uuid, fileName));
      }

      // Upload verification documents
      final verificationFutures = <Future<String?>>[];
      for (int i = 0; i < _verificationDocs.length; i++) {
        final doc = _verificationDocs[i];
        final fileName = '${user.uid}_verification${_verificationDocs.length > 1 ? '_${i + 1}' : ''}.jpg';
        verificationFutures.add(_uploadToCloudflareR2(doc, user.uid, uuid, fileName));
      }

      // Wait for all uploads to complete
      final uploadResults = await Future.wait([...imageFutures, ...verificationFutures]);

      final imageUrls = uploadResults.sublist(0, widget.postData['images'].length);
      final verificationUrls = uploadResults.sublist(widget.postData['images'].length);

      if (imageUrls.contains(null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload one or more property images')),
        );
        setState(() => _isUploading = false);
        return;
      }
      if (verificationUrls.contains(null)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload one or more verification documents')),
        );
        setState(() => _isUploading = false);
        return;
      }

      // Upload to Firestore
      await FirebaseFirestore.instance.collection('posts').doc(postId).set({
        ...widget.postData,
        'images': imageUrls,
        'verificationDocs': verificationUrls,
        'verificationType': _verificationType,
        'uid': uuid,
        'postId': postId,
        'userId': user.uid,
        'lat': widget.postData['lat'],
        'long': widget.postData['long'],
        'timestamp': FieldValue.serverTimestamp(),
        'isVerifyDone': true,
        'isAdAvailable': false,
      });

      // Update user's posts collection with UUID
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'posts': FieldValue.arrayUnion([uuid]),
      });

      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen()),
              (Route<dynamic> route) => false,
        );
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Post created successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error submitting post: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Verification')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _verificationType,
                    items: ['Utility Bills', 'Holding Tax', 'E Porcha', 'Others']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (val) => setState(() => _verificationType = val!),
                    decoration: InputDecoration(labelText: 'Verification Type'),
                  ),
                  SizedBox(height: 10),
                  ElevatedButton(onPressed: _pickDocs, child: Text('Upload Verification Document')),
                  SizedBox(height: 10),
                  _verificationDocs.isEmpty
                      ? Container(
                    height: 200,
                    width: double.infinity,
                    color: Colors.grey[300],
                    child: Center(child: Text('No verification docs uploaded yet')),
                  )
                      : Container(
                    height: 200,
                    width: double.infinity,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _verificationDocs.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: EdgeInsets.only(right: 8),
                          child: Image.file(
                            _verificationDocs[index],
                            width: 150,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _verificationDocs.isNotEmpty && !_isUploading ? _submitPost : null,
                    child: Text('Submit'),
                  ),
                ],
              ),
            ),
            if (_isUploading)
              Center(
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}