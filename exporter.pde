AnimatedGifEncoder gifEncoder      = null;
int                gifExportCount  = 0;
int                gifFrameCount   = 0;

void initExportCounter() {
  java.io.File dir = new java.io.File(exportsDir());
  java.io.File[] files = dir.listFiles();
  if (files == null) return;
  for (java.io.File f : files) {
    String name = f.getName();
    if (!name.startsWith("pattern_")) continue;
    int dot = name.lastIndexOf('.');
    if (dot <= 8) continue;
    try {
      int n = Integer.parseInt(name.substring(8, dot));
      if (n > gifExportCount) gifExportCount = n;
    } catch (Exception ignored) {}
  }
}

PGraphics renderPatternFrame(byte[] dirs, float pulseProgressVal, boolean smooth, float traceProgress) {
  final int   W   = 512;
  final int   H   = 512;
  final float PAD = 36f;

  int N = dirs.length;
  PGraphics pg = createGraphics(W, H, JAVA2D);
  if (!smooth) pg.noSmooth(); // must be before beginDraw()
  pg.beginDraw();
  if (showBackground) {
    pushStyle(); colorMode(HSB, 360, 100, 100);
    int bgC = color(bgColorH, bgColorS, bgColorB);
    popStyle();
    pg.noStroke(); pg.fill(bgC); pg.rect(0, 0, W, H);
  } else {
    pg.clear();
  }

  if (N == 0) { pg.endDraw(); return pg; }

  // ── 1. Build vertices ──────────────────────────────────
  PVector[] v = new PVector[N + 1];
  v[0] = new PVector(0, 0);
  float minX = 0, maxX = 0, minY = 0, maxY = 0;
  for (int i = 0; i < N; i++) {
    int nd = (dirs[i] + currentPatternStartDir) % 6;
    float angle = START_ANGLE + nd * (PI / 3f);
    PVector step = PVector.fromAngle(angle).mult(HEX_LINE_LENGTH);
    v[i+1] = PVector.add(v[i], step);
    minX = min(minX, v[i+1].x); maxX = max(maxX, v[i+1].x);
    minY = min(minY, v[i+1].y); maxY = max(maxY, v[i+1].y);
  }
  float patW = maxX - minX, patH = maxY - minY;
  float avW = W - PAD * 2, avH = H - PAD * 2;
  float tScale = 1f;
  if (patW > 0 || patH > 0) {
    float sX = (patW > 0) ? avW / patW : Float.MAX_VALUE;
    float sY = (patH > 0) ? avH / patH : Float.MAX_VALUE;
    tScale = min(sX, sY, 4f);
  }
  for (PVector vv : v) vv.mult(tScale);
  minX *= tScale; maxX *= tScale; minY *= tScale; maxY *= tScale;
  float dx = W / 2f - (minX + maxX) / 2f;
  float dy = H / 2f - (minY + maxY) / 2f;
  for (PVector vv : v) { vv.x += dx; vv.y += dy; }

  float ms = constrain(tScale, 0.6f, 1.2f);

  // ── 2. Precompute edge colours (must run in HSB mode on main sketch) ──
  pushStyle();
  colorMode(HSB, 360, 100, 100);
  int[] edgeColors = new int[N + 1]; // vertex-based: N+1 colours for N edges
  int[] midColors  = new int[N];
  for (int i = 0; i <= N; i++) edgeColors[i] = pathColor(i, N + 1, currentPalette);
  for (int i = 0; i < N; i++) midColors[i] = lerpColor(edgeColors[i], edgeColors[i+1], 0.5f);
  popStyle();

  // ── 3. Grid dots ───────────────────────────────────────
  if (gridDotsMode) {
    float step = HEX_LINE_LENGTH * tScale;
    if (step >= 8) {
      float baseAngle = START_ANGLE + currentPatternStartDir * (PI / 3f);
      float bqx = cos(baseAngle),         bqy = sin(baseAngle);
      float brx = cos(baseAngle + PI/3f), bry = sin(baseAngle + PI/3f);
      float ox = v[0].x, oy = v[0].y;
      int R = ceil(max(W, (float)H) / step) + 2;
      float dotDiam = constrain(step * 0.10f, 3f, 7f);
      pg.noStroke(); pg.fill(160, 160, 175, 120);
      for (int r = -R; r <= R; r++) {
        for (int q = -R; q <= R; q++) {
          float dotX = ox + (q * bqx + r * brx) * step;
          float dotY = oy + (q * bqy + r * bry) * step;
          if (dotX >= -step && dotX <= W + step && dotY >= -step && dotY <= H + step)
            pg.circle(dotX, dotY, dotDiam);
        }
      }
    }
  }

  // ── 4. Path ────────────────────────────────────────────
  // traceProgress >= 0: draw only that many edges (for trace GIF animation).
  // traceProgress <  0: draw all N edges (static / pulse GIF).
  int   drawN  = (traceProgress >= 0) ? min(N, (int) traceProgress) : N;
  float drawFr = (traceProgress >= 0) ? (traceProgress - drawN) : 0f;

  float sw = constrain(strokeWidthBase * tScale, 1f, strokeWidthBase * 3f);
  pg.strokeWeight(sw); pg.strokeJoin(ROUND); pg.noFill();

  if (arcMode) {
    PVector[] insetStart = new PVector[N];
    PVector[] insetEnd   = new PVector[N];
    for (int i = 0; i < N; i++) {
      insetStart[i] = PVector.lerp(v[i],   v[i+1], arcInset);
      insetEnd[i]   = PVector.lerp(v[i+1], v[i],   arcInset);
    }
    insetStart[0] = v[0].copy();
    insetEnd[N-1] = v[N].copy();

    if (traceProgress < 0) {
      // Static / pulse: draw all segments and arcs.
      for (int i = 0; i < N; i++) { pg.stroke(edgeColors[i]); pg.line(insetStart[i].x, insetStart[i].y, insetEnd[i].x, insetEnd[i].y); }
      for (int i = 1; i < N; i++) { pg.stroke(edgeColors[i]); pg.noFill(); pg.bezier(insetEnd[i-1].x, insetEnd[i-1].y, v[i].x, v[i].y, v[i].x, v[i].y, insetStart[i].x, insetStart[i].y); }
    } else {
      // Trace: use the same 2N-1 element sequence as the live renderer so
      // arcs animate before the next segment starts (not after).
      int   totalEl = max(1, 2 * N - 1);
      float arcStep = traceProgress * (float) totalEl / N;
      int   maxEl   = min((int) arcStep, totalEl);
      float elFrac  = arcStep - (int) arcStep;
      for (int el = 0; el < maxEl; el++) {
        if (el % 2 == 0) {
          int si = el / 2;
          pg.stroke(edgeColors[si]);
          pg.line(insetStart[si].x, insetStart[si].y, insetEnd[si].x, insetEnd[si].y);
        } else {
          int vi = (el + 1) / 2;
          pg.stroke(edgeColors[vi]); pg.noFill();
          pg.bezier(insetEnd[vi-1].x, insetEnd[vi-1].y, v[vi].x, v[vi].y, v[vi].x, v[vi].y, insetStart[vi].x, insetStart[vi].y);
        }
      }
      // Partial current element (arcs not animated - too short, looks choppy).
      if (elFrac > 0 && (int) arcStep < totalEl && (int) arcStep % 2 == 0) {
        int si = (int) arcStep / 2;
        pg.stroke(edgeColors[si]);
        pg.line(insetStart[si].x, insetStart[si].y, lerp(insetStart[si].x, insetEnd[si].x, elFrac), lerp(insetStart[si].y, insetEnd[si].y, elFrac));
      }
    }
  } else {
    for (int i = 0; i < drawN; i++) {
      PVector vA = v[i], vB = v[i+1];
      PVector m1 = new PVector(lerp(vA.x, vB.x, 1f/3f), lerp(vA.y, vB.y, 1f/3f));
      PVector m2 = new PVector(lerp(vA.x, vB.x, 2f/3f), lerp(vA.y, vB.y, 2f/3f));
      pg.stroke(edgeColors[i]);   pg.line(vA.x, vA.y, m1.x, m1.y);
      pg.stroke(midColors[i]);    pg.line(m1.x, m1.y, m2.x, m2.y);
      pg.stroke(edgeColors[i+1]); pg.line(m2.x, m2.y, vB.x, vB.y);
    }
    // partial segment for trace
    if (drawFr > 0 && drawN < N) {
      PVector vA = v[drawN], vB = v[drawN+1];
      PVector m1 = new PVector(lerp(vA.x, vB.x, 1f/3f), lerp(vA.y, vB.y, 1f/3f));
      PVector m2 = new PVector(lerp(vA.x, vB.x, 2f/3f), lerp(vA.y, vB.y, 2f/3f));
      if (drawFr < 1f/3f) {
        pg.stroke(edgeColors[drawN]);
        pg.line(vA.x, vA.y, lerp(vA.x, m1.x, drawFr*3f), lerp(vA.y, m1.y, drawFr*3f));
      } else if (drawFr < 2f/3f) {
        float t = (drawFr-1f/3f)*3f;
        pg.stroke(edgeColors[drawN]);   pg.line(vA.x, vA.y, m1.x, m1.y);
        pg.stroke(midColors[drawN]);    pg.line(m1.x, m1.y, lerp(m1.x,m2.x,t), lerp(m1.y,m2.y,t));
      } else {
        float t = (drawFr-2f/3f)*3f;
        pg.stroke(edgeColors[drawN]);   pg.line(vA.x, vA.y, m1.x, m1.y);
        pg.stroke(midColors[drawN]);    pg.line(m1.x, m1.y, m2.x, m2.y);
        pg.stroke(edgeColors[drawN+1]); pg.line(m2.x, m2.y, lerp(m2.x,vB.x,t), lerp(m2.y,vB.y,t));
      }
    }
  }

  // ── 5. End markers ─────────────────────────────────────
  if (showExportMarkers) {
    pg.stroke(0, 255, 120); pg.strokeWeight(2f); pg.fill(20, 40, 25, 200);
    pg.circle(v[0].x, v[0].y, 16f * ms);
    pg.fill(0, 255, 120); pg.noStroke();
    pg.circle(v[0].x, v[0].y, 6f * ms);

    PVector endV = v[N];
    pg.stroke(255, 50, 80); pg.strokeWeight(2f); pg.noFill();
    pg.circle(endV.x, endV.y, 14f * ms);
    float crossSz = 10f * ms;
    pg.line(endV.x - crossSz, endV.y, endV.x + crossSz, endV.y);
    pg.line(endV.x, endV.y - crossSz, endV.x, endV.y + crossSz);
  }

  // ── 6. Pulse ───────────────────────────────────────────
  if (pulseProgressVal >= 0 && pulseSpeed > 0.0031f) {
    int seg       = floor(pulseProgressVal);
    float segFrac = pulseProgressVal - seg;
    if (seg < N) {
      float px2 = lerp(v[seg].x,   v[seg+1].x, segFrac);
      float py2 = lerp(v[seg].y,   v[seg+1].y, segFrac);
      pg.noStroke();
      pg.fill(255, 255, 255,  60); pg.circle(px2, py2, 16f * ms);
      pg.fill(255, 255, 255, 255); pg.circle(px2, py2,  8f * ms);
    }
  }

  pg.endDraw();
  return pg;
}

PGraphics renderPatternFrame(byte[] dirs, float pulseProgressVal, boolean smooth) {
  return renderPatternFrame(dirs, pulseProgressVal, smooth, -1f);
}
PGraphics renderPatternFrame(byte[] dirs, float pulseProgressVal) {
  return renderPatternFrame(dirs, pulseProgressVal, true, -1f);
}

void exportPatternCanvas(byte[] dirs, float pulseFrame) {
  if (dirs == null || dirs.length == 0) return;
  gifExportCount++;
  PGraphics pg = renderPatternFrame(dirs, pulseFrame, true);
  pg.save(exportsPath("pattern_" + nf(gifExportCount, 3) + ".png"));
  if (pulseFrame < 0) copyToClipboard(pg);
}

// gif recorder
// palette trained on frame 1, reused for all frames - prevents inter-frame palette jitter
// transparent bg uses disposal=2 (restore-to-background) to prevent flicker
void gifRecorderStart() {
  gifExportCount++;
  gifFrameCount = 0;
  String path = exportsPath("pattern_" + nf(gifExportCount, 3) + ".gif");
  gifEncoder = new AnimatedGifEncoder();
  gifEncoder.setRepeat(0);
  gifEncoder.setQuality(1);
  if (!showBackground) {
    gifEncoder.setTransparent(new java.awt.Color(20, 20, 25));
    gifEncoder.setDispose(2);
  } else {
    gifEncoder.setDispose(1); // do-not-dispose; background fills each frame
  }
  if (!gifEncoder.start(path)) {
    notify("GIF start failed", 180, NOTIF_ERROR);
    gifEncoder = null;
  }
}

void gifRecorderPretrain(PGraphics pg) {
  if (gifEncoder == null) return;
  pg.loadPixels();
  java.awt.image.BufferedImage img = new java.awt.image.BufferedImage(pg.pixelWidth, pg.pixelHeight, java.awt.image.BufferedImage.TYPE_INT_ARGB);
  img.setRGB(0, 0, pg.pixelWidth, pg.pixelHeight, pg.pixels, 0, pg.pixelWidth);
  gifEncoder.preTrain(img);
}

void gifRecorderAddFrame(PGraphics pg, int delayMs) {
  if (gifEncoder == null) return;
  pg.loadPixels();
  BufferedImage img = new BufferedImage(pg.pixelWidth, pg.pixelHeight, BufferedImage.TYPE_INT_ARGB);
  img.setRGB(0, 0, pg.pixelWidth, pg.pixelHeight, pg.pixels, 0, pg.pixelWidth);
  gifEncoder.setDelay(delayMs);
  gifEncoder.addFrame(img);
  gifFrameCount++;
}

void gifRecorderFinish() {
  if (gifEncoder == null) return;
  gifEncoder.finish();
  notify("GIF saved: exports/pattern_" + nf(gifExportCount, 3) + ".gif  (" + gifFrameCount + " frames)", 300, NOTIF_SUCCESS);
  gifEncoder = null;
}

void tickGifExport() {
  int N = gifExportDirs.length;

  if (gifExportFrame == -1) {
    // Pretrain step: build palette from the full pattern before trace frames start.
    gifRecorderPretrain(renderPatternFrame(gifExportDirs, -1f, false, N));
    gifExportFrame = 0;
    return;
  }

  if (gifExportFrame < gifExportTotal) {
    PGraphics pg;
    if (gifExportFrame < gifExportFrames) {
      float progress = gifExportIsPulse
        ? ((float) gifExportFrame / gifExportFrames) * N
        : ((float) gifExportFrame / max(1, gifExportFrames - 1)) * N;
      pg = gifExportIsPulse
        ? renderPatternFrame(gifExportDirs, progress, false)
        : renderPatternFrame(gifExportDirs, -1f, false, progress);
    } else {
      pg = renderPatternFrame(gifExportDirs, -1f, false, N); // hold frame
    }
    gifRecorderAddFrame(pg, gifExportDelay);
    gifExportFrame++;
    return;
  }

  // All frames done.
  gifRecorderFinish();
  gifExporting  = false;
  gifExportDirs = null;
}

void drawGifProgressOverlay() {
  if (!gifExporting) return;
  int displayFrame = max(0, gifExportFrame);
  float frac = gifExportTotal > 0 ? (float) displayFrame / gifExportTotal : 0f;

  float bw = 300, bh = 72;
  float bx = width / 2f - bw / 2f, by = height / 2f - bh / 2f;
  noStroke(); fill(13, 13, 18, 230);
  rect(bx, by, bw, bh, 10);

  textAlign(CENTER, CENTER); noStroke();
  textSize(11 * UI_TEXT_SCALE);
  fill(180);
  String label = gifExportFrame < 0 ? "Preparing palette..." :
                 "Exporting GIF  " + displayFrame + " / " + gifExportTotal;
  text(label, width / 2f, by + 22);

  float bx2 = bx + 16, by2 = by + 46, bw2 = bw - 32, bh2 = 10;
  noStroke(); fill(35, 35, 45); rect(bx2, by2, bw2, bh2, 5);
  fill(80, 190, 110);           rect(bx2, by2, bw2 * frac, bh2, 5);
}

void openExportsFolder() {
  String path = exportsDir();
  try {
    String os = System.getProperty("os.name").toLowerCase();
    if (os.contains("win")) {
      // explorer.exe handles UNC and spaces; /select would need a file arg so just open the dir
      new ProcessBuilder("explorer.exe", path).start();
    } else if (os.contains("mac")) {
      new ProcessBuilder("open", path).start();
    } else {
      new ProcessBuilder("xdg-open", path).start();
    }
  } catch (Exception e) {
    notify("Could not open exports folder", 120, NOTIF_ERROR);
  }
}

// clipboard - two flavors: imageFlavor (ARGB, Linux/macOS) + image/bmp (CF_DIB, Windows)
// Windows AWT ignores imageFlavor when DIB is present, so DIB must come first
// setContents dispatched on EDT - calling from the draw thread can silently fail on Windows
void copyToClipboard(PGraphics pg) {
  pg.loadPixels();

  final BufferedImage imgARGB = new BufferedImage(pg.pixelWidth, pg.pixelHeight, BufferedImage.TYPE_INT_ARGB);
  imgARGB.setRGB(0, 0, pg.pixelWidth, pg.pixelHeight, pg.pixels, 0, pg.pixelWidth);

  // Composite onto the app background for the Windows DIB flavor - CF_DIB
  // has no alpha channel so pasting a transparent image produces garbage.
  final BufferedImage imgRGB = new BufferedImage(pg.pixelWidth, pg.pixelHeight, BufferedImage.TYPE_INT_RGB);
  java.awt.Graphics2D g2 = imgRGB.createGraphics();
  g2.setColor(new java.awt.Color(20, 20, 25));
  g2.fillRect(0, 0, pg.pixelWidth, pg.pixelHeight);
  g2.drawImage(imgARGB, 0, 0, null);
  g2.dispose();

  byte[] bmpData = null;
  try {
    java.io.ByteArrayOutputStream bos = new java.io.ByteArrayOutputStream();
    ImageIO.write(imgRGB, "bmp", bos);
    bmpData = bos.toByteArray();
  } catch (Exception ignored) {}
  final byte[] bmpBytes = bmpData;

  DataFlavor bmpFlavor = null;
  try { bmpFlavor = new DataFlavor("image/bmp;class=java.io.InputStream"); }
  catch (Exception ignored) {}
  final DataFlavor bmpFlavorFinal = bmpFlavor;

  final Transferable t = new Transferable() {
    public DataFlavor[] getTransferDataFlavors() {
      if (bmpFlavorFinal != null && bmpBytes != null)
        return new DataFlavor[]{ bmpFlavorFinal, DataFlavor.imageFlavor };
      return new DataFlavor[]{ DataFlavor.imageFlavor };
    }
    public boolean isDataFlavorSupported(DataFlavor f) {
      return DataFlavor.imageFlavor.equals(f) ||
             (bmpFlavorFinal != null && bmpFlavorFinal.equals(f));
    }
    public Object getTransferData(DataFlavor f) throws UnsupportedFlavorException, java.io.IOException {
      if (bmpFlavorFinal != null && bmpFlavorFinal.equals(f) && bmpBytes != null)
        return new java.io.ByteArrayInputStream(bmpBytes);
      if (DataFlavor.imageFlavor.equals(f)) return imgARGB;
      throw new UnsupportedFlavorException(f);
    }
  };

  javax.swing.SwingUtilities.invokeLater(new Runnable() {
    public void run() {
      try { Toolkit.getDefaultToolkit().getSystemClipboard().setContents(t, null); }
      catch (Exception e) { println("Clipboard error: " + e.getMessage()); }
    }
  });
}

