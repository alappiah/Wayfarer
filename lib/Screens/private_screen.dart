import 'package:flutter/material.dart';

class PrivateScreen extends StatelessWidget {
  const PrivateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.lock,
            size: 80,
            color: Colors.grey,
          ),
          SizedBox(height: 16),
          Text(
            "Private Entries",
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            "Your private journal entries will appear here",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}