class Page {
  String url = "";

  Page(this.url);

  Page.fromJson(dynamic json) {
    url = json['url'];
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['url'] = url;
    return map;
  }
}
