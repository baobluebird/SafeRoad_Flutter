class User {
  String name;
  String date;
  String email;
  String password;
  String confirmPassword;
  String phone;

 User({
    required this.name,
    required this.date,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.phone,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      name: json['name'],
      date: json['date'],
      email: json['email'],
      password: json['password'],
      confirmPassword: json['confirmPassword'],
      phone: json['phone'],
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'date': date,
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
        'phone': phone,
      };

}