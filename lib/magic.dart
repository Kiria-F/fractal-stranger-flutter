double doMagic(({double x, double y}) p) {
  var result = p;
  int i = 0;
  int iMax = 250;
  for (; i < iMax; i++) {
    var buf = result;
    result =
        (x: buf.x * buf.x - buf.y * buf.y + p.x, y: 2 * buf.x * buf.y + p.y);
    if (result.x == double.infinity ||
        result.x == double.negativeInfinity ||
        result.y == double.infinity ||
        result.y == double.negativeInfinity) {
      break;
    }
    if (result.x == 0 && result.y == 0) {
      i = iMax;
      break;
    }
  }
  return i / iMax;
}
