import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fractal_stranger/mandelbrot_drawer.dart';

void main() {
  runApp(const MaterialApp(
    home: App(),
    debugShowCheckedModeBanner: false,
  ));
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      child: const Mandelbrot(),
    );
  }
}

class Mandelbrot extends StatefulWidget {
  const Mandelbrot({super.key});

  @override
  State<Mandelbrot> createState() => _MandelbrotState();
}

class _MandelbrotState extends State<Mandelbrot> {
  Widget image = Container();
  int tapsCount = 0;
  bool showTitle = false;
  bool refreshRequired = true;
  double width = 1000;
  double height = 690;
  double scale = 69;
  double offsetX = 0;
  double offsetY = 0;
  double modScale = 1;
  double modScaleMem = 1;
  double modScalePrev = 1;
  double modOffsetX = 0;
  double modOffsetY = 0;
  double progress = 0;
  int pointersCount = 0;
  Isolate? currentIsolate;
  ReceivePort? currentReceivePort;

  void getImage() async {
    refreshRequired = false;
    currentIsolate?.kill(priority: Isolate.immediate);
    progress = 0;
    final receivePort = ReceivePort();
    currentReceivePort = receivePort;
    currentIsolate = await Isolate.spawn(render, receivePort.sendPort);
    receivePort.listen((message) {
      if (message is SendPort) {
        if (currentReceivePort == receivePort) {
          message.send((
            width: width.toInt(),
            height: height.toInt(),
            scale: scale * modScale,
            offsetX: offsetX + modOffsetX / scale / modScale,
            offsetY: offsetY + modOffsetY / scale / modScale,
          ));
        } else {
          message.send('die');
        }
      } else if (message is Uint8List) {
        if (currentReceivePort == receivePort) {
          currentIsolate?.kill(priority: Isolate.beforeNextEvent);
          currentIsolate = null;
          currentReceivePort = null;
          setState(() {
            image = Image.memory(message);
            progress = 0;
            scale *= modScale;
            modScale = 1;
            offsetX += modOffsetX / scale;
            modOffsetX = 0;
            offsetY += modOffsetY / scale;
            modOffsetY = 0;
          });
        }
      } else if (message is double) {
        setState(() {
          progress = message;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      width = constraints.maxWidth;
      height = constraints.maxHeight;
      if (refreshRequired) {
        getImage();
      } else if (pointersCount > 0) {
        refreshRequired = false;
        currentIsolate?.kill(priority: Isolate.immediate);
        currentIsolate = null;
        currentReceivePort = null;
        progress = 0;
      }
      return Stack(
        children: [
          Listener(
            onPointerDown: (event) {
              pointersCount++;
            },
            onPointerUp: (event) {
              pointersCount--;
              setState(() {
                refreshRequired = pointersCount == 0;
              });
            },
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                const scaleStep = 2;
                final cursorCenterOffsetX = event.position.dx - width / 2;
                final cursorCenterOffsetY = event.position.dy - height / 2;
                setState(() {
                  if (event.scrollDelta.dy < 0) {
                    // zoom in
                    modOffsetX *= scaleStep;
                    modOffsetY *= scaleStep;
                    modOffsetX -= cursorCenterOffsetX;
                    modOffsetY -= cursorCenterOffsetY;
                    modScale *= scaleStep;
                  } else {
                    // zoom out
                    modOffsetX += cursorCenterOffsetX;
                    modOffsetY += cursorCenterOffsetY;
                    modOffsetX /= scaleStep;
                    modOffsetY /= scaleStep;
                    modScale /= scaleStep;
                  }
                  refreshRequired = true;
                });
              }
            },
            child: GestureDetector(
              trackpadScrollCausesScale: true,
              onTap: () {
                tapsCount++;
                if (tapsCount == 8) {
                  setState(() {
                    showTitle = true;
                  });
                  tapsCount = 0;
                }
              },
              onScaleStart: (event) {
                tapsCount = 0;
                setState(() {
                  modScaleMem = modScale;
                  modScalePrev = 1;
                });
              },
              onScaleUpdate: (event) {
                setState(() {
                  if (event.scale > modScalePrev) {
                    modOffsetX *= event.scale / modScalePrev;
                    modOffsetY *= event.scale / modScalePrev;
                  }
                  modOffsetX += event.focalPointDelta.dx;
                  modOffsetY += event.focalPointDelta.dy;
                  if (event.scale < modScalePrev) {
                    modOffsetX *= event.scale / modScalePrev;
                    modOffsetY *= event.scale / modScalePrev;
                  }
                  modScale = modScaleMem * event.scale;
                });
                modScalePrev = event.scale;
              },
              onScaleEnd: (details) {
                setState(() {
                  refreshRequired = true;
                });
              },
              child: Container(
                height: double.infinity,
                width: double.infinity,
                color: Colors.black,
                child: Stack(children: [
                  Positioned(
                    left: modOffsetX,
                    top: modOffsetY,
                    child: Transform.scale(
                      scale: modScale,
                      child: image,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    bottom: 0,
                    child: Container(
                      height: 2,
                      width: progress * width,
                      color: Colors.red,
                    ),
                  )
                ]),
              ),
            ),
          ),
          Visibility(
            visible: showTitle,
            child: TapRegion(
              onTapInside: (event) => setState(() => showTitle = false),
              child: Align(
                child: Card(
                  color: Colors.grey[100],
                  elevation: 10,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(top: 60, bottom: 20),
                        child: Transform.scale(
                          scale: 1.5,
                          child: SvgPicture.asset('assets/sstu_logo.svg'),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(40),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: TextStyle(
                              color: Colors.grey[800],
                              fontFamily: 'Jost',
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                            children: [
                              TextSpan(text: 'Приложение разработано с великой целью\n'),
                              TextSpan(text: 'Чтобы сдать лабу\n', style: TextStyle(fontSize: 15)),
                              TextSpan(text: 'Кирьяковым Фёдором\n', style: TextStyle(fontSize: 25)),
                              TextSpan(text: '2-ИАИТ-114М\n'),
                              TextSpan(text: 'Самара 2024', style: TextStyle(fontSize: 15)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}
