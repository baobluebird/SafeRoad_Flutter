import 'package:flutter/material.dart';

class MyTextFormFieldForPass extends StatelessWidget {
  final String? errorInput;
  final TextEditingController inputController;

  final String hintText;
  final IconData? icon;
  final void Function()? onPressed;
  final bool obsecureText;

  MyTextFormFieldForPass({super.key,
    required this.hintText,
    this.icon,
    this.onPressed,
    this.obsecureText = false, required this.inputController, this.errorInput});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.0),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: inputController,
        autofocus: false,
        obscureText: obsecureText,
        decoration: InputDecoration(
          labelText: hintText,
          contentPadding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
          border: InputBorder.none,
          prefixIcon: Icon(icon,color: Colors.blue),
          suffixIcon: IconButton(
            icon: Icon(obsecureText ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              onPressed!();
            },
          ),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return errorInput;
          }
          return null;
        },
      ),
    );
  }
}

class MyTextFormField extends StatelessWidget {
  final String? errorInput;
  final TextEditingController inputController;

  final String hintText;
  final IconData? icon;
  final void Function()? onPressed;
  final bool obsecureText;

  MyTextFormField({super.key,
    required this.hintText,
    this.icon,
    this.onPressed,
    this.obsecureText = false, required this.inputController, this.errorInput});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30.0),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.5),
            spreadRadius: 1,
            blurRadius: 2,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: inputController,
        autofocus: false,
        obscureText: obsecureText,
        decoration: InputDecoration(
          labelText: hintText,
          contentPadding: const EdgeInsets.fromLTRB(20.0, 10.0, 20.0, 10.0),
          border: InputBorder.none,
          prefixIcon: Icon(icon,color: Colors.blue),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return errorInput;
          }
          return null;
        },
      ),
    );
  }
}
