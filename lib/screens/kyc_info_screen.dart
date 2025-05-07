import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'kyc_nid_screen.dart';

class KycInfoScreen extends StatefulWidget {
  const KycInfoScreen({super.key});

  @override
  _KycInfoScreenState createState() => _KycInfoScreenState();
}

class _KycInfoScreenState extends State<KycInfoScreen> {
  final _nameController = TextEditingController();
  final _professionController = TextEditingController();
  final _emailController = TextEditingController();
  DateTime? _dob;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    final user = _auth.currentUser;
    if (user != null && user.phoneNumber != null) {
      // Phone number is already available from auth
    }
  }

  void _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dob) {
      setState(() {
        _dob = picked;
      });
    }
  }

  void _proceed() {
    if (_nameController.text.isEmpty ||
        _professionController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final user = _auth.currentUser;
    if (user == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KycNidScreen(
          name: _nameController.text,
          profession: _professionController.text,
          dob: _dob!,
          email: _emailController.text,
          phone: user.phoneNumber ?? '',
          currentStep: 1, // Step 1 of 3
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    return Scaffold(
      appBar: AppBar(title: const Text('KYC - Personal Info')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              const LinearProgressIndicator(value: 0.33), // Step 1 of 3
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _professionController,
                decoration: InputDecoration(
                  labelText: 'Profession',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: AbsorbPointer(
                  child: TextField(
                    controller: TextEditingController(
                      text: _dob != null ? DateFormat('yyyy-MM-dd').format(_dob!) : '',
                    ),
                    decoration: InputDecoration(
                      labelText: 'Date of Birth',
                      border: const OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.grey[300],
                      hintText: 'Select Date',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                enabled: false,
                controller: TextEditingController(text: user?.phoneNumber ?? 'Not available'),
                decoration: InputDecoration(
                  labelText: 'Mobile Number',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[300],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  filled: true,
                  fillColor: Colors.grey[300],
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _proceed,
                child: const Text('Proceed'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}