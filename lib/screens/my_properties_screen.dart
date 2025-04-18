import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class MyPropertiesScreen extends StatelessWidget {
  static const String _accessKeyId = '56c8a2692163341f6f9971118ed825f7';
  static const String _secretAccessKey = '021802c9458d513ae0850efc8864ec53777683da044c288845d37d01272d450e';
  static const String _endpoint = 'https://d4954d83c98b55ffd16035570f81ca94.r2.cloudflarestorage.com';
  static const String _bucketName = 'post';

  Future<Widget> _fetchImage(String userId, String uuid, String fileName) async {
    final filePath = '$userId/$uuid/$fileName';
    final uri = Uri.parse('$_endpoint/$_bucketName/$filePath');

    final now = DateTime.now().toUtc();
    final date = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}T${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}Z';
    final dateStamp = date.substring(0, 8);

    final contentSha256 = 'UNSIGNED-PAYLOAD';
    final canonicalRequest = 'GET\n/$_bucketName/$filePath\n\nhost:${uri.host}\nx-amz-content-sha256:$contentSha256\nx-amz-date:$date\n\nhost;x-amz-content-sha256;x-amz-date\n$contentSha256';
    final stringToSign = 'AWS4-HMAC-SHA256\n$date\n$dateStamp/auto/s3/aws4_request\n${sha256.convert(utf8.encode(canonicalRequest)).toString()}';
    final kDate = Hmac(sha256, utf8.encode('AWS4$_secretAccessKey')).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode('auto')).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode('s3')).bytes;
    final signingKey = Hmac(sha256, kService).convert(utf8.encode('aws4_request')).bytes;
    final signature = Hmac(sha256, signingKey).convert(utf8.encode(stringToSign)).toString();

    final response = await http.get(
      uri,
      headers: {
        'Authorization': 'AWS4-HMAC-SHA256 Credential=$_accessKeyId/$dateStamp/auto/s3/aws4_request, SignedHeaders=host;x-amz-content-sha256;x-amz-date, Signature=$signature',
        'x-amz-date': date,
        'x-amz-content-sha256': contentSha256,
        'Host': uri.host,
      },
    );

    if (response.statusCode == 200) {
      return Image.memory(response.bodyBytes, height: 200, width: double.infinity, fit: BoxFit.cover);
    } else {
      print('Image fetch failed: ${response.statusCode} - ${response.body}');
      return Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey[300],
        child: Center(child: Text('Image not available')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: Text('My Properties')),
        body: Center(child: Text('Please log in to view your properties.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('My Properties'),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            if (userSnapshot.hasError) {
              return Center(child: Text('Error: ${userSnapshot.error}'));
            }
            if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
              return Center(child: Text('User data not found.'));
            }

            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final postUuids = List<String>.from(userData['posts'] ?? []);

            if (postUuids.isEmpty) {
              return Center(child: Text('You have no properties listed yet.'));
            }

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .where('userId', isEqualTo: user.uid)
                  .snapshots(),
              builder: (context, postsSnapshot) {
                if (postsSnapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (postsSnapshot.hasError) {
                  return Center(child: Text('Error: ${postsSnapshot.error}'));
                }
                if (!postsSnapshot.hasData || postsSnapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No property details found.'));
                }

                final properties = postsSnapshot.data!.docs;

                return ListView.builder(
                  itemCount: properties.length,
                  itemBuilder: (context, index) {
                    final property = properties[index].data() as Map<String, dynamic>;
                    final uuid = property['uid'] as String;
                    final postId = property['postId'] as String; // lat=long=uuid=
                    final images = property['images'] as List<dynamic>;
                    final thumbnail = images.isNotEmpty ? images[0] as String : null;
                    final isVerifyDone = property['isVerifyDone'] as bool? ?? false;
                    final location = property['location'] as String? ?? 'Unknown location';
                    final rent = property['rent'] as String? ?? 'N/A';
                    final homeType = property['homeType'] as String? ?? 'N/A';

                    return Card(
                      elevation: 4,
                      margin: EdgeInsets.only(bottom: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<Widget>(
                            future: thumbnail != null
                                ? _fetchImage(user.uid, uuid, thumbnail)
                                : Future.value(Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.grey[300],
                              child: Center(child: Text('No thumbnail available')),
                            )),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                return Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.grey[300],
                                  child: Center(child: CircularProgressIndicator()),
                                );
                              }
                              if (snapshot.hasError) {
                                return Container(
                                  height: 200,
                                  width: double.infinity,
                                  color: Colors.grey[300],
                                  child: Center(child: Text('Error loading image')),
                                );
                              }
                              return snapshot.data ?? Container(
                                height: 200,
                                width: double.infinity,
                                color: Colors.grey[300],
                                child: Center(child: Text('Image not available')),
                              );
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(location, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                SizedBox(height: 8),
                                Text('Rent: $rent'),
                                Text('Home Type: $homeType'),
                                SizedBox(height: 8),
                                Text(
                                  isVerifyDone ? 'Verified' : 'Under Review',
                                  style: TextStyle(
                                    color: isVerifyDone ? Colors.green : Colors.orange,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => EditPropertyScreen(
                                          propertyId: postId,
                                          propertyData: property,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Text('Edit'),
                                ),
                                ElevatedButton(
                                  onPressed: () => _deleteProperty(context, postId, user.uid, uuid),
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                  child: Text('Delete'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _deleteProperty(BuildContext context, String postId, String userId, String uuid) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Property'),
        content: Text('Are you sure you want to delete this property?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
        await FirebaseFirestore.instance.collection('users').doc(userId).update({
          'posts': FieldValue.arrayRemove([uuid]),
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Property deleted successfully')),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting property: $e')),
        );
      }
    }
  }
}
class EditPropertyScreen extends StatefulWidget {
  final String propertyId;
  final Map<String, dynamic> propertyData;

  const EditPropertyScreen({required this.propertyId, required this.propertyData});

  @override
  _EditPropertyScreenState createState() => _EditPropertyScreenState();
}

class _EditPropertyScreenState extends State<EditPropertyScreen> {
  late TextEditingController _floorController;
  late TextEditingController _roomsController;
  late TextEditingController _areaController;
  late TextEditingController _phoneController;
  late TextEditingController _rentController;
  late TextEditingController _liftChargeController;
  late TextEditingController _descriptionController;
  late bool _isRentNegotiable;
  late bool _utilityIncluded;
  late bool _parkingAvailable;
  late bool _liftAvailable;
  late DateTime _availableFrom;
  late String _homeType;
  List<File> _propertyImages = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _floorController = TextEditingController(text: widget.propertyData['floor']);
    _roomsController = TextEditingController(text: widget.propertyData['rooms']);
    _areaController = TextEditingController(text: widget.propertyData['area']);
    _phoneController = TextEditingController(text: widget.propertyData['contact']);
    _rentController = TextEditingController(text: widget.propertyData['rent']);
    _liftChargeController = TextEditingController(text: widget.propertyData['liftCharge']);
    _descriptionController = TextEditingController(text: widget.propertyData['description']);
    _isRentNegotiable = widget.propertyData['isRentNegotiable'] ?? false;
    _utilityIncluded = widget.propertyData['utilityIncluded'] ?? false;
    _parkingAvailable = widget.propertyData['parkingAvailable'] ?? false;
    _liftAvailable = widget.propertyData['liftAvailable'] ?? false;
    _availableFrom = widget.propertyData['availableFrom'] is Timestamp
        ? (widget.propertyData['availableFrom'] as Timestamp).toDate()
        : DateTime.parse(widget.propertyData['availableFrom'] as String? ?? DateTime.now().toString());
    _homeType = widget.propertyData['homeType'] ?? 'Family';
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

  Future<void> _saveChanges() async {
    setState(() => _isSaving = true);
    try {
      final updatedData = {
        'floor': _floorController.text,
        'rooms': _roomsController.text,
        'area': _areaController.text,
        'contact': _phoneController.text,
        'rent': _rentController.text,
        'isRentNegotiable': _isRentNegotiable,
        'utilityIncluded': _utilityIncluded,
        'parkingAvailable': _parkingAvailable,
        'liftAvailable': _liftAvailable,
        'liftCharge': _liftAvailable ? _liftChargeController.text : '',
        'availableFrom': _availableFrom,
        'homeType': _homeType,
        'description': _descriptionController.text,
        // Images remain unchanged unless new ones are uploaded (logic can be added if needed)
      };

      await FirebaseFirestore.instance.collection('posts').doc(widget.propertyId).update(updatedData);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Property updated successfully')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error updating property: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Property')),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ElevatedButton(
                  onPressed: _pickImages,
                  child: Text('Replace Property Pictures (up to 5)'),
                ),
                SizedBox(height: 10),
                _propertyImages.isEmpty
                    ? Text('No new images selected. Existing images will remain.')
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
                TextField(controller: _floorController, decoration: InputDecoration(labelText: 'Floor')),
                TextField(controller: _roomsController, decoration: InputDecoration(labelText: 'Number of Rooms')),
                TextField(controller: _areaController, decoration: InputDecoration(labelText: 'Area (sq ft, optional)')),
                TextField(controller: _phoneController, decoration: InputDecoration(labelText: 'Contact Info')),
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
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveChanges,
                  child: Text('Save Changes'),
                ),
              ],
            ),
          ),
          if (_isSaving) Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}