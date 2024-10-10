import 'dart:isolate';
import 'dart:typed_data';

import 'package:fractal_stranger/magic.dart';
import 'package:image/image.dart' as imglib;

typedef RenderArea = ({
  int width,
  int height,
  double scale,
  double offsetX,
  double offsetY,
});

Uint8List renderPlug(RenderArea area) {
  var image = imglib.Image(width: area.width, height: area.height);
  for (int x = 0; x < area.width; ++x) {
    for (int y = 0; y < area.height; ++y) {
      image.setPixelRgb(x, y, x * 256 ~/ area.width, y * 256 ~/ area.height, 128);
    }
  }
  return imglib.encodeBmp(image);
}

void render(SendPort sendPort) {
  // print('B');
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);
  receivePort.listen((message) {
    if (message is String) {
      if (message == 'die') {
        Isolate.exit();
      }
    } else if (message is RenderArea) {
      final renderArea = message;
      var image = imglib.Image(width: renderArea.width, height: renderArea.height);
      double visibleWidth = renderArea.width / renderArea.scale;
      double visibleHeight = renderArea.height / renderArea.scale;
      double halfWidth = visibleWidth / 2;
      double halfHeight = visibleHeight / 2;
      double magicMin = doMagic((x: -halfWidth - renderArea.offsetX, y: -halfHeight - renderArea.offsetY));
      double magicMax = magicMin;
      final buffSize = renderArea.width * renderArea.height;
      var buffer = List<double>.filled(buffSize, 0.0);
      double progressMem = 0;
      double progressDelta = 0.01;
      for (int x = 0; x < renderArea.width; ++x) {
        for (int y = 0; y < renderArea.height; ++y) {
          double magic = doMagic((
            x: x * visibleWidth / renderArea.width - halfWidth - renderArea.offsetX,
            y: y * visibleHeight / renderArea.height - halfHeight - renderArea.offsetY
          ));
          final index = x * renderArea.height + y;
          final progress = index / buffSize;
          if (progress > progressMem + progressDelta) {
            sendPort.send(progress);
            progressMem = progress;
          }
          buffer[index] = magic;
          if (magic < magicMin) {
            magicMin = magic;
          } else if (magic > magicMax) {
            magicMax = magic;
          }
        }
      }

      double correction;
      if (magicMin < magicMax) {
        correction = 1 / (magicMax - magicMin) * 255;
      } else {
        correction = -1;
      }
      for (int x = 0; x < renderArea.width; x++) {
        for (int y = 0; y < renderArea.height; y++) {
          int value;
          if (correction > 0) {
            value = ((buffer[x * renderArea.height + y] - magicMin) * correction).toInt();
          } else {
            value = 127;
          }
          image.setPixelRgb(x, y, value, value, value);
        }
      }
      sendPort.send(imglib.encodeBmp(image));
      Isolate.exit();
    }
  });
}
