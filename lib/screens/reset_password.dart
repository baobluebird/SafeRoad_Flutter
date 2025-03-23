import 'package:flutter/material.dart';
import 'package:pothole/screens/sign_in.dart';

import '../components/text_form_field.dart';
import '../services/login_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String? userId;
  ResetPasswordScreen({super.key, required this.userId});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool isError = true;
  String serverMessage = '';

  Future<void> _resetPass() async {
    print(widget.userId);
    if (_formKey.currentState?.validate() ?? false) {
    try {
      final Map<String, dynamic> response =
      await ResetPassService.resetPass(widget.userId!, _passwordController.text,
          _confirmPasswordController.text);
      print(response);
      if (response['status'] == 'OK') {
        setState(() {
          isError = false;
          serverMessage = response['message'];
        });
      } else {
        setState(() {
          isError = true;
          serverMessage = response['message'];
        });
        print('Error occurred: ${response['message']}');
      }
    } catch (e) {
      setState(() {
        serverMessage = 'Error: $e';
      });
      print('Error occurred: $e');
    }
  }
  }

  bool showPass = true;
  bool showConfirm = true;

  showConfPass() {
    setState(() {
      showConfirm = !showConfirm;
    });
  }

  showPassword() {
    setState(() {
      showPass = !showPass;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Center(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Image.asset(
                        'assets/images/logo_app.png',
                        width: MediaQuery.of(context).size.width * 0.3,
                        height: MediaQuery.of(context).size.width * 0.3,
                        fit: BoxFit.contain,
                      ),
                      const Text(
                        'Reset Password',
                        style: TextStyle(fontSize: 18, fontFamily: 'Open Sans'),
                      ),
                      const SizedBox(height: 16),
                      MyTextFormFieldForPass(
                        hintText: 'Password',
                        inputController: _passwordController,
                        obsecureText: showPass,
                        icon: Icons.lock_outline,
                        errorInput: 'Please enter your password',
                        onPressed: () {
                          setState(() {
                            showPass = !showPass;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      MyTextFormFieldForPass(
                        hintText: 'Confirm Password',
                        inputController: _confirmPasswordController,
                        obsecureText: showPass,
                        icon: Icons.lock_outline,
                        errorInput: 'Please enter your confirm password',
                        onPressed: () {
                          setState(() {
                            showPass = !showPass;
                          });
                        },
                      ),
                      const SizedBox(height: 20),
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(30.0),
                          color: Colors.blueAccent,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26.withOpacity(0.3),
                              spreadRadius: 1,
                              blurRadius: 3,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        height: 50,
                        width: 180,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                            if (_formKey.currentState!.validate()) {
                              FocusScope.of(context).requestFocus(FocusNode());
                              if (!_isLoading) {
                                setState(() {
                                  _isLoading = true;
                                });
                                await _resetPass();
                                if (!isError) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(serverMessage),
                                      duration: const Duration(seconds: 1),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                  Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (context) => const SigninScreen(),
                                      ));
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(serverMessage),
                                      duration: const Duration(seconds: 2),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                                setState(() {
                                  _isLoading = false;
                                });
                              }
                            }else{
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill in all fields'),
                                  duration: Duration(seconds: 2),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            backgroundColor: Colors.blue,
                          ),
                          child: const Text(
                            'Reset Password',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Open Sans',
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
