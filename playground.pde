



// button rects
float[]   pgBtnCopySig    = new float[4];
float[]   pgBtnCopyImg    = new float[4];
float[]   pgBtnExportGIF  = new float[4];
float[]   pgBtnSolve      = new float[4];
float[]   pgBtnClear      = new float[4];
float[]   pgBtnOpenFolder = new float[4];
float[][] pgPresetBtns    = new float[64][4];
float[]   pgBtnNewPreset  = new float[4];
float[]   presetListArea  = new float[4];
float     presetScrollY   = 0f;
float[]   btnPresetSave   = new float[4];
float[]   btnPresetCancel = new float[4];




void drawPlayground() {
  boolean solverRunning = solverThread != null && solverThread.isAlive();
  if (solverRunning) {
    int sz; synchronized(totalGallery) { sz = totalGallery.size(); }
    notifyPersistent("solve", "[~]  Decoding...  " + sz + " found", NOTIF_INFO);
  } else {
    dismissPersistent("solve");
  }

  float panelW    = width * panelSlide * PANEL_WIDTH_FRAC;
  float panelX    = width - panelW;
  float drawAreaW = panelX;

  if (panelSlide > 0.01f) {
    noStroke(); fill(13, 13, 18);
    rect(panelX, 0, panelW, height);
    stroke(45, 45, 55); strokeWeight(1);
    line(panelX, 0, panelX, height);
    if (panelW > 80) {
      if      (openPanel == 1) drawPlaygroundPanel1(panelX, panelW);
      else if (openPanel == 2) drawPanel2(panelX, panelW);
      else if (openPanel == 3) drawPanel3(panelX, panelW);
      else if (openPanel == 4) drawPlaygroundPanel4(panelX, panelW);
      else if (openPanel == 5) drawPanel5(panelX, panelW);
    }
  }

  noStroke(); fill(130); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP);
  text("[1] Presets  [2] Color  [3] Render  [4] Export  [5] About", 10, 10);

  // ── Draw canvas (always on, panzoom) ──────────────────────
  updateDrawViewport(drawAreaW);
  if (showBackground) {
    pushStyle(); colorMode(HSB, 360, 100, 100);
    noStroke(); fill(bgColorH, bgColorS, bgColorB);
    rect(0, 0, drawAreaW, height);
    popStyle();
  }
  clip(0, 0, drawAreaW, height);
  drawDrawModeGrid(drawAreaW);
  drawDrawModePath(drawAreaW);
  drawDrawModeHints(drawAreaW);
  noClip();

  // ── Signature field (always visible at bottom) ────────────
  float fieldH  = 48 * UI_TEXT_SCALE;
  float fieldW  = min(500 * UI_TEXT_SCALE, drawAreaW - 60);
  float fieldX  = drawAreaW / 2f - fieldW / 2f;
  float hintH   = 20 * UI_TEXT_SCALE;
  float fieldY  = height - fieldH - hintH - 14 * UI_TEXT_SCALE;

  noStroke(); fill(20, 20, 25, 0);
  rect(0, fieldY - 14, drawAreaW, height - (fieldY - 14));

  int invalidIdx   = firstInvalidIndex(customSignature);
  boolean overLimit = (customSignature.length() > MAX_EDGES);
  drawAqwedField(fieldX, fieldY, fieldW, fieldH, invalidIdx, overLimit);

  float warnY = fieldY + fieldH + 10 * UI_TEXT_SCALE;
  textSize(9 * UI_TEXT_SCALE); textAlign(CENTER, CENTER); noStroke();
  if (invalidIdx >= 0 && customSignature.length() > 0) {
    fill(255, 100, 100);
    text("(!)  edge reused at step " + (invalidIdx + 1), drawAreaW / 2f, warnY);
  } else if (overLimit) {
    fill(255, 140, 40);
    text("(!)  pattern too long to solve (" + customSignature.length() + " edges, solver limit " + MAX_EDGES + ")", drawAreaW / 2f, warnY);
  } else {
    fill(75);
    text("Drag endpoint · type aqwed   CTRL+Z undo   CTRL+BKS clear   S solve   J gif   I image   [Tab] fit", drawAreaW / 2f, warnY);
  }
}

void drawAqwedField(float bx, float by, float bw, float bh, int invalidIdx, boolean atLimit) {
  if (atLimit)                                        stroke(255, 140, 40, 200);
  else if (invalidIdx >= 0 && customSignature.length() > 0) stroke(255, 80, 80, 180);
  else                                                stroke(100, 255, 150, 150);
  strokeWeight(2); fill(13, 13, 18);
  rect(bx, by, bw, bh, 8);

  String counter = String.valueOf(customSignature.length());
  fill(atLimit ? color(255, 140, 40) : 55); textSize(9 * UI_TEXT_SCALE); textAlign(RIGHT, CENTER); noStroke();
  text(counter, bx + bw - 10, by + bh/2);

  float padding       = 12;
  float counterReserve = 58 * UI_TEXT_SCALE;
  float innerW        = bw - padding - counterReserve - padding;
  float startX        = bx + padding;

  pushStyle();
  textFont(monoFont);
  textSize(20 * UI_TEXT_SCALE);
  float charW = textWidth('w');

  float cursorPixel = charW * cursorPos;
  if (cursorPixel - inputScrollX < 0)            inputScrollX = cursorPixel;
  if (cursorPixel - inputScrollX > innerW - 10)  inputScrollX = cursorPixel - innerW + 10;
  if (inputScrollX < 0)                          inputScrollX = 0;

  clip(startX, by + 4, innerW, bh - 8);
  float cx = startX - inputScrollX;

  for (int i = 0; i <= customSignature.length(); i++) {
    if (i == cursorPos && frameCount % 60 < 30) {
      fill(100, 255, 150, 220); noStroke();
      rect(cx - 1, by + 6, 2, bh - 12, 1);
    }
    if (i < customSignature.length()) {
      boolean bad = (invalidIdx >= 0 && i >= invalidIdx);
      fill(bad ? color(255, 80, 80) : color(100, 255, 150)); noStroke();
      textAlign(LEFT, CENTER);
      text(customSignature.charAt(i), cx, by + bh/2);
      cx += charW;
    }
  }
  noClip();
  popStyle();
}




byte[] sigToBytes(String sig) {
  if (sig == null || sig.length() == 0) return new byte[0];
  int invalidAt = firstInvalidIndex(sig);
  int len = (invalidAt < 0) ? sig.length() : invalidAt;
  if (len <= 0) return new byte[0];
  byte[] result = new byte[len + 1];
  result[0] = 0; // initial direction - matches buildGraph's currentAbsDir = 0
  int absDir = 0;
  for (int i = 0; i < len; i++) {
    char c = sig.charAt(i);
    int turn = Math.max(0, sigCharToTurn(c));
    absDir = (absDir + turn) % 6;
    result[i + 1] = (byte) absDir;
  }
  return result;
}

// draw mode

void drawDrawMode(float drawAreaW) {
  updateDrawViewport(drawAreaW);

  // Clip everything to the draw area so it never bleeds into panels
  clip(0, 0, drawAreaW, height);

  drawDrawModeGrid(drawAreaW);
  drawDrawModePath(drawAreaW);
  drawDrawModeHints(drawAreaW);

  noClip();

  // Bottom hint bar
  float hintH = 20 * UI_TEXT_SCALE;
  float hintY = height - hintH - 6 * UI_TEXT_SCALE;
  noStroke(); fill(20, 20, 25, 215);
  rect(0, hintY - 6, drawAreaW, height - (hintY - 6));
  textAlign(CENTER, CENTER); fill(75); textSize(9 * UI_TEXT_SCALE); noStroke();
  text("Drag from endpoint to draw   CTRL+Z undo   CTRL+BKS clear   H arc   G dots   S solve   [Tab] type",
       drawAreaW / 2f, hintY + hintH / 2f);
}

void drawDrawModeGrid(float drawAreaW) {
  // Dots visible when gridDotsMode is on, OR while actively drawing.
  if (!gridDotsMode && !drawDragging) return;
  float step = drawStepSize();
  if (step < 6) return;

  // Use draw viewport origin (axial 0,0 on screen) as anchor for the grid.
  // axialToScreen(0,0) = (drawViewX, drawViewY) so we just use those directly.
  float ox = drawViewX;
  float oy = drawViewY;

  // Hex grid basis vectors (no pattern rotation in draw mode - always canonical).
  // dir 0 = (1,0) axial → screen: step along x-axis angle (START_ANGLE=0 → east).
  float bqx = cos(START_ANGLE),          bqy = sin(START_ANGLE);
  float brx = cos(START_ANGLE + PI/3f),  bry = sin(START_ANGLE + PI/3f);

  int R = ceil(max(drawAreaW, (float)height) / step) + 2;
  float dotDiam = constrain(step * 0.10f, 3f, 8f);

  pushStyle();
  noStroke();
  fill(160, 160, 175, 100);

  for (int r = -R; r <= R; r++) {
    for (int q = -R; q <= R; q++) {
      float dotX = ox + (q * bqx + r * brx) * step;
      float dotY = oy + (q * bqy + r * bry) * step;
      if (dotX >= -step && dotX <= drawAreaW + step &&
          dotY >= -step && dotY <= (float)height + step) {
        circle(dotX, dotY, dotDiam);
      }
    }
  }
  popStyle();
}

void drawDrawModePath(float drawAreaW) {
  if (drawPath.size() == 0) {
    // Empty path - pulsing dot at the start position.
    float[] os = axialToScreen(drawStartAxial[0], drawStartAxial[1]);
    float step = drawStepSize();
    float pulse = 0.5f + 0.5f * sin(frameCount * 0.08f);
    float r = constrain(step * 0.18f, 5f, 14f) * (0.85f + 0.15f * pulse);
    pushStyle();
    noStroke(); fill(100, 255, 150, 180);
    circle(os[0], os[1], r * 2);
    popStyle();
    return;
  }

  // Every entry in drawPath is a real edge direction (index 0 = first/initial edge).
  int numEdges = drawPath.size();

  float step = drawStepSize();
  float[] startScr = axialToScreen(drawStartAxial[0], drawStartAxial[1]);
  PVector[] verts = new PVector[numEdges + 1];
  verts[0] = new PVector(startScr[0], startScr[1]);
  int q = drawStartAxial[0], r = drawStartAxial[1];
  for (int i = 0; i < numEdges; i++) {
    int d = ((drawPath.get(i) % 6) + 6) % 6;
    q += DIR_OFFSETS[d][0];
    r += DIR_OFFSETS[d][1];
    float[] s = axialToScreen(q, r);
    verts[i + 1] = new PVector(s[0], s[1]);
  }

  int N = numEdges;
  float sw = constrain(strokeWidthBase * 0.7f * drawViewScale, 1f, strokeWidthBase * 3f);

  pushStyle();
  colorMode(HSB, 360, 100, 100);
  strokeWeight(sw); strokeJoin(ROUND); noFill();

  if (arcMode && N >= 2) {
    // Arc mode: inset segments + bezier corners
    PVector[] insetS = new PVector[N];
    PVector[] insetE = new PVector[N];
    for (int i = 0; i < N; i++) {
      insetS[i] = PVector.lerp(verts[i],   verts[i+1], arcInset);
      insetE[i] = PVector.lerp(verts[i+1], verts[i],   arcInset);
    }
    insetS[0]     = verts[0].copy();
    insetE[N - 1] = verts[N].copy();
    for (int i = 0; i < N; i++) {
      stroke(pathColor(i, N + 1, currentPalette));
      line(insetS[i].x, insetS[i].y, insetE[i].x, insetE[i].y);
      if (i < N - 1) {
        bezier(insetE[i].x,     insetE[i].y,
               verts[i+1].x,   verts[i+1].y,
               verts[i+1].x,   verts[i+1].y,
               insetS[i+1].x,  insetS[i+1].y);
      }
    }
  } else {
    // Straight mode: per-edge gradient sub-segments
    for (int i = 0; i < N; i++) {
      color cA = pathColor(i,     N + 1, currentPalette);
      color cB = pathColor(i + 1, N + 1, currentPalette);
      color cMid = lerpColor(cA, cB, 0.5f);
      PVector vA = verts[i], vB = verts[i + 1];
      PVector m1 = new PVector(lerp(vA.x, vB.x, 1f/3f), lerp(vA.y, vB.y, 1f/3f));
      PVector m2 = new PVector(lerp(vA.x, vB.x, 2f/3f), lerp(vA.y, vB.y, 2f/3f));
      stroke(cA);   line(vA.x, vA.y, m1.x, m1.y);
      stroke(cMid); line(m1.x, m1.y, m2.x, m2.y);
      stroke(cB);   line(m2.x, m2.y, vB.x, vB.y);
    }
  }

  colorMode(RGB, 255, 255, 255);
  popStyle();

  // Pulsing dot at the pending-restart origin (shown while old path is still visible)
  if (pendingRestart) {
    float[] ps    = axialToScreen(pendingRestartAxial[0], pendingRestartAxial[1]);
    float   pulse = 0.5f + 0.5f * sin(frameCount * 0.08f);
    float   pr    = constrain(drawStepSize() * 0.18f, 5f, 14f) * (0.85f + 0.15f * pulse);
    pushStyle(); noStroke(); fill(255, 200, 80, 180); circle(ps[0], ps[1], pr * 2); popStyle();
  }

  // Pulse (uses lastTargetScale - override to draw viewport scale)
  lastTargetScale = drawViewScale;
  drawPulse(verts, N);

  // End markers
  float ms = constrain(drawViewScale, 0.6f, 1.4f);
  PVector sv = verts[0];
  PVector ev = verts[N];

  stroke(0, 255, 120); strokeWeight(2); fill(20, 40, 25, 200);
  circle(sv.x, sv.y, 16 * ms);
  fill(0, 255, 120); noStroke();
  circle(sv.x, sv.y, 6 * ms);

  stroke(255, 50, 80); strokeWeight(2); noFill();
  circle(ev.x, ev.y, 14 * ms);
  float cs = 10 * ms;
  line(ev.x - cs, ev.y, ev.x + cs, ev.y);
  line(ev.x, ev.y - cs, ev.x, ev.y + cs);
}

void drawDrawModeHints(float drawAreaW) {
  // While dragging: show hints for the active endpoint.
  // While idle: show hints for whichever endpoint the mouse is closer to.
  int[] activeAxial;
  if (drawExtendSide != 0) {
    activeAxial = pendingRestart ? pendingRestartAxial
                                 : (drawExtendSide == 1) ? drawEndAxial : drawStartAxial;
  } else if (drawPath.size() == 0) {
    return; // nothing to show on empty path
  } else {
    float[] es = axialToScreen(drawEndAxial[0], drawEndAxial[1]);
    float[] ss = axialToScreen(drawStartAxial[0], drawStartAxial[1]);
    boolean nearEnd = dist(mouseX, mouseY, es[0], es[1]) <=
                      dist(mouseX, mouseY, ss[0], ss[1]);
    activeAxial = nearEnd ? drawEndAxial : drawStartAxial;
    // For from-start hints, temporarily set side so isDrawDirAllowed works correctly.
    drawExtendSide = nearEnd ? 1 : -1;
  }
  float step = drawStepSize();
  float snapR = step * 0.5f;

  pushStyle();
  for (int d = 0; d < 6; d++) {
    // During a pending restart the new start has no history - all 6 dirs are valid.
    if (!pendingRestart && !isDrawDirAllowed(d)) continue;
    int nq = activeAxial[0] + DIR_OFFSETS[d][0];
    int nr = activeAxial[1] + DIR_OFFSETS[d][1];
    if (!pendingRestart) {
      String ek = edgeKeyFor(packQR(activeAxial[0], activeAxial[1]), packQR(nq, nr));
      if (drawUsedEdges.contains(ek)) continue; // edge already used in old path
    }

    float[] s = axialToScreen(nq, nr);
    float dist = dist(mouseX, mouseY, s[0], s[1]);
    boolean near = dist < snapR;

    noStroke();
    fill(near ? color(100, 255, 150, 200) : color(100, 255, 150, 55));
    float dotR = constrain(step * 0.14f, 4f, 12f);
    if (near) dotR *= 1.3f;
    circle(s[0], s[1], dotR * 2);
  }
  popStyle();
  if (!drawDragging) drawExtendSide = 0; // restore if we set it temporarily
}

// viewport

float drawStepSize() { return HEX_LINE_LENGTH * drawViewScale; }

float[] axialToScreen(int q, int r) {
  float step = drawStepSize();
  float bqx = cos(START_ANGLE),         bqy = sin(START_ANGLE);
  float brx = cos(START_ANGLE + PI/3f), bry = sin(START_ANGLE + PI/3f);
  float sx = drawViewX + (q * bqx + r * brx) * step;
  float sy = drawViewY + (q * bqy + r * bry) * step;
  return new float[]{sx, sy};
}


int[] screenToNearestAxial(float sx, float sy) {
  float step = drawStepSize();
  float bqx = cos(START_ANGLE),         bqy = sin(START_ANGLE);
  float brx = cos(START_ANGLE + PI/3f), bry = sin(START_ANGLE + PI/3f);

  float det = bqx * bry - bqy * brx;
  if (abs(det) < 1e-9f) return new int[]{0, 0};
  float dx = sx - drawViewX, dy = sy - drawViewY;
  float fq = (bry * dx - brx * dy) / (det * step);
  float fr = (bqx * dy - bqy * dx) / (det * step);

  // Cube coords: s = -q-r
  float fs = -fq - fr;
  int rq = round(fq), rr = round(fr), rs = round(fs);
  float dq = abs(rq - fq), dr = abs(rr - fr), ds = abs(rs - fs);
  if (dq > dr && dq > ds) rq = -rr - rs;
  else if (dr > ds)        rr = -rq - rs;
  return new int[]{rq, rr};
}

int directionBetween(int[] from, int[] dest) {
  int dq = dest[0] - from[0], dr = dest[1] - from[1];
  for (int d = 0; d < 6; d++) {
    if (DIR_OFFSETS[d][0] == dq && DIR_OFFSETS[d][1] == dr) return d;
  }
  return -1;
}

void updateDrawViewport(float drawAreaW) {
  drawViewX     = lerp(drawViewX,     drawTargetX,     DRAW_LERP_SPEED);
  drawViewY     = lerp(drawViewY,     drawTargetY,     DRAW_LERP_SPEED);
  drawViewScale = lerp(drawViewScale, drawTargetScale, DRAW_LERP_SPEED);

  if (drawExtendSide == 0) return;

  // Auto-nudge when dragging so the active endpoint stays visible.
  // During a pending restart, track the new origin, not the old path endpoint.
  int[] ep = pendingRestart ? pendingRestartAxial
                            : (drawExtendSide == 1) ? drawEndAxial : drawStartAxial;
  float[] s = axialToScreen(ep[0], ep[1]);
  float margin = 120f, nudge = 55f;
  if (s[0] < margin)             drawTargetX += nudge;
  if (s[0] > drawAreaW - margin) drawTargetX -= nudge;
  if (s[1] < margin)             drawTargetY += nudge;
  if (s[1] > (float)height - margin) drawTargetY -= nudge;
}

void centerDrawViewOnPath(boolean instant) {
  float step = HEX_LINE_LENGTH; // use scale=1 to compute bounds, then fit

  if (drawPath.size() == 0) {
    drawTargetX     = width / 2f;
    drawTargetY     = height / 2f - 40;
    drawTargetScale = 2.0f;
    if (instant) {
      drawViewX = drawTargetX; drawViewY = drawTargetY; drawViewScale = drawTargetScale;
    }
    return;
  }

  // Walk all edges to collect visited axial coords.
  float minQ = drawStartAxial[0], maxQ = drawStartAxial[0];
  float minR = drawStartAxial[1], maxR = drawStartAxial[1];
  int q = drawStartAxial[0], r = drawStartAxial[1];
  for (int i = 0; i < drawPath.size(); i++) {
    int d = ((drawPath.get(i) % 6) + 6) % 6;
    q += DIR_OFFSETS[d][0];
    r += DIR_OFFSETS[d][1];
    if (q < minQ) minQ = q; if (q > maxQ) maxQ = q;
    if (r < minR) minR = r; if (r > maxR) maxR = r;
  }

  // Convert axial extent to screen extent at scale=1.
  float bqx = cos(START_ANGLE),         bqy = sin(START_ANGLE);
  float brx = cos(START_ANGLE + PI/3f), bry = sin(START_ANGLE + PI/3f);
  // Four corners of the (minQ,minR)→(maxQ,maxR) bounding box in screen space.
  float[] cornersX = {
    (minQ * bqx + minR * brx) * step, (maxQ * bqx + minR * brx) * step,
    (maxQ * bqx + maxR * brx) * step, (minQ * bqx + maxR * brx) * step
  };
  float[] cornersY = {
    (minQ * bqy + minR * bry) * step, (maxQ * bqy + minR * bry) * step,
    (maxQ * bqy + maxR * bry) * step, (minQ * bqy + maxR * bry) * step
  };
  float bminX = cornersX[0], bmaxX = cornersX[0], bminY = cornersY[0], bmaxY = cornersY[0];
  for (int i = 1; i < 4; i++) {
    bminX = min(bminX, cornersX[i]); bmaxX = max(bmaxX, cornersX[i]);
    bminY = min(bminY, cornersY[i]); bmaxY = max(bmaxY, cornersY[i]);
  }

  float patW = bmaxX - bminX, patH = bmaxY - bminY;
  float availW = width * (1f - PANEL_WIDTH_FRAC) - 80;
  float availH = (float)height - 100;
  float newScale = 1.0f;
  if (patW > 0 || patH > 0) {
    float sX = (patW > 0) ? availW / patW : Float.MAX_VALUE;
    float sY = (patH > 0) ? availH / patH : Float.MAX_VALUE;
    newScale = constrain(min(sX, sY), 0.3f, 4.0f);
  }

  float patCX = (bminX + bmaxX) / 2f * newScale;
  float patCY = (bminY + bmaxY) / 2f * newScale;

  // Centre the pattern: drawViewX = areaCentre - (patCentre_in_screen_space).
  // patCentre_in_screen_space = startSX + patCX (offset of start + offset of pattern centre from start).
  float startSX = (drawStartAxial[0] * bqx + drawStartAxial[1] * brx) * newScale * step;
  float startSY = (drawStartAxial[0] * bqy + drawStartAxial[1] * bry) * newScale * step;
  float areaCX = width * (1f - PANEL_WIDTH_FRAC * panelSlide) / 2f;
  float areaCY = (float)height / 2f - 30;

  drawTargetX     = areaCX - startSX - patCX;
  drawTargetY     = areaCY - startSY - patCY;
  drawTargetScale = newScale;
  if (instant) {
    drawViewX = drawTargetX; drawViewY = drawTargetY; drawViewScale = drawTargetScale;
  }
}

void centerDrawViewOnPath() { centerDrawViewOnPath(true); }

void zoomDrawView(float delta, float anchorX, float anchorY) {
  float factor = (delta < 0) ? 1.12f : (1f / 1.12f);
  float newScale = constrain(drawTargetScale * factor, 0.25f, 5.0f);
  float ratio = newScale / drawTargetScale;
  drawTargetX = anchorX + (drawTargetX - anchorX) * ratio;
  drawTargetY = anchorY + (drawTargetY - anchorY) * ratio;
  drawTargetScale = newScale;
}



boolean isDrawDirAllowed(int d) {
  if (drawExtendSide == 1) {
    // First edge: no direction restriction - any of the 6 directions is valid.
    if (drawPath.isEmpty()) return true;
    // Subsequent edges: block the 180° reversal of the last edge.
    int lastDir = drawPath.get(drawPath.size() - 1);
    return (lastDir + 3) % 6 != d;
  } else {
    // From START: all restrictions are handled by drawUsedEdges + backtrack logic.
    return true;
  }
}

// panel 1 - presets

void drawPlaygroundPanel1(float px, float pw) {
  float pad  = 14;
  float y    = 18 * UI_TEXT_SCALE;
  float cxP  = px + pw / 2f;
  float btnH = 26 * UI_TEXT_SCALE;
  float gap  = 4;

  textAlign(CENTER, TOP); fill(160); textSize(10 * UI_TEXT_SCALE); noStroke();
  text("PRESETS", cxP, y); y += 18 * UI_TEXT_SCALE;
  stroke(40, 40, 50); strokeWeight(1);
  line(px + pad, y, px + pw - pad, y); y += 10 * UI_TEXT_SCALE;

  // "+ New Preset" always at top
  pgBtnNewPreset[0] = px + pad; pgBtnNewPreset[1] = y;
  pgBtnNewPreset[2] = pw - pad * 2; pgBtnNewPreset[3] = 24 * UI_TEXT_SCALE;
  boolean npHov = mouseInRect(pgBtnNewPreset);
  noStroke(); fill(npHov ? color(25, 40, 55) : color(18, 25, 38));
  rect(pgBtnNewPreset[0], y, pgBtnNewPreset[2], pgBtnNewPreset[3], 4);
  stroke(npHov ? color(80, 180, 120) : color(38, 75, 55)); strokeWeight(1.5f); noFill();
  rect(pgBtnNewPreset[0], y, pgBtnNewPreset[2], pgBtnNewPreset[3], 4);
  textAlign(CENTER, CENTER); fill(npHov ? 210 : 120); textSize(9 * UI_TEXT_SCALE); noStroke();
  text("+ New Preset", cxP, y + pgBtnNewPreset[3] / 2);
  if (npHov) wantedCursor = HAND;
  y += pgBtnNewPreset[3] + 6 * UI_TEXT_SCALE;

  // Scrollable list
  float rowH     = btnH + gap;
  float listH    = height - y - 4;
  float contentH = presets.size() * rowH;
  presetScrollY  = constrain(presetScrollY, 0, max(0, contentH - listH));
  presetListArea[0] = px; presetListArea[1] = y; presetListArea[2] = pw; presetListArea[3] = listH;

  float delW = 22 * UI_TEXT_SCALE;
  clip(px, y, pw, listH);
  for (int i = 0; i < presets.size(); i++) {
    float rowY = y + i * rowH - presetScrollY;
    if (rowY + rowH < y || rowY > y + listH) continue;
    pgPresetBtns[i][0] = px + pad; pgPresetBtns[i][1] = rowY;
    pgPresetBtns[i][2] = pw - pad * 2 - delW - gap; pgPresetBtns[i][3] = btnH;
    boolean hov = mouseInRect(pgPresetBtns[i]);
    noStroke(); fill(hov ? color(30, 48, 38) : color(22, 26, 30));
    rect(pgPresetBtns[i][0], rowY, pgPresetBtns[i][2], btnH, 4);
    stroke(hov ? color(100, 255, 150) : color(48, 53, 60)); strokeWeight(1); noFill();
    rect(pgPresetBtns[i][0], rowY, pgPresetBtns[i][2], btnH, 4);
    textAlign(LEFT, CENTER); fill(hov ? 255 : 155); textSize(9 * UI_TEXT_SCALE); noStroke();
    text(presets.get(i).name, pgPresetBtns[i][0] + 8, rowY + btnH/2);
    textAlign(RIGHT, CENTER); fill(hov ? 130 : 55); textSize(8 * UI_TEXT_SCALE);
    String ts = presets.get(i).signature; if (ts.length() > 12) ts = ts.substring(0, 10) + "..";
    text(ts, pgPresetBtns[i][0] + pgPresetBtns[i][2] - 6, rowY + btnH/2);
    if (hov) wantedCursor = HAND;
    // Delete button
    float delX = px + pw - pad - delW;
    boolean delHov = mouseInRect(delX+1, rowY+1, delW-2, btnH-2);
    noStroke(); fill(delHov ? color(65,22,25) : color(28,18,20));
    rect(delX+1, rowY+1, delW-2, btnH-2, 3);
    stroke(delHov ? color(255,80,80) : color(85,38,42)); strokeWeight(1); noFill();
    rect(delX+1, rowY+1, delW-2, btnH-2, 3);
    textAlign(CENTER, CENTER); fill(delHov ? color(255,100,100) : color(120,55,60));
    textSize(9 * UI_TEXT_SCALE); noStroke(); text("x", delX + delW/2, rowY + btnH/2);
    if (delHov) wantedCursor = HAND;
  }
  noClip();

  // Scrollbar
  if (contentH > listH && listH > 0) {
    float sbW = 3, sbX = px + pw - 3;
    float sbH = listH * listH / contentH;
    float sbY = y + (presetScrollY / max(1, contentH - listH)) * (listH - sbH);
    noStroke(); fill(38, 42, 50); rect(sbX, y, sbW, listH, 1);
    fill(90, 100, 115); rect(sbX, sbY, sbW, max(sbH, 12), 1);
  }
}

// panel 4 - export

void drawPlaygroundPanel4(float px, float pw) {
  float pad  = 14;
  float y    = 18 * UI_TEXT_SCALE;
  float cxP  = px + pw / 2f;

  textAlign(CENTER, TOP); fill(160); textSize(10 * UI_TEXT_SCALE); noStroke();
  text("EXPORT", cxP, y); y += 18 * UI_TEXT_SCALE;
  stroke(40, 40, 50); strokeWeight(1);
  line(px + pad, y, px + pw - pad, y); y += 12 * UI_TEXT_SCALE;

  // Signature box
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("SIGNATURE", px + pad, y); y += 12 * UI_TEXT_SCALE;
  String sig = customSignature;
  float sigBoxW = pw - pad * 2;
  float sigBoxH = 52 * UI_TEXT_SCALE;
  noStroke(); fill(18, 18, 25); rect(px + pad, y, sigBoxW, sigBoxH, 4);
  stroke(45, 45, 55); strokeWeight(1); noFill();
  rect(px + pad, y, sigBoxW, sigBoxH, 4);
  pushStyle();
  clip(px + pad + 4, y + 3, sigBoxW - 8, sigBoxH - 6);
  textAlign(LEFT, TOP); fill(sig.length() == 0 ? 45 : 145); textSize(10 * UI_TEXT_SCALE); noStroke();
  text(sig.length() == 0 ? "(empty)" : sig, px + pad + 6, y + 6, sigBoxW - 12, sigBoxH - 12);
  noClip(); popStyle();
  y += sigBoxH + 8 * UI_TEXT_SCALE;

  // Copy signature
  pgBtnCopySig[0] = px+pad; pgBtnCopySig[1] = y; pgBtnCopySig[2] = pw-pad*2; pgBtnCopySig[3] = 28*UI_TEXT_SCALE;
  boolean csHov = mouseInRect(pgBtnCopySig);
  noStroke(); fill(csHov ? color(35,65,45) : color(25,50,35));
  rect(pgBtnCopySig[0], y, pgBtnCopySig[2], pgBtnCopySig[3], 4);
  stroke(100,255,150); strokeWeight(1.5f); noFill();
  rect(pgBtnCopySig[0], y, pgBtnCopySig[2], pgBtnCopySig[3], 4);
  textAlign(CENTER, CENTER); fill(csHov ? 255 : 190); textSize(10*UI_TEXT_SCALE); noStroke();
  text("[ Copy Signature ]  [C]", cxP, y + pgBtnCopySig[3]/2);
  if (csHov) wantedCursor = HAND;
  y += 28*UI_TEXT_SCALE + 6*UI_TEXT_SCALE;

  // Copy image
  pgBtnCopyImg[0] = px+pad; pgBtnCopyImg[1] = y; pgBtnCopyImg[2] = pw-pad*2; pgBtnCopyImg[3] = 28*UI_TEXT_SCALE;
  boolean ciHov = mouseInRect(pgBtnCopyImg);
  noStroke(); fill(ciHov ? color(35,50,75) : color(22,30,48));
  rect(pgBtnCopyImg[0], y, pgBtnCopyImg[2], pgBtnCopyImg[3], 4);
  stroke(80,140,255); strokeWeight(1.5f); noFill();
  rect(pgBtnCopyImg[0], y, pgBtnCopyImg[2], pgBtnCopyImg[3], 4);
  textAlign(CENTER, CENTER); fill(ciHov ? 255 : 190); textSize(10*UI_TEXT_SCALE); noStroke();
  text("[ Copy Image ]  [I]", cxP, y + pgBtnCopyImg[3]/2);
  if (ciHov) wantedCursor = HAND;
  y += 28*UI_TEXT_SCALE + 6*UI_TEXT_SCALE;

  // Export GIF
  pgBtnExportGIF[0] = px+pad; pgBtnExportGIF[1] = y; pgBtnExportGIF[2] = pw-pad*2; pgBtnExportGIF[3] = 28*UI_TEXT_SCALE;
  boolean gifHov = sig.length() > 0 && mouseInRect(pgBtnExportGIF);
  noStroke(); fill(sig.length() == 0 ? color(18,15,28) : (gifHov ? color(35,28,50) : color(22,18,35)));
  rect(pgBtnExportGIF[0], y, pgBtnExportGIF[2], pgBtnExportGIF[3], 4);
  stroke(sig.length() == 0 ? color(40,32,55) : (gifHov ? color(180,120,255) : color(80,55,120)));
  strokeWeight(1.5f); noFill();
  rect(pgBtnExportGIF[0], y, pgBtnExportGIF[2], pgBtnExportGIF[3], 4);
  textAlign(CENTER, CENTER); fill(sig.length() == 0 ? 38 : (gifHov ? color(210,170,255) : color(130,90,180)));
  textSize(10*UI_TEXT_SCALE); noStroke();
  text("[ Export GIF ]  [J]", cxP, y + pgBtnExportGIF[3]/2);
  if (gifHov) wantedCursor = HAND;
  y += 28*UI_TEXT_SCALE + 12*UI_TEXT_SCALE;

  // Divider + Solve section
  stroke(40, 40, 50); strokeWeight(1);
  line(px + pad, y, px + pw - pad, y); y += 12 * UI_TEXT_SCALE;
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("FIND PERMUTATIONS", px + pad, y); y += 13 * UI_TEXT_SCALE;

  boolean canSolve = sig.length() > 0 && firstInvalidIndex(sig) < 0;
  pgBtnSolve[0] = px+pad; pgBtnSolve[1] = y; pgBtnSolve[2] = pw-pad*2; pgBtnSolve[3] = 34*UI_TEXT_SCALE;
  boolean sHov = canSolve && mouseInRect(pgBtnSolve);
  noStroke(); fill(!canSolve ? color(18,22,18) : (sHov ? color(28,62,33) : color(20,50,28)));
  rect(pgBtnSolve[0], y, pgBtnSolve[2], pgBtnSolve[3], 4);
  stroke(!canSolve ? color(35,40,35) : (sHov ? color(100,255,150) : color(65,165,85)));
  strokeWeight(1.5f); noFill();
  rect(pgBtnSolve[0], y, pgBtnSolve[2], pgBtnSolve[3], 4);
  textAlign(CENTER, CENTER);
  fill(!canSolve ? 42 : (sHov ? color(150,255,170) : color(90,210,110)));
  textSize(10*UI_TEXT_SCALE); noStroke();
  text(!canSolve ? "[ Find Permutations ]" : "[ Find Permutations ]  [S]", cxP, y + pgBtnSolve[3]/2);
  if (sHov) wantedCursor = HAND;
  y += 34*UI_TEXT_SCALE + 6*UI_TEXT_SCALE;

  // Clear
  pgBtnClear[0] = px+pad; pgBtnClear[1] = y; pgBtnClear[2] = pw-pad*2; pgBtnClear[3] = 24*UI_TEXT_SCALE;
  boolean clHov = mouseInRect(pgBtnClear);
  noStroke(); fill(clHov ? color(50,20,22) : color(28,18,20));
  rect(pgBtnClear[0], y, pgBtnClear[2], pgBtnClear[3], 4);
  stroke(clHov ? color(255,80,80) : color(90,38,45)); strokeWeight(1); noFill();
  rect(pgBtnClear[0], y, pgBtnClear[2], pgBtnClear[3], 4);
  textAlign(CENTER, CENTER); fill(clHov ? color(255,100,100) : color(130,55,65));
  textSize(9*UI_TEXT_SCALE); noStroke();
  text("[ Clear Pattern ]", cxP, y + pgBtnClear[3]/2);
  if (clHov) wantedCursor = HAND;
  y += 24*UI_TEXT_SCALE + 6*UI_TEXT_SCALE;

  // GIF uncap toggle
  drawGifUncapToggle(px, pw, y); y += gifUncapped ? 52 * UI_TEXT_SCALE : 34 * UI_TEXT_SCALE;

  // Open exports folder
  pgBtnOpenFolder[0]=px+pad; pgBtnOpenFolder[1]=y; pgBtnOpenFolder[2]=pw-pad*2; pgBtnOpenFolder[3]=24*UI_TEXT_SCALE;
  boolean ofHov = mouseInRect(pgBtnOpenFolder);
  noStroke(); fill(ofHov ? color(28,28,40) : color(20,20,30));
  rect(pgBtnOpenFolder[0], y, pgBtnOpenFolder[2], pgBtnOpenFolder[3], 4);
  stroke(ofHov ? color(140,140,200) : color(55,55,80)); strokeWeight(1); noFill();
  rect(pgBtnOpenFolder[0], y, pgBtnOpenFolder[2], pgBtnOpenFolder[3], 4);
  textAlign(CENTER, CENTER); fill(ofHov ? 200 : 100); textSize(9*UI_TEXT_SCALE); noStroke();
  text("[ Open Exports Folder ]", cxP, y + pgBtnOpenFolder[3]/2);
  if (ofHov) wantedCursor = HAND;
  y += 24*UI_TEXT_SCALE + 10*UI_TEXT_SCALE;

  // Stats
  stroke(40, 40, 50); strokeWeight(1);
  line(px + pad, y, px + pw - pad, y); y += 10 * UI_TEXT_SCALE;
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("STATS", px + pad, y); y += 13 * UI_TEXT_SCALE;
  fill(120); textSize(8 * UI_TEXT_SCALE);
  text("Length: " + sig.length() + (sig.length() > MAX_EDGES ? " (over solver limit)" : ""), px + pad, y); y += 11 * UI_TEXT_SCALE;
  text("Permutations found: " + String.format("%,d", totalPathsFound.get()), px + pad, y); y += 11 * UI_TEXT_SCALE;
  text("Rotation: " + currentPatternStartDir + " / 6", px + pad, y);

  // Key hints
  float hintY = height - 30 * UI_TEXT_SCALE;
  stroke(35, 40, 48); strokeWeight(1);
  line(px + pad, hintY - 8*UI_TEXT_SCALE, px + pw - pad, hintY - 8*UI_TEXT_SCALE);
  textAlign(LEFT, TOP); fill(110); textSize(8 * UI_TEXT_SCALE); noStroke();
  text("S : solve   C : copy sig   I : copy image", px + pad, hintY);
}

// solve

void triggerSolve() {
  String sig = customSignature;
  if (sig.length() == 0) {
    notify("Enter a pattern first", 120, NOTIF_WARN); return;
  }
  if (sig.length() > MAX_EDGES) {
    notify("Pattern too long to solve (" + sig.length() + " edges, max " + MAX_EDGES + ")", 150, NOTIF_ERROR); return;
  }
  if (firstInvalidIndex(sig) >= 0) {
    notify("Pattern has edge reuse - fix before solving", 120, NOTIF_ERROR); return;
  }
  // Same sig + results already in gallery - just navigate there
  int galSize; synchronized(totalGallery) { galSize = totalGallery.size(); }
  boolean solverIdle = solverThread == null || !solverThread.isAlive();
  if (sig.equals(baseSignature) && galSize > 0 && solverIdle) {
    currentState = AppState.GALLERY; return;
  }
  startDecoding(sig, currentPatternStartDir);
  if (currentState != AppState.ERROR) currentState = AppState.GALLERY;
}





void syncSigToPath() { syncSigToPath(true); }
void syncSigToPath(boolean center) {
  String raw = customSignature;
  int inv = firstInvalidIndex(raw);
  String sig = (inv == 0) ? "" : (inv > 0) ? raw.substring(0, inv) : raw;
  if (!loadSigToDrawPath(sig)) {
    drawPath.clear(); drawUsedEdges.clear();
    drawStartAxial[0] = 0; drawStartAxial[1] = 0;
    drawEndAxial[0]   = 0; drawEndAxial[1]   = 0;
  }
  if (center) centerDrawViewOnPath();
}

void syncDrawToType() {
  customSignature = sigFromDrawPath();
  cursorPos       = customSignature.length();
  inputScrollX    = 0;
  // Set visual rotation to match the drawn starting direction so TYPE mode
  // renders the pattern in the same orientation it was drawn.
  currentPatternStartDir = drawPath.isEmpty() ? 0 : (drawPath.get(0) & 0xFF) % 6;
}

// panel mouse handlers

void handlePlaygroundPanel1Mouse(float panelX, float panelW) {
  if (mouseInRect(pgBtnNewPreset)) {
    presetModalOpen = true; newPresetName = ""; return;
  }
  if (mouseInRect(presetListArea) && presetListArea[2] > 0) {
    float btnH = 26 * UI_TEXT_SCALE, gap = 4;
    float rowH = btnH + gap;
    float delW = 22 * UI_TEXT_SCALE;
    int   row  = (int)((mouseY - presetListArea[1] + presetScrollY) / rowH);
    if (row >= 0 && row < presets.size()) {
      float rowScreenY = presetListArea[1] + row * rowH - presetScrollY;
      // Delete button
      float delX = presetListArea[0] + presetListArea[2] - 14 * UI_TEXT_SCALE - delW;
      if (rowScreenY >= presetListArea[1] && mouseInRect(delX+1, rowScreenY+1, delW-2, btnH-2)) {
        presets.remove(row);
        presetScrollY = constrain(presetScrollY, 0, max(0, presets.size() * rowH - presetListArea[3]));
        saveConfig(); notify("Preset deleted", 60, NOTIF_INFO); return;
      }
      loadPreset(row);
    }
  }
}

void handlePlaygroundPanel4Mouse() {
  if (mouseInRect(pgBtnCopySig))   { copySignature();    return; }
  if (mouseInRect(pgBtnCopyImg))   { exportImage();      return; }
  if (mouseInRect(pgBtnExportGIF)) { exportCurrentGIF(); return; }
  if (mouseInRect(btnGifUncap))    { gifUncapped = !gifUncapped; saveConfig(); return; }
  if (mouseInRect(pgBtnSolve))     { triggerSolve();     return; }
  if (mouseInRect(pgBtnClear))     { clearPlayground();  return; }
  if (mouseInRect(pgBtnOpenFolder)){ openExportsFolder(); return; }
}

// helpers

void loadPreset(int i) {
  if (i < 0 || i >= presets.size()) return;
  customSignature        = presets.get(i).signature;
  cursorPos              = customSignature.length();
  inputScrollX           = 0;
  currentPatternStartDir = presets.get(i).startDir;
  resetAnimation();
  syncSigToPath();
  notify("Loaded: " + presets.get(i).name, 90, NOTIF_INFO);
}

void drawPresetModal() {
  noStroke(); fill(0, 0, 0, 170); rect(0, 0, width, height);
  float boxW = min(420 * UI_TEXT_SCALE, width - 60);
  float boxH = 210 * UI_TEXT_SCALE;
  float boxX = width/2f - boxW/2f, boxY = height/2f - boxH/2f;
  float pad  = 20 * UI_TEXT_SCALE, cxB = width/2f;
  fill(20, 22, 28); stroke(60, 130, 80); strokeWeight(2);
  rect(boxX, boxY, boxW, boxH, 10);
  float y = boxY + 18 * UI_TEXT_SCALE;
  textAlign(CENTER, TOP); fill(155); textSize(11 * UI_TEXT_SCALE); noStroke();
  text("NEW PRESET", cxB, y); y += 20 * UI_TEXT_SCALE;
  stroke(40, 45, 58); strokeWeight(1); line(boxX+pad, y, boxX+boxW-pad, y); y += 12 * UI_TEXT_SCALE;
  // Pattern info
  String sig = customSignature.length() > 0 ? customSignature : "(empty)";
  if (sig.length() > 32) sig = sig.substring(0, 29) + "...";
  fill(70); textSize(8 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("Pattern: " + sig + "   Dir: " + currentPatternStartDir, boxX+pad, y); y += 14 * UI_TEXT_SCALE;
  // Name field
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("NAME", boxX+pad, y); y += 13 * UI_TEXT_SCALE;
  float fw = boxW - pad*2, fh = 28 * UI_TEXT_SCALE;
  noStroke(); fill(14, 14, 20); rect(boxX+pad, y, fw, fh, 4);
  boolean hasName = newPresetName.length() > 0;
  stroke(hasName ? color(60,160,90) : color(48,50,65)); strokeWeight(1.5f); noFill();
  rect(boxX+pad, y, fw, fh, 4);
  textAlign(LEFT, CENTER); fill(hasName ? 210 : 70); textSize(11 * UI_TEXT_SCALE); noStroke();
  text((hasName ? newPresetName : "enter a name") + (hasName && frameCount%60<30 ? "_" : ""), boxX+pad+8, y+fh/2f);
  y += fh + 14 * UI_TEXT_SCALE;
  // Buttons
  float bW2 = (boxW - pad*2 - 8) / 2f, bH = 28 * UI_TEXT_SCALE;
  boolean canSave = customSignature.length() > 0 && newPresetName.trim().length() > 0;
  btnPresetSave[0] = boxX+pad; btnPresetSave[1] = y; btnPresetSave[2] = bW2; btnPresetSave[3] = bH;
  boolean svHov = canSave && mouseInRect(btnPresetSave);
  noStroke(); fill(canSave ? (svHov ? color(28,70,42) : color(20,52,30)) : color(18,25,22));
  rect(btnPresetSave[0], y, bW2, bH, 4);
  stroke(canSave ? (svHov ? color(100,255,150) : color(55,130,75)) : color(32,42,35)); strokeWeight(1.5f); noFill();
  rect(btnPresetSave[0], y, bW2, bH, 4);
  textAlign(CENTER, CENTER); fill(canSave ? (svHov ? 255 : 175) : 50); textSize(10 * UI_TEXT_SCALE); noStroke();
  text("[ Save Preset ]", btnPresetSave[0]+bW2/2, y+bH/2); if (svHov) wantedCursor = HAND;
  btnPresetCancel[0] = boxX+pad+bW2+8; btnPresetCancel[1] = y; btnPresetCancel[2] = bW2; btnPresetCancel[3] = bH;
  boolean caHov = mouseInRect(btnPresetCancel);
  noStroke(); fill(caHov ? color(50,20,22) : color(28,18,20));
  rect(btnPresetCancel[0], y, bW2, bH, 4);
  stroke(caHov ? color(255,80,80) : color(90,38,45)); strokeWeight(1); noFill();
  rect(btnPresetCancel[0], y, bW2, bH, 4);
  textAlign(CENTER, CENTER); fill(caHov ? color(255,100,100) : color(135,60,65)); textSize(10 * UI_TEXT_SCALE); noStroke();
  text("[ Cancel ]", btnPresetCancel[0]+bW2/2, y+bH/2); if (caHov) wantedCursor = HAND;
}

void commitNewPreset() {
  String trimmed = newPresetName.trim();
  if (trimmed.length() == 0 || customSignature.length() == 0) return;
  presets.add(new Preset(trimmed, customSignature, currentPatternStartDir));
  presetModalOpen = false; newPresetName = "";
  saveConfig();
  notify("Preset saved: " + trimmed, 90, NOTIF_SUCCESS);
}

void clearPlayground() {
  pendingRestart  = false;
  customSignature = "";
  cursorPos       = 0;
  inputScrollX    = 0;
  drawPath.clear();
  drawUsedEdges.clear();
  drawStartAxial[0] = 0; drawStartAxial[1] = 0;
  drawEndAxial[0]   = 0; drawEndAxial[1]   = 0;
  resetAnimation();
  centerDrawViewOnPath(); // reset viewport to empty state
  notify("Pattern cleared", 60, NOTIF_INFO);
}
