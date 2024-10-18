class User {
  String? id;
  String? username;
  String? email;

  User({this.id, this.username, this.email});

  User.fromJson(dynamic json) {
    id = json['id'];
    username = json['username'];
    email = json['email'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};

    map['username'] = username;
    map['id'] = id;
    map['email'] = email;

    return map;
  }
}
