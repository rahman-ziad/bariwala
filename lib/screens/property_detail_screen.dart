import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shimmer/shimmer.dart';

class PropertyDetailScreen extends StatelessWidget {
  final Map<String, dynamic> propertyData;

  const PropertyDetailScreen({required this.propertyData});

  static const String _accessKeyId = '56c8a2692163341f6f9971118ed825f7';
  static const String _secretAccessKey = '021802c9458d513ae0850efc8864ec53777683da044c288845d37d01272d450e';
  static const String _endpoint = 'https://d4954d83c98b55ffd16035570f81ca94.r2.cloudflarestorage.com';
  static const String _bucketName = 'post';

  Future<Widget> _fetchImage(BuildContext context, String userId, String uuid, String fileName, {bool isThumbnail = true}) async {
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
          width: isThumbnail ? 300 : null,
          height: isThumbnail ? null : MediaQuery.of(context).size.height,
          fit: isThumbnail ? BoxFit.cover : BoxFit.contain,
        );
      } else {
        print('Image fetch failed: ${response.statusCode} - ${response.body}');
        return Container(
          width: isThumbnail ? 300 : double.infinity,
          height: isThumbnail ? 250 : MediaQuery.of(context).size.height,
          color: Colors.grey[300],
          child: Center(child: Text('Image not available')),
        );
      }
    } catch (e) {
      print('Error fetching image: $e');
      return Container(
        width: isThumbnail ? 300 : double.infinity,
        height: isThumbnail ? 250 : MediaQuery.of(context).size.height,
        color: Colors.grey[300],
        child: Center(child: Text('Image not available')),
      );
    }
  }

  void _showFullScreenImage(BuildContext context, String userId, String uuid, String image) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: FutureBuilder<Widget>(
                future: _fetchImage(context, userId, uuid, image, isThumbnail: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      child: Container(
                        width: double.infinity,
                        height: MediaQuery.of(context).size.height,
                        color: Colors.grey[300],
                      ),
                    );
                  }
                  if (snapshot.hasError) {
                    return Container(
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height,
                      color: Colors.grey[300],
                      child: Center(child: Text('Error loading image')),
                    );
                  }
                  return snapshot.data ?? Container(
                    width: double.infinity,
                    height: MediaQuery.of(context).size.height,
                    color: Colors.grey[300],
                    child: Center(child: Text('Image not available')),
                  );
                },
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uuid = propertyData['uid'] as String;
    final images = propertyData['images'] as List<dynamic>;
    final location = propertyData['location'] as String? ?? 'Unknown location';
    final rooms = propertyData['rooms'] as String? ?? 'N/A';
    final floor = propertyData['floor'] as String? ?? 'N/A';
    final rent = propertyData['rent'] as String? ?? 'N/A';
    final isRentNegotiable = propertyData['isRentNegotiable'] as bool? ?? false;
    final liftAvailable = propertyData['liftAvailable'] as bool? ?? false;
    final parkingAvailable = propertyData['parkingAvailable'] as bool? ?? false;
    final utilityIncluded = propertyData['utilityIncluded'] as bool? ?? false;
    final area = propertyData['area'] as String? ?? 'N/A';
    final contact = propertyData['contact'] as String? ?? 'N/A';
    final description = propertyData['description'] as String? ?? 'No description';
    final homeType = propertyData['homeType'] as String? ?? 'N/A';
    final availableFrom = propertyData['availableFrom'] is Timestamp
        ? (propertyData['availableFrom'] as Timestamp).toDate().toString().split(' ')[0]
        : propertyData['availableFrom'] as String? ?? 'N/A';
    final lat = propertyData['lat'] as double? ?? 23.8103;
    final long = propertyData['long'] as double? ?? 90.4125;

    return Scaffold(
      appBar: AppBar(
        title: Text('Property Details'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Container(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  final image = images[index] as String;
                  final userId = propertyData['userId'] as String;
                  return Padding(
                    padding: EdgeInsets.only(right: 8.0),
                    child: GestureDetector(
                      onTap: () => _showFullScreenImage(context, userId, uuid, image),
                      child: FutureBuilder<Widget>(
                        future: _fetchImage(context, userId, uuid, image),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return Shimmer.fromColors(
                              baseColor: Colors.grey[300]!,
                              highlightColor: Colors.grey[100]!,
                              child: Container(
                                width: 300,
                                color: Colors.grey[300],
                              ),
                            );
                          }
                          if (snapshot.hasError) {
                            return Container(
                              width: 300,
                              color: Colors.grey[300],
                              child: Center(child: Text('Error loading image')),
                            );
                          }
                          return snapshot.data ?? Container(
                            width: 300,
                            color: Colors.grey[300],
                            child: Center(child: Text('Image not available')),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16),

            Text(
              location,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 8),
            Divider(color: Colors.grey[300]),
            SizedBox(height: 8),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.king_bed, size: 20, color: Colors.grey[700]),
                    SizedBox(width: 4),
                    Text(
                      '$rooms rooms, $floor floor',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '৳$rent',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
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
                  ],
                ),
              ],
            ),
            SizedBox(height: 8),

            Row(
              children: [
                if (liftAvailable)
                  Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Row(
                      children: [
                        Icon(Icons.elevator, color: Colors.green, size: 20),
                        SizedBox(width: 4),
                        Text('Lift', style: TextStyle(fontSize: 14, color: Colors.black87)),
                      ],
                    ),
                  ),
                if (parkingAvailable)
                  Padding(
                    padding: EdgeInsets.only(right: 12),
                    child: Row(
                      children: [
                        Icon(Icons.local_parking, color: Colors.green, size: 20),
                        SizedBox(width: 4),
                        Text('Parking', style: TextStyle(fontSize: 14, color: Colors.black87)),
                      ],
                    ),
                  ),
                if (utilityIncluded)
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.green, size: 20),
                      SizedBox(width: 4),
                      Text('Utilities', style: TextStyle(fontSize: 14, color: Colors.black87)),
                    ],
                  ),
              ],
            ),
            SizedBox(height: 16),
            Divider(color: Colors.grey[300]),
            SizedBox(height: 16),

            Text(
              'Property Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 12),
            _buildDetailRow('Area', '$area sq ft'),
            _buildDetailRow('Contact', contact),
            _buildDetailRow('Home Type', homeType),
            _buildDetailRow('Available From', availableFrom),
            SizedBox(height: 16),
            Divider(color: Colors.grey[300]),
            SizedBox(height: 16),

            Text(
              'Description',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 8),
            Text(
              description,
              style: TextStyle(fontSize: 16, color: Colors.black54, height: 1.5),
            ),
            SizedBox(height: 16),
            Divider(color: Colors.grey[300]),
            SizedBox(height: 16),

            Text(
              'Location on Map',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: FlutterMap(
                options: MapOptions(
                  center: LatLng(lat, long),
                  zoom: 15.0,
                  interactiveFlags: InteractiveFlag.all & ~InteractiveFlag.rotate,
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
                        point: LatLng(lat, long),
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
            SizedBox(height: 24),

            Center(
              child: ElevatedButton(
                onPressed: () {

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Apply Now clicked!')),
                  );
                },
                child: Text('Apply Now'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
                  textStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.black87),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          ),
        ],
      ),
    );
  }
}