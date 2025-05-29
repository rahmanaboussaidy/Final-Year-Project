import 'package:flutter/material.dart';
import 'package:inventory/screens/home_screen.dart';
import 'package:inventory/screens/signup_screen.dart';
import 'package:inventory/services/service.dart';


class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  void _showSnackBar(String message, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color ?? Colors.red),
    );
  }

  Future<void> _onLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('Email and password are required.');
      return;
    }

    setState(() => _isLoading = true);

    final error = await AuthService().loginWithEmail(
      email: email,
      password: password,
    );

    if (error == null) {
      _showSnackBar('Login successful!', color: Colors.green);
      // Navigate to Home screen or dashboard
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _showSnackBar(error);
    }

    setState(() => _isLoading = false);
  }

  Future<void> _onGoogleLogin() async {
    setState(() => _isLoading = true);
    final error = await AuthService().signInWithGoogle();
    if (error == null) {
      _showSnackBar('Google login successful!', color: Colors.green);
       Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      _showSnackBar(error);
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Text('Sign In', style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 32),
                    Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Email',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      hintText: 'Enter your email',
                      border: OutlineInputBorder(),
                    ),
                    ),
                  
                  const SizedBox(height: 16),
                    Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Password',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      border: const OutlineInputBorder(),
                      suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    ),
                    Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                      Navigator.pushNamed(context, '/reset');
                      },
                      child: const Text(
                      'Forgot Password?',
                      style: TextStyle(color: Colors.blue),
                      ),
                    ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      ),
                      onPressed: _isLoading ? null : _onLogin,
                      child: _isLoading
                        ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                        : const Text('Sign In'),
                    )
                    
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8.0),
                        child: Text('OR'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      ),
                      icon: Image.asset('assets/images/google.png', height: 24, width: 24),
                      label: const Text('Continue with Google'),
                      onPressed: _isLoading ? null : _onGoogleLogin,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text("Don't have an account?"),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (_) => const SignupScreen()),
                        ),
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
