import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:pothole/screens/sign_up.dart';

import '../components/text_form_field.dart';
import '../page/home_admin.dart';
import '../page/home_user.dart';
import '../services/login_service.dart';
import '../utils/snack_bar.dart';
import 'forgot_password.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SigninScreen extends StatefulWidget {
  final List<CameraDescription>? cameras;

  const SigninScreen({Key? key, this.cameras}) : super(key: key);

  @override
  State<SigninScreen> createState() => _SigninScreenState();
}

class _SigninScreenState extends State<SigninScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final myBox = Hive.box('myBox');

  bool _isLoading = false;
  bool isError = true;
  bool _isAdmin = false;
  String serverMessage = '';
  String token = '';

  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> _signInWithGoogle() async {
    try {
      await _googleSignIn.signOut(); // đảm bảo chọn lại tài khoản mỗi lần
      final GoogleSignInAccount? account = await _googleSignIn.signIn();

      if (account != null) {
        final email = account.email;
        final name = account.displayName ?? '';
        final googleId = account.id;

        final response = await SignInService.signInWithGoogle({
          "email": email,
          "name": name,
          "googleId": googleId,
        });

        if (response['status'] == "OK") {
          final String accessToken = response['access_token'];

          await myBox.put('userId', response['userId']);
          await myBox.put('name', response['name']);
          await myBox.put('isAdmin', response['isAdmin'] ?? false);
          await myBox.put('token', accessToken);

          final decoded = await DecodeTokenService.decodeToken(accessToken);
          if (decoded['status'] == "OK") {
            if (response['isAdmin'] == true) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => AdminHome()),
              );
            } else {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => UserHome()),
              );
            }

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Google Sign-In successful'), backgroundColor: Colors.green),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Token decode failed'), backgroundColor: Colors.red),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message']), backgroundColor: Colors.red),
          );
        }
      }
    } catch (error) {
      print("Google Sign-In error: $error");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: $error'), backgroundColor: Colors.red),
      );
    }
  }



  Future<void> _signIn() async {
    if (_formKey.currentState?.validate() ?? false) {
      try {
        final Map<String, dynamic> response = await SignInService.signIn(
          _emailController.text,
          _passwordController.text,
        );

        print('Response status: ${response['status']}');
        print('Response body: ${response['message']}');
        print('Response body: ${response['access_token']}');

        if (response['status'] == "OK") {
          token = response['access_token'];
          await myBox.put('userId', response['userId']);
          await myBox.put('name', response['name']);
          final Map<String, dynamic> responseToken =
              await DecodeTokenService.decodeToken(token);
          if (responseToken['status'] == "OK") {
            setState(() {
              serverMessage = response['message'];
            });
            print('Login successful');
            if (response['isAdmin'] == true) {
              _isAdmin = true;
              await myBox.put('isAdmin', true);
            } else {
              await myBox.put('isAdmin', false);
              _isAdmin = false;
            }
          }else{
            setState(() {
              serverMessage = responseToken['message'];
              isError = true;
            });
            print('Login failed: ${responseToken['message']}');
          }
          print("success stored to hive");
          setState(() {
            serverMessage = response['message'];
            isError = false;
          });
          print('Login successful');
        } else {
          setState(() {
            serverMessage = response['message'];
            isError = true;
          });
          print('Login failed: ${response['message']}');
        }
      } catch (error) {
        setState(() {
          isError = true;
          serverMessage = 'Error: $error';
        });
        print('Error: $error');
      }
    }
  }

  Future<void> remember() async {
    await myBox.put('token', token);
  }

  bool showPass = true;
  bool checkTheBox = false;

  showPassword() {
    setState(() {
      showPass = !showPass;
    });
  }

  check() {
    setState(() {
      checkTheBox = !checkTheBox;
    });
  }

  // @override
  // void dispose() {
  //   super.dispose();
  //   _emailController.dispose();
  //   _passwordController.dispose();
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomAppBar(
        color: Colors.transparent,
        elevation: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Don\'t have an account?',
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SignupScreen(),
                  ),
                );
              },
              child: const Text(
                'Sign up',
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
      ),
      body:  SingleChildScrollView(
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
                        const SizedBox(height: 20),
                        Image.asset(
                          'assets/images/logo_app.png',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Login to your account',
                          style:  GoogleFonts.openSans(
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 20),
                        MyTextFormField(
                          hintText: 'Email',
                          inputController: _emailController,
                          icon: Icons.email,
                          errorInput: 'Please enter your email',
                        ),
                        const SizedBox(height: 10),
                        MyTextFormFieldForPass(
                          hintText: 'Password',
                          inputController: _passwordController,
                          obsecureText: showPass,
                          icon: Icons.lock,
                          errorInput: 'Please enter your password',
                          onPressed: () {
                            setState(() {
                              showPass = !showPass;
                            });
                          },
                        ),
                        const SizedBox(height: 20),
                          CheckboxListTile(
                          title: const Text(
                            'Remember Password',
                            style: TextStyle(
                              fontFamily: 'Open Sans',
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          value: checkTheBox ? true : false,
                          onChanged: (bool? newValue) {
                            check();
                          },
                          controlAffinity: ListTileControlAffinity.leading,
                          activeColor: Colors.blue,
                        ),
                        const SizedBox(height: 10),
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
                            onPressed: () async {
                              FocusScope.of(context).requestFocus(FocusNode());
                              if (_formKey.currentState!.validate()) {
                                if (!_isLoading) {
                                  setState(() {
                                    _isLoading = true;
                                  });
                                  await _signIn();
                                  if (!isError) {
                                    if (checkTheBox) {
                                      await remember();
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(serverMessage),
                                        duration: const Duration(seconds: 1),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                   if (_isAdmin == true) {
                                      print('admin');
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              AdminHome(),
                                        ),
                                      );
                                   } else {
                                      print('user');
                                      Navigator.pushReplacement(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => UserHome(),
                                        ),
                                      );
                                    }
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
                              } else {
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
                              'Sign in',
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
                          child: TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const ForgotPasswordScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: Color.fromARGB(100, 3, 58, 107),
                                fontSize: 16.0,
                                fontFamily: 'WorkSansMedium',
                              ),
                            ),
                          ),
                        ),
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
                                      Colors.black,
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
                            Container(
                              padding: const EdgeInsets.all(7),
                              child:  Image.asset(
                                'assets/images/facebook.png',
                                width: 100,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(width: 5),
                            GestureDetector(
                              onTap: _signInWithGoogle,
                              child: Image.asset(
                                "assets/images/google.png",
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
            ],
          ),
      ),

    );
  }
}
