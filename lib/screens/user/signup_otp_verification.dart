import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../model/user.dart';
import '../../services/user_service.dart';
import 'sign_in.dart';

class SignupOTPVerificationScreen extends StatefulWidget {
  final String email;
  final String id;
  final User user;

  const SignupOTPVerificationScreen({
    Key? key,
    required this.email,
    required this.id,
    required this.user,
  }) : super(key: key);

  @override
  State<SignupOTPVerificationScreen> createState() => _SignupOTPVerificationScreenState();
}

class _SignupOTPVerificationScreenState extends State<SignupOTPVerificationScreen> {
  String serverMessage = '';
  String? codeDigit1, codeDigit2, codeDigit3, codeDigit4, codeDigit5;
  bool _isVerifying = false;

  Future<void> _verifyAndSignUp() async {
    String code = "$codeDigit1$codeDigit2$codeDigit3$codeDigit4$codeDigit5";
    setState(() => _isVerifying = true);

    final verifyRes = await VerifyCodeService.verifyCode(widget.id, code);

    if (verifyRes['status'] == 'OK') {
      final signupRes = await SignUpService.signUp(widget.user);
      if (signupRes['status'] == 'OK') {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đăng ký thành công!'), backgroundColor: Colors.green),
        );
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const SigninScreen()),
              (_) => false,
        );
      } else {
        _showError(signupRes['message']);
      }
    } else {
      _showError(verifyRes['message']);
    }

    setState(() => _isVerifying = false);
  }

  void _showError(String? message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message ?? 'Xác minh thất bại'), backgroundColor: Colors.red),
    );
  }

  Widget _buildCodeInput(void Function(String) onChanged) {
    return SizedBox(
      height: 68,
      width: 64,
      child: TextFormField(
        onChanged: onChanged,
        decoration: const InputDecoration(hintText: '0'),
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        inputFormatters: [
          LengthLimitingTextInputFormatter(1),
          FilteringTextInputFormatter.digitsOnly,
        ],
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Xác thực email")),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Nhập mã xác thực gồm 5 chữ số đã gửi đến email của bạn:',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 24),
            Form(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildCodeInput((v) { codeDigit1 = v; if (v.length == 1) FocusScope.of(context).nextFocus(); }),
                  _buildCodeInput((v) { codeDigit2 = v; if (v.length == 1) FocusScope.of(context).nextFocus(); }),
                  _buildCodeInput((v) { codeDigit3 = v; if (v.length == 1) FocusScope.of(context).nextFocus(); }),
                  _buildCodeInput((v) { codeDigit4 = v; if (v.length == 1) FocusScope.of(context).nextFocus(); }),
                  _buildCodeInput((v) { codeDigit5 = v; if (v.length == 1) FocusScope.of(context).unfocus(); }),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isVerifying ? null : _verifyAndSignUp,
              child: _isVerifying ? const CircularProgressIndicator() : const Text('Xác thực & Đăng ký'),
            ),
          ],
        ),
      ),
    );
  }
}
