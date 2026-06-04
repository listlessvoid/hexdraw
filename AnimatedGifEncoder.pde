// palette trained on first frame only; reused for all frames to eliminate inter-frame jitter
class AnimatedGifEncoder {
  java.awt.Color   transparent = null;
  int     transIndex  = 0;
  int     repeat      = -1;
  int     delay       = 0;
  boolean started     = false;
  java.io.OutputStream out;
  java.awt.image.BufferedImage image;
  byte[]  pixels;
  byte[]  indexedPixels;
  int     colorDepth;
  byte[]  colorTab;
  boolean[] usedEntry = new boolean[256];
  int     palSize     = 7;
  int     dispose     = -1;
  boolean closeStream = false;
  boolean firstFrame  = true;
  boolean sizeSet     = false;
  int     sample      = 10;
  int     width, height;

  GifNeuQuant nqLearner = null;

  // Train the palette on a reference image without writing it as a frame.
  // Call before the first addFrame() so the palette represents the full
  // pattern rather than an early (mostly empty) trace frame.
  void preTrain(java.awt.image.BufferedImage im) {
    if (im == null) return;
    if (!sizeSet) setSize(im.getWidth(), im.getHeight());
    image = im;
    getImagePixels();
    analyzePixels(); // sets nqLearner and colorTab; no output written
  }

  void setDelay(int ms)               { delay   = Math.round(ms / 10.0f); }
  void setDispose(int code)           { if (code >= 0) dispose = code; }
  void setRepeat(int iter)            { if (iter >= 0) repeat = iter; }
  void setTransparent(java.awt.Color c) { transparent = c; }
  void setQuality(int q)              { if (q < 1) q = 1; sample = q; }

  void setSize(int w, int h) {
    if (started && !firstFrame) return;
    width = w; height = h;
    if (width  < 1) width  = 320;
    if (height < 1) height = 240;
    sizeSet = true;
  }

  boolean addFrame(java.awt.image.BufferedImage im) {
    if (im == null || !started) return false;
    try {
      if (!sizeSet) setSize(im.getWidth(), im.getHeight());
      image = im;
      getImagePixels();
      analyzePixels();
      if (firstFrame) { writeLSD(); writePalette(); if (repeat >= 0) writeNetscapeExt(); }
      writeGraphicCtrlExt();
      writeImageDesc();
      if (!firstFrame) writePalette();
      writePixels();
      firstFrame = false;
    } catch (java.io.IOException e) { return false; }
    return true;
  }

  boolean finish() {
    if (!started) return false;
    started = false;
    nqLearner = null;
    try {
      out.write(0x3b); out.flush();
      if (closeStream) out.close();
    } catch (java.io.IOException e) { return false; }
    out = null; image = null; pixels = null; indexedPixels = null; colorTab = null;
    closeStream = false; firstFrame = true;
    return true;
  }

  boolean start(java.io.OutputStream os) {
    if (os == null) return false;
    closeStream = false; out = os;
    try { writeString("GIF89a"); } catch (java.io.IOException e) { return false; }
    return (started = true);
  }

  boolean start(String file) {
    try {
      out = new java.io.BufferedOutputStream(new java.io.FileOutputStream(file));
      boolean ok = start(out);
      closeStream = true;
      return ok;
    } catch (java.io.IOException e) { return false; }
  }

  void analyzePixels() {
    int len = pixels.length, nPix = len / 3;
    indexedPixels = new byte[nPix];
    if (nqLearner == null) {
      nqLearner = new GifNeuQuant(pixels, len, sample);
      colorTab  = nqLearner.process();
      for (int i = 0; i < colorTab.length; i += 3) {
        byte t = colorTab[i]; colorTab[i] = colorTab[i+2]; colorTab[i+2] = t;
        usedEntry[i/3] = false;
      }
    } else {
      for (int i = 0; i < 256; i++) usedEntry[i] = false;
    }
    int k = 0;
    for (int i = 0; i < nPix; i++) {
      int idx = nqLearner.map(pixels[k++] & 0xFF, pixels[k++] & 0xFF, pixels[k++] & 0xFF);
      usedEntry[idx] = true;
      indexedPixels[i] = (byte) idx;
    }
    pixels = null; colorDepth = 8; palSize = 7;
    if (transparent != null) transIndex = findClosest(transparent);
  }

  int findClosest(java.awt.Color c) {
    if (colorTab == null) return -1;
    int r = c.getRed(), g = c.getGreen(), b = c.getBlue(), minpos = 0, dmin = Integer.MAX_VALUE;
    for (int i = 0; i < colorTab.length; ) {
      int dr = r-(colorTab[i++]&0xFF), dg = g-(colorTab[i++]&0xFF), db = b-(colorTab[i++]&0xFF);
      int d = dr*dr+dg*dg+db*db, idx = i/3-1;
      if (usedEntry[idx] && d < dmin) { dmin = d; minpos = idx; }
    }
    return minpos;
  }

  void getImagePixels() {
    int w = image.getWidth(), h = image.getHeight();
    if (w != width || h != height || image.getType() != java.awt.image.BufferedImage.TYPE_3BYTE_BGR) {
      java.awt.image.BufferedImage tmp = new java.awt.image.BufferedImage(width, height, java.awt.image.BufferedImage.TYPE_3BYTE_BGR);
      java.awt.Graphics2D g2 = tmp.createGraphics();
      g2.setColor(new java.awt.Color(20, 20, 25));
      g2.fillRect(0, 0, width, height);
      g2.drawImage(image, 0, 0, null);
      g2.dispose();
      image = tmp;
    }
    pixels = ((java.awt.image.DataBufferByte) image.getRaster().getDataBuffer()).getData();
  }

  void writeGraphicCtrlExt() throws java.io.IOException {
    out.write(0x21); out.write(0xF9); out.write(4);
    int transp = (transparent == null) ? 0 : 1;
    int disp   = (dispose >= 0) ? (dispose & 7) : (transparent == null ? 0 : 2);
    out.write(0 | (disp << 2) | 0 | transp);
    writeShort(delay); out.write(transIndex); out.write(0);
  }

  void writeImageDesc() throws java.io.IOException {
    out.write(0x2C); writeShort(0); writeShort(0);
    writeShort(width); writeShort(height);
    out.write(firstFrame ? 0 : (0x80 | palSize));
  }

  void writeLSD() throws java.io.IOException {
    writeShort(width); writeShort(height);
    out.write(0x80 | 0x70 | 0x00 | palSize);
    out.write(0); out.write(0);
  }

  void writeNetscapeExt() throws java.io.IOException {
    out.write(0x21); out.write(0xFF); out.write(11);
    writeString("NETSCAPE2.0");
    out.write(3); out.write(1); writeShort(repeat); out.write(0);
  }

  void writePalette() throws java.io.IOException {
    out.write(colorTab, 0, colorTab.length);
    int n = 3 * 256 - colorTab.length;
    for (int i = 0; i < n; i++) out.write(0);
  }

  void writePixels() throws java.io.IOException {
    new GifLZWEncoder(width, height, indexedPixels, colorDepth).encode(out);
  }

  void writeShort(int v) throws java.io.IOException {
    out.write(v & 0xFF); out.write((v >> 8) & 0xFF);
  }

  void writeString(String s) throws java.io.IOException {
    for (int i = 0; i < s.length(); i++) out.write((byte) s.charAt(i));
  }
}
