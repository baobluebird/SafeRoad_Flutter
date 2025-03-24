import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pothole/screens/sign_in.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../components/text_form_field.dart';
import '../model/user.dart';
import '../services/login_service.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _dateController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn();


  User? user;
  bool _isLoading = false;
  bool isError = true;
  String serverMessage = '';

  Future<void> _signUpWithGoogle() async {
    try {
      // 🔥 Force sign out trước
      await _googleSignIn.signOut();

      // Sau đó bắt đầu lại quá trình đăng nhập
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account != null) {
        final email = account.email;
        final name = account.displayName ?? '';
        final id = account.id;

        final user = {
          "email": email,
          "name": name,
          "googleId": id,
        };

        final response = await SignUpService.signUpWithGoogle(user);
        if (response['status'] == 'OK') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message']), backgroundColor: Colors.green),
          );
          Navigator.of(context).push(MaterialPageRoute(builder: (context) => const SigninScreen()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message']), backgroundColor: Colors.red),
          );
        }
      }
    } catch (error) {
      print("Google Sign-In error: $error");
    }
  }


  Future<void> _selectDate(BuildContext context) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null) {
      setState(() {
        _dateController.text = pickedDate.toString().split(" ")[0];
      });
    }
  }


  Future<void> _signUp() async {
    if (_formKey.currentState?.validate() ?? false) {
      user = User(
        name: _nameController.text,
        date: _dateController.text,
        email: _emailController.text,
        password: _passwordController.text,
        confirmPassword: _confirmPasswordController.text,
        phone: _phoneController.text,
      );
      try {
        final response = await SignUpService.signUp(user!);
        if (response['status'] == "OK") {
          setState(() {
            serverMessage = response["message"];
            isError = false;
          });
          print('Create successful');
        } else {
          print(response);
          setState(() {
            serverMessage = response['message'];
            isError = true;
          });
          print('Create failed: ${response['message']}');
        }
      } catch (error) {
        setState(() {
          serverMessage = 'Error: $error';
          isError = true;
        });
        print('Error: $error');
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
                      Text(
                        'Create your account',
                        style:  GoogleFonts.openSans(
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 16),
                      MyTextFormField(
                        hintText: 'Name',
                        inputController: _nameController,
                        icon: Icons.person_outline,
                        errorInput: 'Please enter your email',
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () => _selectDate(context),
                        child: AbsorbPointer(
                          child: MyTextFormField(
                            hintText: 'Date of Birth',
                            inputController: _dateController,
                            icon: Icons.calendar_today,
                            errorInput: 'Please select your date of birth',
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      MyTextFormField(
                        hintText: 'Email',
                        inputController: _emailController,
                        icon: Icons.email_outlined,
                        errorInput: 'Please enter your email',
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
                      const SizedBox(height: 10),
                      MyTextFormField(
                        hintText: 'Phone',
                        inputController: _phoneController,
                        icon: Icons.phone_outlined,
                        errorInput: 'Please enter your phone',
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
                        width: 160,
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
                                await _signUp();
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
                            'Sign up',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'Open Sans',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.only(top: 10.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    Colors.grey,
                                    Colors.black26,
                                  ],
                                  begin: FractionalOffset(0.0, 0.0),
                                  end: FractionalOffset(1.0, 1.0),
                                  stops: <double>[0.0, 1.0],
                                  tileMode: TileMode.clamp,
                                ),
                              ),
                              width: 100.0,
                              height: 1.0,
                            ),
                            const Padding(
                              padding: EdgeInsets.only(left: 15.0, right: 15.0),
                              child: Text(
                                'Or',
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 16.0,
                                  fontFamily: 'WorkSansMedium',
                                ),
                              ),
                            ),
                            Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: <Color>[
                                    Colors.grey,
                                    Colors.black26,
                                  ],
                                  begin: FractionalOffset(0.0, 0.0),
                                  end: FractionalOffset(1.0, 1.0),
                                  stops: <double>[0.0, 1.0],
                                  tileMode: TileMode.clamp,
                                ),
                              ),
                              width: 100.0,
                              height: 1.0,
                            ),
                          ],
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _signUpWithGoogle,
                            child: Image.asset(
                              "assets/images/google.png",
                              width: 100,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.all(7),
                            child: Image.asset(
                              "assets/images/facebook.png",
                              width: 100,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.all(7),
                            child: Image.asset(
                              "assets/images/apple.png",
                              width: 100,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Already have an account?',
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SigninScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Sign in',
                    style: TextStyle(
                      fontSize: 20,
                      color: Colors.lightBlue,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'NotoSans-Italic-VariableFont_wdth,wght.ttf',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
