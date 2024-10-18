
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:rum_sdk/rum_flutter.dart';

class RumAssetBundle extends AssetBundle{
  AssetBundle _bundle;
  RumAssetBundle({
    AssetBundle? bundle
}): _bundle = bundle?? rootBundle;

  @override
  Future<ByteData> load(String key) async {
    ByteData? data;
    int? dataSize;
    try{
      var beforeLoad = DateTime.now().millisecondsSinceEpoch;
      data = await _bundle.load(key);
      var afterLoad = DateTime.now().millisecondsSinceEpoch;
      int duration = afterLoad - beforeLoad;
      dataSize = _getDataLength(data);
      RumFlutter().pushEvent("Asset-load",attributes: {
       "name":_getFileName(key),
       "size":"$dataSize",
        "duration":"$duration"
      });
    } catch(exception){
      rethrow;
    }
    return data;

  }
  @override
  Future<String> loadString(String key,{bool cache=true}) async{
    String? data;
    int? dataSize;
    try{
      var beforeLoad = DateTime.now().millisecondsSinceEpoch;
      data = await _bundle.loadString(key,cache:cache);
      var afterLoad = DateTime.now().millisecondsSinceEpoch;
      int duration = afterLoad-beforeLoad;
      dataSize = _getDataLength(data);
      RumFlutter().pushEvent("Asset-load", attributes: {
        "name":_getFileName(key),
        "size":"$dataSize",
        "duration":"$duration"
      }
      );
    } catch (exception){
      rethrow;
    }
    return data;
  }


  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) {
    return _bundle.loadStructuredData(key, parser);
  }

  String? _getFileName(String key){
    final uri = Uri.tryParse(key);
    if (uri == null) {
      return key;
    }
    return uri.pathSegments.isEmpty ? key : uri.pathSegments.last;
  }

  int?  _getDataLength(dynamic data){
    int? dataLength;
    if(data is List<int>){
      dataLength = data.length;
    }
    else if(data is ByteData){
      dataLength = data.lengthInBytes;
    }
    else if (data is ImmutableBuffer){
      dataLength = data.length;
    }
    return dataLength;

  }
  
}