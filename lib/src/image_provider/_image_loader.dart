import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cached_network_image_platform_interface/cached_network_image_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

import 'package:cached_network_image_platform_interface'
        '/cached_network_image_platform_interface.dart' as platform
    show ImageLoader;
import 'package:cached_network_image_platform_interface'
        '/cached_network_image_platform_interface.dart'
    show ImageRenderMethodForWeb;
import 'package:xxtea/xxtea.dart';

/// ImageLoader class to load images on IO platforms.
class ImageLoader implements platform.ImageLoader {
  @override
  Stream<ui.Codec> loadAsync(
    String url,
    String? cacheKey,
    StreamController<ImageChunkEvent> chunkEvents,
    DecoderCallback decode,
    BaseCacheManager cacheManager,
    int? maxHeight,
    int? maxWidth,
    Map<String, String>? headers,
    Function()? errorListener,
    ImageRenderMethodForWeb imageRenderMethodForWeb,
    Function() evictImage,
  ) async* {
    try {
      assert(
          cacheManager is ImageCacheManager ||
              (maxWidth == null && maxHeight == null),
          'To resize the image with a CacheManager the '
          'CacheManager needs to be an ImageCacheManager. maxWidth and '
          'maxHeight will be ignored when a normal CacheManager is used.');
      String encryptType='';
      if(url.endsWith('.t')||url.endsWith('.tg')){
        encryptType='xjmh';
      }
      if(url.endsWith('.lu')){
        encryptType='91lu';
        url=url.replaceAll(".lu", "");
      }

      var stream = cacheManager is ImageCacheManager
          ? cacheManager.getImageFile(url,
              maxHeight: maxHeight,
              maxWidth: maxWidth,
              withProgress: true,
              headers: headers,
              key: cacheKey)
          : cacheManager.getFileStream(url,
              withProgress: true, headers: headers, key: cacheKey);

      await for (var result in stream) {
        if (result is DownloadProgress) {
          chunkEvents.add(ImageChunkEvent(
            cumulativeBytesLoaded: result.downloaded,
            expectedTotalBytes: result.totalSize,
          ));
        }
        if (result is FileInfo) {
          var file = result.file;
          var bytes = await file.readAsBytes();
          bytes=decrypt(bytes, encryptType);
          var decoded = await decode(bytes);
          yield decoded;
        }
      }
    } catch (e) {
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        evictImage();
      });

      errorListener?.call();
      rethrow;
    } finally {
      await chunkEvents.close();
    }
  }
  Uint8List decrypt(Uint8List bytes,String type){
    Uint8List res=bytes;
    switch(type){
      case 'xjmh':
        var tmp=xxtea.decrypt(bytes, 'sNtMmZ48y1KTY8wq');
        if(tmp==null){
          print('图像解密失败');
        }else{
          res=tmp;
        }
        break;
      case '91lu':
        ByteBuffer buffer = bytes.buffer;
        res=buffer.asUint8List(8);
        break;

    }
    return res;
  }
}
