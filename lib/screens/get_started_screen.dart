import 'package:flutter/material.dart';
import 'package:inventory/screens/signin_screen.dart';


class GetStartedScreen extends StatelessWidget {
  const GetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Image.asset(
            'assets/images/delivery.png',
            fit: BoxFit.contain,
            height: 150,
            width: 150,
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: [
            const Text(
              'Welcome',
              style: TextStyle(
              fontSize:30,
              fontWeight: FontWeight.bold,
              color: Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.fromLTRB(16,0,16,0),
              child: const Text(
                'Get started to manage your inventory ease.',
                style: TextStyle(
                fontSize: 20,
                color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            ],
          ),
        
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: Center(
              child: SizedBox(
              width: 200,
              child: ElevatedButton(
                onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const SignInScreen()),
                );
                },
                style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
                ),
                child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Text(
                  'Get Started',
                  style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  ),
                ),
                ),
              ),
              ),
            ),
            ),
          const SizedBox(height: 30),
          ],
        ),
        ),
      ),
      ),
    );
  }
}
