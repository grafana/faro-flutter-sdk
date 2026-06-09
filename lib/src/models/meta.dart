import 'package:faro/src/models/app.dart';
import 'package:faro/src/models/browser.dart';
import 'package:faro/src/models/device.dart';
import 'package:faro/src/models/faro_user.dart';
import 'package:faro/src/models/os.dart';
import 'package:faro/src/models/page.dart';
import 'package:faro/src/models/sdk.dart';
import 'package:faro/src/models/session.dart';
import 'package:faro/src/models/view_meta.dart';

class Meta {
  Meta({
    this.session,
    this.sdk,
    this.app,
    this.view,
    this.browser,
    this.page,
    this.user,
    this.device,
    this.os,
  });

  Meta.fromJson(dynamic json) {
    session = json['session'] != null
        ? Session.fromJson(json['session'])
        : null;
    sdk = json['sdk'] != null ? Sdk.fromJson(json['sdk']) : null;
    app = json['app'] != null ? App.fromJson(json['app']) : null;
    view = json['view'] != null ? ViewMeta.fromJson(json['view']) : null;
    browser = json['browser'] != null
        ? Browser.fromJson(json['browser'])
        : null;
    page = json['page'] != null ? Page.fromJson(json['page']) : null;
    user = json['user'] != null ? FaroUser.fromJson(json['user']) : null;
    device = json['device'] != null ? Device.fromJson(json['device']) : null;
    os = json['os'] != null ? Os.fromJson(json['os']) : null;
  }
  Session? session;
  Sdk? sdk;
  App? app;
  ViewMeta? view;
  Browser? browser;
  Page? page;
  FaroUser? user;
  Device? device;
  Os? os;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (session != null) {
      map['session'] = session!.toJson();
    }
    if (sdk != null) {
      map['sdk'] = sdk!.toJson();
    }
    if (app != null) {
      map['app'] = app!.toJson();
    }
    if (view != null) {
      map['view'] = view!.toJson();
    }
    if (browser != null) {
      map['browser'] = browser!.toJson();
    }
    if (page != null) {
      map['page'] = page!.toJson();
    }
    if (user != null) {
      map['user'] = user!.toJson();
    }
    if (device != null) {
      map['device'] = device!.toJson();
    }
    if (os != null) {
      map['os'] = os!.toJson();
    }
    return map;
  }

  /// Creates a JSON representation for Faro protocol.
  /// Session attributes are stringified as required by Faro.
  Map<String, dynamic> toFaroJson() {
    final map = <String, dynamic>{};
    if (session != null) {
      map['session'] = session!.toFaroJson();
    }
    if (sdk != null) {
      map['sdk'] = sdk!.toJson();
    }
    if (app != null) {
      map['app'] = app!.toJson();
    }
    if (view != null) {
      map['view'] = view!.toJson();
    }
    if (browser != null) {
      map['browser'] = browser!.toJson();
    }
    if (page != null) {
      map['page'] = page!.toJson();
    }
    if (user != null) {
      map['user'] = user!.toJson();
    }
    if (device != null) {
      map['device'] = device!.toJson();
    }
    if (os != null) {
      map['os'] = os!.toJson();
    }
    return map;
  }
}
