class Detection {
  String id;
  String name;
  String user;
  String location;
  String address;
  String description;
  String createdAt;

  Detection({
      required this.id,
      required this.name,
      required this.user,
      required this.location,
      required this.address,
      required this.description,
      required this.createdAt,
  });

  factory Detection.fromJson(Map<String, dynamic> json) {
    return Detection(
      id: json['_id'],
      name: json['name'],
      user: json['user'],
      location: json['location'],
      address: json['address'],
      description: json['description'],
      createdAt: json['createdAt'],
    );
  }

  Map<String, dynamic> toJson() => {
    '_id': id,
    'name': name,
    'user': user,
    'location': location,
    'address': address,
    'description': description,
    'createdAt': createdAt,
  };
}
