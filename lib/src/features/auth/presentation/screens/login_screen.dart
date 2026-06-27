import 'package:flutter/material.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'SECURE\nACCESS',
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w100,
                letterSpacing: 8,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 60),
            TextField(
              decoration: InputDecoration(
                hintText: 'AGENT ID',
                hintStyle: TextStyle(color: Colors.white24, letterSpacing: 2),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              obscureText: true,
              decoration: InputDecoration(
                hintText: 'PASSCODE',
                hintStyle: TextStyle(color: Colors.white24, letterSpacing: 2),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white10)),
              ),
            ),
            const SizedBox(height: 60),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFFD700),
                  foregroundColor: Colors.black,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                onPressed: () {
                  // Navigate to PTT Screen
                },
                child: const Text('AUTHORIZE', style: TextStyle(letterSpacing: 4, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
