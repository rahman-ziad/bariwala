import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import 'create_post.dart';
import 'property_detail_screen.dart';

class HomeTabScreen extends StatefulWidget {
  @override
  _HomeTabScreenState createState() => _HomeTabScreenState();
}

class _HomeTabScreenState extends State<HomeTabScreen> {
  static const String _accessKeyId = '56c8a2692163341f6f9971118ed825f7';
  static const String _secretAccessKey = '021802c9458d513ae0850efc8864ec53777683da044c288845d37d01272d450e';
  static const String _endpoint = 'https://d4954d83c98b55ffd16035570f81ca94.r2.cloudflarestorage.com';
  static const String _bucketName = 'post';

  Future<Widget> _fetchImage(BuildContext context, String userId, String uuid, String fileName) async {
    try {
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
        return Image.memory(
          response.bodyBytes,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
        );
      } else {
        print('Image fetch failed: ${response.statusCode} - ${response.body}');
        return Container(
          height: 200,
          width: double.infinity,
          color: Colors.grey[300],
          child: Center(child: Text('Image not available')),
        );
      }
    } catch (e) {
      print('Error fetching image: $e');
      return Container(
        height: 200,
        width: double.infinity,
        color: Colors.grey[300],
        child: Center(child: Text('Image not available')),
      );
    }
  }

  String _trimLocation(String location, int maxLength) {
    if (location.length <= maxLength) return location;
    return '${location.substring(0, maxLength)}...';
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
                filled: true,
                fillColor: Colors.grey[200],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Want to host your own place?',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 10),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ElevatedButton(
                              onPressed: () =>
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => CreatePostScreen())),
                              child: Text('Post now'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Center(child: Text('Image Placeholder')),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Top Properties', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          FutureBuilder<List<QueryDocumentSnapshot>>(
            future: _fetchVerifiedProperties(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: Text('Error: ${snapshot.error}')),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(child: Text('No verified properties found.')),
                );
              }

              final properties = snapshot.data!;

              return ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                padding: EdgeInsets.all(16.0),
                itemCount: properties.length,
                itemBuilder: (context, index) {
                  final property = properties[index].data() as Map<String, dynamic>;
                  final uuid = property['uid'] as String;
                  final userId = property['userId'] as String;
                  final images = property['images'] as List<dynamic>;
                  final thumbnail = images.isNotEmpty ? images[0] as String : null;
                  final rooms = property['rooms'] as String? ?? 'N/A';
                  final floor = property['floor'] as String? ?? 'N/A';
                  final rent = property['rent'] as String? ?? 'N/A';
                  final isRentNegotiable = property['isRentNegotiable'] as bool? ?? false;
                  final liftAvailable = property['liftAvailable'] as bool? ?? false;
                  final parkingAvailable = property['parkingAvailable'] as bool? ?? false;
                  final location = property['location'] as String? ?? 'Unknown location';
                  final trimmedLocation = _trimLocation(location, 50);

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PropertyDetailScreen(propertyData: property),
                        ),
                      );
                    },
                    child: Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                      elevation: 4,
                      margin: EdgeInsets.only(bottom: 16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.vertical(top: Radius.circular(16.0)),
                            child: thumbnail != null
                                ? FutureBuilder<Widget>(
                              future: _fetchImage(context, userId, uuid, thumbnail),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.waiting) {
                                  return Shimmer.fromColors(
                                    baseColor: Colors.grey[300]!,
                                    highlightColor: Colors.grey[100]!,
                                    child: Container(
                                      height: 200,
                                      width: double.infinity,
                                      color: Colors.grey[300],
                                    ),
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
                            )
                                : Container(
                              height: 200,
                              width: double.infinity,
                              color: Colors.grey[300],
                              child: Center(child: Text('No image')),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.king_bed, size: 20, color: Colors.grey[700]),
                                          SizedBox(width: 4),
                                          Text(
                                            '$rooms rooms, $floor floor',
                                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        trimmedLocation,
                                        style: TextStyle(fontSize: 10, color: Colors.grey[600], fontStyle: FontStyle.italic),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '৳$rent',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue),
                                    ),
                                    if (isRentNegotiable)
                                      Container(
                                        margin: EdgeInsets.only(top: 4),
                                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          'Negotiable',
                                          style: TextStyle(color: Colors.white, fontSize: 12),
                                        ),
                                      ),
                                    SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (liftAvailable) Icon(Icons.elevator, color: Colors.green, size: 20),
                                        if (parkingAvailable) Icon(Icons.local_parking, color: Colors.green, size: 20),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<List<QueryDocumentSnapshot>> _fetchVerifiedProperties() async {
    final querySnapshot = await FirebaseFirestore.instance
        .collection('posts')
        .where('isVerifyDone', isEqualTo: true)
        .get();

    return querySnapshot.docs;
  }
}