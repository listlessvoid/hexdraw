// button rects - [x, y, w, h], rebuilt every frame
float[] btnRotMinus  = new float[4];
float[] btnRotPlus   = new float[4];
float[] btnArcToggle      = new float[4];
float[] btnGridToggle     = new float[4];
float[] btnMarkersToggle  = new float[4];
float[] btnCopySig   = new float[4];
float[] btnCopyImg   = new float[4];
float[] btnExportGIF    = new float[4];
float[] btnOpenFolder   = new float[4];
float[] panelScrubBar = new float[4]; // [x, y, w, h] for mini scrubber in panel 1
boolean anyPanelBtnReady = false; // true once at least one frame drawn with panel open

// palette list
float[] btnNewPalette  = new float[4];
float[] paletteListArea = new float[4]; // visible list region [x,y,w,h]
float   paletteListScrollY = 0f;

// sliders
float[] traceSliderBar    = new float[4];
float[] pulseSliderBar    = new float[4];
float[] gradientSliderBar = new float[4];
float[] strokeSliderBar   = new float[4];
float[] arcInsetSliderBar = new float[4];

// palette modal
float[] btnModalPickStart  = new float[4];
float[] btnModalPickEnd    = new float[4];
float[] btnModalCreate     = new float[4];
float[] btnModalCancel     = new float[4];

float[] btnBgToggle = new float[4];
float[] btnBgPick   = new float[4];
float[] btnGifUncap  = new float[4];

// panel 5
float[] btnResetConfig = new float[4];
float[] btnCleanupOpen = new float[4];
float[] btnCleanupDo   = new float[4];
float[] btnCleanupNo   = new float[4];

void drawGalleryInterface() {
  int currentAvailableSize;
  synchronized(totalGallery) { currentAvailableSize = totalGallery.size(); }

  // Persistent notification while solver thread is alive
  if (solverThread != null && solverThread.isAlive()) {
    notifyPersistent("solve", "[~]  Decoding...  " + currentAvailableSize + " found", NOTIF_INFO);
  } else {
    dismissPersistent("solve");
  }

  // Panel geometry
  float panelW   = width * panelSlide * PANEL_WIDTH_FRAC;
  float panelX   = width - panelW;
  float drawAreaW = panelX;

  // Panel background
  if (panelSlide > 0.01f) {
    noStroke(); fill(13, 13, 18);
    rect(panelX, 0, panelW, height);
    stroke(45, 45, 55); strokeWeight(1);
    line(panelX, 0, panelX, height);

    if (panelW > 80) { // only render content once panel is substantially open
      anyPanelBtnReady = true;
      if      (openPanel == 1) drawPanel1(panelX, panelW, currentAvailableSize);
      else if (openPanel == 2) drawPanel2(panelX, panelW);
      else if (openPanel == 3) drawPanel3(panelX, panelW);
      else if (openPanel == 4) drawPanel4(panelX, panelW, currentAvailableSize);
      else if (openPanel == 5) drawPanel5(panelX, panelW);
    }
  }

  // Panel toggle hints (top-left) + back hint (top-right of draw area)
  noStroke(); fill(130); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP);
  text("[1] Nav  [2] Color  [3] Render  [4] Export  [5] About", 10, 10);
  textAlign(RIGHT, TOP);
  text("Backspace / Right-click - back to playground", drawAreaW - 10, 10);

  // Pattern
  synchronized(totalGallery) {
    if (currentAvailableSize == 0) return;
    if (galleryIndex >= currentAvailableSize) galleryIndex = currentAvailableSize - 1;
    if (galleryIndex < 0) galleryIndex = 0;

    byte[] activePath = totalGallery.get(galleryIndex);
    String activeSignature = bytesToSignature(activePath);

    if (showBackground) {
      pushStyle(); colorMode(HSB, 360, 100, 100);
      noStroke(); fill(bgColorH, bgColorS, bgColorB);
      rect(0, 0, drawAreaW, height);
      popStyle();
    }
    drawHexPath(activePath, drawAreaW);

    // Signature + edge count below pattern
    textAlign(CENTER, CENTER);
    textSize(18 * UI_TEXT_SCALE); fill(100, 255, 150); noStroke();
    text(activeSignature, drawAreaW / 2f, height - 46 * UI_TEXT_SCALE);
    textSize(9 * UI_TEXT_SCALE); fill(70);
    text(totalEdges + " edges", drawAreaW / 2f, height - 28 * UI_TEXT_SCALE);
  }

  // Pattern index: top-right of draw area
  String idxStr = formatIndex(galleryIndex + 1, currentAvailableSize);
  textAlign(RIGHT, TOP); fill(65); textSize(9 * UI_TEXT_SCALE); noStroke();
  text(idxStr, drawAreaW - 10, 10);

  // 3px position strip at absolute bottom of draw area
  float fillFrac = (currentAvailableSize > 1) ? (float)galleryIndex / (float)(currentAvailableSize - 1) : 0f;
  noStroke();
  fill(60, 140, 90);  rect(0, height - 3, drawAreaW * fillFrac, 3);
  fill(25, 35, 28);   rect(drawAreaW * fillFrac, height - 3, drawAreaW * (1f - fillFrac), 3);

  // Goto overlay (G key)
  if (gotoInputActive) {
    drawGotoOverlay(currentAvailableSize);
  }
}


// panel 1 - navigate
void drawPanel1(float px, float pw, int totalCount) {
  float pad = 14;
  float y   = 18 * UI_TEXT_SCALE;
  float cxP = px + pw / 2f;

  // Header
  textAlign(CENTER, TOP); fill(160); textSize(10 * UI_TEXT_SCALE); noStroke();
  text("NAVIGATE", cxP, y); y += 18 * UI_TEXT_SCALE;
  stroke(40, 40, 50); strokeWeight(1);
  line(px + pad, y, px + pw - pad, y); y += 12 * UI_TEXT_SCALE;

  if (totalCount == 0) return;

  // Mini scrubber
  float barX = px + pad;
  float barW = pw - pad * 2;
  float barH = 10 * UI_TEXT_SCALE;
  drawMiniScrubber(barX, y, barW, barH, totalCount);
  panelScrubBar[0] = barX; panelScrubBar[1] = y; panelScrubBar[2] = barW; panelScrubBar[3] = barH;
  y += barH + 14 * UI_TEXT_SCALE;

  // Current index
  textAlign(CENTER, TOP); fill(180); textSize(11 * UI_TEXT_SCALE); noStroke();
  text(String.format("%,d", galleryIndex + 1) + " / " + formatTotal(totalCount), cxP, y);
  y += 18 * UI_TEXT_SCALE;

  // Nav button row helpers
  float btnH   = 26 * UI_TEXT_SCALE;
  float btnGap = 5;
  float bW2    = (pw - pad * 2 - btnGap) / 2f; // half width
  float bW3    = (pw - pad * 2 - btnGap * 2) / 3f;

  // Row: Home | End
  float bY = y;
  drawPanelBtn(px + pad, bY, bW2, btnH, "HOME", true);
  drawPanelBtn(px + pad + bW2 + btnGap, bY, bW2, btnH, "END", true);
  y += btnH + btnGap;

  // Row: −100 | −10 | −1
  drawPanelBtn(px + pad,                    y, bW3, btnH, "-100", totalCount > 1);
  drawPanelBtn(px + pad + bW3 + btnGap,     y, bW3, btnH, "-10",  totalCount > 1);
  drawPanelBtn(px + pad + (bW3 + btnGap)*2, y, bW3, btnH, "-1",   totalCount > 1);
  y += btnH + btnGap;

  // Row: +1 | +10 | +100
  drawPanelBtn(px + pad,                    y, bW3, btnH, "+1",   totalCount > 1);
  drawPanelBtn(px + pad + bW3 + btnGap,     y, bW3, btnH, "+10",  totalCount > 1);
  drawPanelBtn(px + pad + (bW3 + btnGap)*2, y, bW3, btnH, "+100", totalCount > 1);
  y += btnH + btnGap;

  // Row: Random
  drawPanelBtn(px + pad, y, pw - pad * 2, btnH, "RANDOM", totalCount > 1);

  // Key hints pinned to panel bottom
  float hintY = height - 54 * UI_TEXT_SCALE;
  stroke(35, 40, 48); strokeWeight(1);
  line(px + pad, hintY - 8 * UI_TEXT_SCALE, px + pw - pad, hintY - 8 * UI_TEXT_SCALE);
  textAlign(LEFT, TOP); fill(110); textSize(8 * UI_TEXT_SCALE); noStroke();
  text("<- -> : +/-1    Up Dn : +/-100", px + pad, hintY); hintY += 12 * UI_TEXT_SCALE;
  text("SHIFT+<- -> : +/-1%    O : goto", px + pad, hintY); hintY += 12 * UI_TEXT_SCALE;
  text("HOME / END    R : random", px + pad, hintY);
}

void drawMiniScrubber(float barX, float barY, float barW, float barH, int totalCount) {
  noStroke(); fill(30, 35, 40); rect(barX, barY, barW, barH, 3);
  float frac = (totalCount > 1) ? (float)galleryIndex / (float)(totalCount - 1) : 0f;
  fill(55, 140, 80); rect(barX, barY, barW * frac, barH, 3);
  float mX = barX + barW * frac;
  fill(100, 255, 150); noStroke(); rect(mX - 2, barY - 3, 4, barH + 6, 1);
}


// panel 2 - color
void drawPanel2(float px, float pw) {
  float pad = 14;
  float y   = 18 * UI_TEXT_SCALE;
  float cxP = px + pw / 2f;

  textAlign(CENTER, TOP); fill(160); textSize(10 * UI_TEXT_SCALE); noStroke();
  text("COLOR", cxP, y); y += 18 * UI_TEXT_SCALE;
  stroke(40, 40, 50); strokeWeight(1);
  line(px + pad, y, px + pw - pad, y); y += 12 * UI_TEXT_SCALE;

  // Palette
  fill(120); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("PALETTE", px + pad, y); y += 13 * UI_TEXT_SCALE;

  // New Palette button - always visible above the list
  btnNewPalette[0] = px + pad; btnNewPalette[1] = y;
  btnNewPalette[2] = pw - pad * 2; btnNewPalette[3] = 24 * UI_TEXT_SCALE;
  boolean npHov = mouseInRect(btnNewPalette);
  noStroke(); fill(npHov ? color(25, 40, 60) : color(18, 28, 42));
  rect(btnNewPalette[0], y, btnNewPalette[2], btnNewPalette[3], 4);
  stroke(npHov ? color(80, 130, 200) : color(42, 65, 100)); strokeWeight(1.5f); noFill();
  rect(btnNewPalette[0], y, btnNewPalette[2], btnNewPalette[3], 4);
  textAlign(CENTER, CENTER); fill(npHov ? 210 : 130); textSize(9 * UI_TEXT_SCALE); noStroke();
  text("+ New Palette", px + pad + (pw - pad * 2) / 2, y + btnNewPalette[3] / 2);
  if (npHov) wantedCursor = HAND;
  y += btnNewPalette[3] + 5 * UI_TEXT_SCALE;

  // Scrollable palette list
  float rowH    = 28 * UI_TEXT_SCALE;
  int   totalP  = BUILTIN_PALETTE_COUNT + customPalettes.size();
  float contentH = totalP * rowH;
  float maxListH = min(contentH, 5 * rowH);

  paletteListScrollY = constrain(paletteListScrollY, 0, max(0, contentH - maxListH));
  paletteListArea[0] = px + pad; paletteListArea[1] = y;
  paletteListArea[2] = pw - pad * 2; paletteListArea[3] = maxListH;

  // Clip and draw rows
  pushStyle();
  clip(paletteListArea[0], paletteListArea[1], paletteListArea[2], paletteListArea[3]);
  for (int p = 0; p < totalP; p++) {
    float rowY = y + p * rowH - paletteListScrollY;
    if (rowY + rowH < y) continue;
    if (rowY > y + maxListH) break;
    drawPaletteRow(p, px + pad, rowY, pw - pad * 2, rowH);
  }
  noClip();
  popStyle();

  // Thin scrollbar if content overflows
  if (contentH > maxListH) {
    float sbW  = 3;
    float sbX  = px + pw - pad - sbW;
    float sbH  = maxListH * maxListH / contentH;
    float sbFrac = paletteListScrollY / max(1, contentH - maxListH);
    float sbY  = y + sbFrac * (maxListH - sbH);
    noStroke(); fill(38, 42, 50); rect(sbX, y, sbW, maxListH, 1);
    fill(90, 100, 115); rect(sbX, sbY, sbW, max(sbH, 12), 1);
  }

  y += maxListH + 10 * UI_TEXT_SCALE;

  // Background
  fill(120); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("BACKGROUND", px + pad, y); y += 13 * UI_TEXT_SCALE;

  btnBgToggle[0] = px + pad; btnBgToggle[1] = y; btnBgToggle[2] = pw - pad * 2; btnBgToggle[3] = 26 * UI_TEXT_SCALE;
  boolean bgHov = mouseInRect(btnBgToggle);
  noStroke(); fill(showBackground ? color(25, 45, 70) : color(22, 22, 28));
  if (bgHov) fill(showBackground ? color(30, 55, 85) : color(28, 28, 35));
  rect(btnBgToggle[0], btnBgToggle[1], btnBgToggle[2], btnBgToggle[3], 4);
  stroke(showBackground ? color(100, 175, 255) : color(60, 60, 70)); strokeWeight(1.5f); noFill();
  rect(btnBgToggle[0], btnBgToggle[1], btnBgToggle[2], btnBgToggle[3], 4);
  textAlign(CENTER, CENTER); fill(showBackground ? color(100, 175, 255) : color(140)); textSize(10 * UI_TEXT_SCALE); noStroke();
  text("Background: " + (showBackground ? "ON" : "OFF"), px + pad + (pw - pad*2)/2, btnBgToggle[1] + btnBgToggle[3]/2);
  if (bgHov) wantedCursor = HAND;
  y += 26 * UI_TEXT_SCALE + 4 * UI_TEXT_SCALE;

  if (showBackground) {
    float swatchW2 = 26 * UI_TEXT_SCALE, swatchH2 = 20 * UI_TEXT_SCALE;
    pushStyle(); colorMode(HSB, 360, 100, 100);
    fill(bgColorH, bgColorS, bgColorB); noStroke();
    rect(px + pad, y, swatchW2, swatchH2, 3);
    popStyle();
    btnBgPick[0] = px + pad + swatchW2 + 5 * UI_TEXT_SCALE; btnBgPick[1] = y;
    btnBgPick[2] = pw - pad * 2 - swatchW2 - 5 * UI_TEXT_SCALE; btnBgPick[3] = swatchH2;
    drawPickColorBtn(btnBgPick, bgPickerOpen);
    y += swatchH2 + 8 * UI_TEXT_SCALE;
  } else {
    y += 4 * UI_TEXT_SCALE;
  }

  // Gradient Cycle
  String gradLabel = (gradientCycle < 0.05f) ? "AUTO" : nf(gradientCycle, 1, 1) + "x";
  fill(120); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("GRADIENT CYCLE: " + gradLabel, px + pad, y); y += 13 * UI_TEXT_SCALE;
  gradientSliderBar[0] = px + pad; gradientSliderBar[1] = y; gradientSliderBar[2] = pw - pad*2; gradientSliderBar[3] = 12 * UI_TEXT_SCALE;
  drawSliderLinear(gradientSliderBar, gradientCycle, 0f, 5f);
  if (mouseInRect(gradientSliderBar)) wantedCursor = HAND;

  float hintY2 = height - 28 * UI_TEXT_SCALE;
  stroke(35, 40, 48); strokeWeight(1);
  line(px + pad, hintY2 - 8 * UI_TEXT_SCALE, px + pw - pad, hintY2 - 8 * UI_TEXT_SCALE);
  textAlign(LEFT, TOP); fill(110); textSize(8 * UI_TEXT_SCALE); noStroke();
  text("P : cycle palette", px + pad, hintY2);
}


// panel 3 - render
void drawPanel3(float px, float pw) {
  float pad = 14;
  float y   = 18 * UI_TEXT_SCALE;
  float cxP = px + pw / 2f;

  textAlign(CENTER, TOP); fill(160); textSize(10 * UI_TEXT_SCALE); noStroke();
  text("RENDER", cxP, y); y += 18 * UI_TEXT_SCALE;
  stroke(40, 40, 50); strokeWeight(1);
  line(px + pad, y, px + pw - pad, y); y += 12 * UI_TEXT_SCALE;

  // Rotation
  fill(120); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("ROTATION", px + pad, y); y += 13 * UI_TEXT_SCALE;

  float btnH  = 26 * UI_TEXT_SCALE;
  float btnW3 = (pw - pad * 2 - 8) / 3f;
  float bGap  = 4;

  btnRotMinus[0] = px + pad;                       btnRotMinus[1] = y; btnRotMinus[2] = btnW3; btnRotMinus[3] = btnH;
  btnRotPlus[0]  = px + pad + (btnW3 + bGap) * 2; btnRotPlus[1]  = y; btnRotPlus[2]  = btnW3; btnRotPlus[3]  = btnH;
  drawPanelBtn(btnRotMinus[0], y, btnW3, btnH, "-", true);
  float valX = px + pad + btnW3 + bGap;
  noStroke(); fill(20, 25, 30); rect(valX, y, btnW3, btnH, 4);
  textAlign(CENTER, CENTER); fill(200); textSize(11 * UI_TEXT_SCALE);
  text(currentPatternStartDir + " / 6", valX + btnW3/2, y + btnH/2);
  drawPanelBtn(btnRotPlus[0], y, btnW3, btnH, "+", true);
  y += btnH + 10 * UI_TEXT_SCALE;

  // Arc mode
  fill(120); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("ARC RENDERING", px + pad, y); y += 13 * UI_TEXT_SCALE;
  btnArcToggle[0] = px + pad; btnArcToggle[1] = y; btnArcToggle[2] = pw - pad * 2; btnArcToggle[3] = btnH;
  boolean arcHov = mouseInRect(btnArcToggle);
  noStroke(); fill(arcMode ? color(30,60,40) : color(22,22,28)); if (arcHov) fill(arcMode ? color(35,70,45) : color(28,28,35));
  rect(btnArcToggle[0], y, btnArcToggle[2], btnH, 4);
  stroke(arcMode ? color(100,255,150) : color(60,60,70)); strokeWeight(1.5f); noFill(); rect(btnArcToggle[0], y, btnArcToggle[2], btnH, 4);
  textAlign(CENTER, CENTER); fill(arcMode ? color(100,255,150) : color(140)); textSize(10*UI_TEXT_SCALE); noStroke();
  text("Arc mode: " + (arcMode ? "ON" : "OFF") + "  [H]", px+pad+(pw-pad*2)/2, y+btnH/2);
  if (arcHov) wantedCursor = HAND; y += btnH + 6 * UI_TEXT_SCALE;

  // Grid dots
  fill(120); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("HEX GRID DOTS", px + pad, y); y += 13 * UI_TEXT_SCALE;
  btnGridToggle[0] = px + pad; btnGridToggle[1] = y; btnGridToggle[2] = pw - pad * 2; btnGridToggle[3] = btnH;
  boolean gridHov = mouseInRect(btnGridToggle);
  noStroke(); fill(gridDotsMode ? color(25,45,70) : color(22,22,28)); if (gridHov) fill(gridDotsMode ? color(30,55,85) : color(28,28,35));
  rect(btnGridToggle[0], y, btnGridToggle[2], btnH, 4);
  stroke(gridDotsMode ? color(100,175,255) : color(60,60,70)); strokeWeight(1.5f); noFill(); rect(btnGridToggle[0], y, btnGridToggle[2], btnH, 4);
  textAlign(CENTER, CENTER); fill(gridDotsMode ? color(100,175,255) : color(140)); textSize(10*UI_TEXT_SCALE); noStroke();
  text("Grid dots: " + (gridDotsMode ? "ON" : "OFF") + "  [G]", px+pad+(pw-pad*2)/2, y+btnH/2);
  if (gridHov) wantedCursor = HAND; y += btnH + 6 * UI_TEXT_SCALE;

  // Export markers
  fill(120); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("EXPORT MARKERS", px + pad, y); y += 13 * UI_TEXT_SCALE;
  btnMarkersToggle[0] = px + pad; btnMarkersToggle[1] = y; btnMarkersToggle[2] = pw - pad * 2; btnMarkersToggle[3] = btnH;
  boolean markHov = mouseInRect(btnMarkersToggle);
  noStroke(); fill(showExportMarkers ? color(40,30,60) : color(22,22,28)); if (markHov) fill(showExportMarkers ? color(50,40,75) : color(28,28,35));
  rect(btnMarkersToggle[0], y, btnMarkersToggle[2], btnH, 4);
  stroke(showExportMarkers ? color(180,130,255) : color(60,60,70)); strokeWeight(1.5f); noFill(); rect(btnMarkersToggle[0], y, btnMarkersToggle[2], btnH, 4);
  textAlign(CENTER, CENTER); fill(showExportMarkers ? color(180,130,255) : color(140)); textSize(10*UI_TEXT_SCALE); noStroke();
  text("Start/end markers: " + (showExportMarkers ? "ON" : "OFF"), px+pad+(pw-pad*2)/2, y+btnH/2);
  if (markHov) wantedCursor = HAND; y += btnH + 10 * UI_TEXT_SCALE;

  // Trace speed
  fill(120); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("TRACE SPEED: " + (traceSpeed >= 2.99f ? "INSTANT" : nf(traceSpeed, 1, 2)), px + pad, y); y += 13 * UI_TEXT_SCALE;
  traceSliderBar[0] = px + pad; traceSliderBar[1] = y; traceSliderBar[2] = pw - pad*2; traceSliderBar[3] = 12 * UI_TEXT_SCALE;
  drawSlider(traceSliderBar, traceSpeed, 0.04f, 3.0f); if (mouseInRect(traceSliderBar)) wantedCursor = HAND;
  y += 12 * UI_TEXT_SCALE + 10 * UI_TEXT_SCALE;

  // Pulse speed
  fill(120); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("PULSE SPEED: " + (pulseSpeed <= 0.0031f ? "OFF" : nf(pulseSpeed, 1, 3)), px + pad, y); y += 13 * UI_TEXT_SCALE;
  pulseSliderBar[0] = px + pad; pulseSliderBar[1] = y; pulseSliderBar[2] = pw - pad*2; pulseSliderBar[3] = 12 * UI_TEXT_SCALE;
  drawSlider(pulseSliderBar, pulseSpeed, 0.003f, 0.25f); if (mouseInRect(pulseSliderBar)) wantedCursor = HAND;
  y += 12 * UI_TEXT_SCALE + 10 * UI_TEXT_SCALE;

  // Stroke width
  fill(120); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("STROKE WIDTH: " + nf(strokeWidthBase, 1, 1), px + pad, y); y += 13 * UI_TEXT_SCALE;
  strokeSliderBar[0] = px + pad; strokeSliderBar[1] = y; strokeSliderBar[2] = pw - pad*2; strokeSliderBar[3] = 12 * UI_TEXT_SCALE;
  drawSliderLinear(strokeSliderBar, strokeWidthBase, 1f, 12f); if (mouseInRect(strokeSliderBar)) wantedCursor = HAND;
  y += 12 * UI_TEXT_SCALE + 10 * UI_TEXT_SCALE;

  // Arc inset
  fill(arcMode ? color(120) : color(65)); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("ARC INSET: " + nf(arcInset, 1, 2) + (arcMode ? "" : "  (arc off)"), px + pad, y); y += 13 * UI_TEXT_SCALE;
  arcInsetSliderBar[0] = px + pad; arcInsetSliderBar[1] = y; arcInsetSliderBar[2] = pw - pad*2; arcInsetSliderBar[3] = 12 * UI_TEXT_SCALE;
  drawSliderLinear(arcInsetSliderBar, arcInset, 0.05f, 0.65f); if (mouseInRect(arcInsetSliderBar)) wantedCursor = HAND;

  float hintY3 = height - 42 * UI_TEXT_SCALE;
  stroke(35, 40, 48); strokeWeight(1);
  line(px + pad, hintY3 - 8 * UI_TEXT_SCALE, px + pw - pad, hintY3 - 8 * UI_TEXT_SCALE);
  textAlign(LEFT, TOP); fill(110); textSize(8 * UI_TEXT_SCALE); noStroke();
  text("T / SHIFT+T : rotate", px + pad, hintY3); hintY3 += 11 * UI_TEXT_SCALE;
  text("H : arc mode   G : grid dots", px + pad, hintY3);
}

void drawPaletteRow(int p, float rx, float ry, float rw, float rh) {
  boolean isSelected = (p == currentPalette);
  boolean isCustom   = (p >= BUILTIN_PALETTE_COUNT);
  int     ci         = p - BUILTIN_PALETTE_COUNT;

  float nameH   = 14 * UI_TEXT_SCALE;
  float gradH   = 10 * UI_TEXT_SCALE;
  float delBtnW = 20 * UI_TEXT_SCALE;
  float gradW   = isCustom ? (rw - delBtnW - 2) : rw;

  // Row background
  boolean hovered = mouseInRect(rx, ry, rw, rh);
  noStroke();
  if      (isSelected) fill(22, 40, 28);
  else if (hovered)    fill(20, 22, 28);
  else                 fill(16, 16, 22);
  rect(rx, ry, rw, rh);

  if (isSelected) {
    stroke(100, 255, 150); strokeWeight(1.5f); noFill();
    rect(rx, ry, rw, rh);
  }

  // Delete button for custom palettes
  if (isCustom) {
    float delX = rx + rw - delBtnW;
    boolean delHov = mouseInRect(delX + 2, ry + 2, delBtnW - 4, nameH - 4);
    noStroke(); fill(delHov ? color(70, 25, 28) : color(30, 15, 18));
    rect(delX + 2, ry + 2, delBtnW - 4, nameH - 4, 2);
    stroke(delHov ? color(255, 80, 80) : color(100, 45, 50)); strokeWeight(1); noFill();
    rect(delX + 2, ry + 2, delBtnW - 4, nameH - 4, 2);
    textAlign(CENTER, CENTER); fill(delHov ? color(255, 110, 110) : color(140, 65, 70));
    textSize(8 * UI_TEXT_SCALE); noStroke();
    text("x", delX + delBtnW / 2, ry + nameH / 2);
    if (delHov) wantedCursor = HAND;
  }

  // Name text
  String name = paletteName(p);
  textAlign(LEFT, TOP); fill(isSelected ? 210 : 120); textSize(8 * UI_TEXT_SCALE); noStroke();
  text(name, rx + 4, ry + 2);

  // Reversed indicator
  if (isSelected && paletteReversed) {
    textAlign(RIGHT, TOP); fill(100, 200, 150); textSize(8 * UI_TEXT_SCALE); noStroke();
    text("<->", rx + gradW - 4, ry + 2);
  }

  // Gradient strip (2px inset left/right so it never bleeds into the row border)
  float gradY     = ry + nameH + 2;
  float gradInset = 2;
  pushStyle();
  colorMode(HSB, 360, 100, 100);
  drawGradientStrip(rx + gradInset, gradY, gradW - gradInset * 2, gradH, p, isSelected && paletteReversed);
  popStyle();

  if (hovered && !isSelected) wantedCursor = HAND;
}


void drawGradientStrip(float x, float y, float w, float h, int palette, boolean reversed) {
  int steps = max(2, (int)(w / 4));
  float sw = w / steps;
  noStroke();
  for (int i = 0; i < steps; i++) {
    float t = (float)i / (steps - 1);
    if (reversed) t = 1.0f - t;
    fill(pathColorRaw(t, palette));
    rect(x + i * sw, y, sw + 0.5f, h);
  }
}

String paletteName(int p) {
  if (p < BUILTIN_PALETTE_COUNT) {
    String[] names = {"Cool->Warm", "Monochrome", "Hexcasting"};
    return names[p];
  }
  int ci = p - BUILTIN_PALETTE_COUNT;
  return (ci < customPalettes.size()) ? customPalettes.get(ci).name : "?";
}

void drawSlider(float[] bar, float value, float minV, float maxV) {
  float frac = constrain(log(value/minV) / log(maxV/minV), 0f, 1f);
  noStroke(); fill(30, 35, 40); rect(bar[0], bar[1], bar[2], bar[3], 3);
  fill(55, 120, 90); rect(bar[0], bar[1], bar[2] * frac, bar[3], 3);
  float mX = bar[0] + bar[2] * frac;
  fill(150); noStroke(); rect(mX - 3, bar[1] - 2, 6, bar[3] + 4, 2);
}

void drawSliderLinear(float[] bar, float value, float minV, float maxV) {
  float frac = constrain((value - minV) / (maxV - minV), 0f, 1f);
  noStroke(); fill(30, 35, 40); rect(bar[0], bar[1], bar[2], bar[3], 3);
  fill(55, 120, 90); rect(bar[0], bar[1], bar[2] * frac, bar[3], 3);
  float mX = bar[0] + bar[2] * frac;
  fill(150); noStroke(); rect(mX - 3, bar[1] - 2, 6, bar[3] + 4, 2);
}


// panel 4 - export
void drawPanel4(float px, float pw, int totalCount) {
  float pad = 14;
  float y   = 18 * UI_TEXT_SCALE;
  float cxP = px + pw / 2f;

  textAlign(CENTER, TOP); fill(160); textSize(10 * UI_TEXT_SCALE); noStroke();
  text("EXPORT", cxP, y); y += 18 * UI_TEXT_SCALE;
  stroke(40, 40, 50); strokeWeight(1);
  line(px + pad, y, px + pw - pad, y); y += 12 * UI_TEXT_SCALE;

  // Signature display
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("SIGNATURE", px + pad, y); y += 12 * UI_TEXT_SCALE;

  String sig = "";
  synchronized(totalGallery) {
    if (!totalGallery.isEmpty() && galleryIndex >= 0 && galleryIndex < totalGallery.size()) {
      sig = bytesToSignature(totalGallery.get(galleryIndex));
    }
  }

  float sigBoxW = pw - pad * 2;
  float sigBoxH = 52 * UI_TEXT_SCALE;
  noStroke(); fill(18, 18, 25); rect(px + pad, y, sigBoxW, sigBoxH, 4);
  stroke(45, 45, 55); strokeWeight(1); noFill();
  rect(px + pad, y, sigBoxW, sigBoxH, 4);
  pushStyle();
  clip(px + pad + 4, y + 3, sigBoxW - 8, sigBoxH - 6);
  textAlign(LEFT, TOP); fill(150); textSize(10 * UI_TEXT_SCALE); noStroke();
  text(sig, px + pad + 6, y + 6, sigBoxW - 12, sigBoxH - 12);
  noClip();
  popStyle();
  y += sigBoxH + 8 * UI_TEXT_SCALE;

  btnCopySig[0] = px + pad; btnCopySig[1] = y; btnCopySig[2] = pw - pad*2; btnCopySig[3] = 28 * UI_TEXT_SCALE;
  boolean copyHover = mouseInRect(btnCopySig);
  noStroke(); fill(copyHover ? color(35, 65, 45) : color(25, 50, 35));
  rect(btnCopySig[0], btnCopySig[1], btnCopySig[2], btnCopySig[3], 4);
  stroke(100, 255, 150); strokeWeight(1.5f); noFill();
  rect(btnCopySig[0], btnCopySig[1], btnCopySig[2], btnCopySig[3], 4);
  textAlign(CENTER, CENTER); fill(copyHover ? 255 : 200); textSize(10 * UI_TEXT_SCALE); noStroke();
  text("[ Copy Signature ]  [C]", cxP, y + btnCopySig[3]/2);
  if (copyHover) wantedCursor = HAND;
  y += 28 * UI_TEXT_SCALE + 6 * UI_TEXT_SCALE;

  btnCopyImg[0] = px + pad; btnCopyImg[1] = y; btnCopyImg[2] = pw - pad*2; btnCopyImg[3] = 28 * UI_TEXT_SCALE;
  boolean imgHover = mouseInRect(btnCopyImg);
  noStroke(); fill(imgHover ? color(35, 50, 75) : color(22, 30, 48));
  rect(btnCopyImg[0], btnCopyImg[1], btnCopyImg[2], btnCopyImg[3], 4);
  stroke(80, 140, 255); strokeWeight(1.5f); noFill();
  rect(btnCopyImg[0], btnCopyImg[1], btnCopyImg[2], btnCopyImg[3], 4);
  textAlign(CENTER, CENTER); fill(imgHover ? 255 : 190); textSize(10 * UI_TEXT_SCALE); noStroke();
  text("[ Copy Image to Clipboard ]", cxP, y + btnCopyImg[3]/2);
  if (imgHover) wantedCursor = HAND;
  y += 28 * UI_TEXT_SCALE + 6 * UI_TEXT_SCALE;

  btnExportGIF[0] = px + pad; btnExportGIF[1] = y; btnExportGIF[2] = pw - pad*2; btnExportGIF[3] = 28 * UI_TEXT_SCALE;
  boolean gifHov = mouseInRect(btnExportGIF);
  noStroke(); fill(gifHov ? color(35, 28, 50) : color(22, 18, 35));
  rect(btnExportGIF[0], btnExportGIF[1], btnExportGIF[2], btnExportGIF[3], 4);
  stroke(gifHov ? color(180, 120, 255) : color(80, 55, 120)); strokeWeight(1.5f); noFill();
  rect(btnExportGIF[0], btnExportGIF[1], btnExportGIF[2], btnExportGIF[3], 4);
  textAlign(CENTER, CENTER); fill(gifHov ? color(210, 170, 255) : color(130, 90, 180));
  textSize(10 * UI_TEXT_SCALE); noStroke();
  text("[ Export GIF ]  [J]", cxP, y + btnExportGIF[3]/2);
  if (gifHov) wantedCursor = HAND;
  y += 28 * UI_TEXT_SCALE + 6 * UI_TEXT_SCALE;

  drawGifUncapToggle(px, pw, y); y += gifUncapped ? 52 * UI_TEXT_SCALE : 34 * UI_TEXT_SCALE;

  btnOpenFolder[0] = px+pad; btnOpenFolder[1] = y; btnOpenFolder[2] = pw-pad*2; btnOpenFolder[3] = 24*UI_TEXT_SCALE;
  boolean ofHov = mouseInRect(btnOpenFolder);
  noStroke(); fill(ofHov ? color(28,28,40) : color(20,20,30));
  rect(btnOpenFolder[0], y, btnOpenFolder[2], btnOpenFolder[3], 4);
  stroke(ofHov ? color(140,140,200) : color(55,55,80)); strokeWeight(1); noFill();
  rect(btnOpenFolder[0], y, btnOpenFolder[2], btnOpenFolder[3], 4);
  textAlign(CENTER, CENTER); fill(ofHov ? 200 : 100); textSize(9*UI_TEXT_SCALE); noStroke();
  text("[ Open Exports Folder ]", cxP, y + btnOpenFolder[3]/2);
  if (ofHov) wantedCursor = HAND;
  y += 24 * UI_TEXT_SCALE + 14 * UI_TEXT_SCALE;

  // Stats
  stroke(40, 40, 50); strokeWeight(1);
  line(px + pad, y, px + pw - pad, y); y += 10 * UI_TEXT_SCALE;
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("STATS", px + pad, y); y += 13 * UI_TEXT_SCALE;
  fill(130); textSize(8 * UI_TEXT_SCALE);
  text("Edges: " + totalEdges, px + pad, y); y += 11 * UI_TEXT_SCALE;
  text("Nodes: " + numNodes, px + pad, y); y += 11 * UI_TEXT_SCALE;
  text("Permutations found: " + String.format("%,d", totalPathsFound.get()), px + pad, y); y += 11 * UI_TEXT_SCALE;
  text("Rotation: " + currentPatternStartDir + " / 6", px + pad, y);

  // Key hints pinned to panel bottom
  float hintY3 = height - 30 * UI_TEXT_SCALE;
  stroke(35, 40, 48); strokeWeight(1);
  line(px + pad, hintY3 - 8 * UI_TEXT_SCALE, px + pw - pad, hintY3 - 8 * UI_TEXT_SCALE);
  textAlign(LEFT, TOP); fill(110); textSize(8 * UI_TEXT_SCALE); noStroke();
  text("C : copy signature    SHIFT+C / I : copy image", px + pad, hintY3);
}


// New palette modal
void drawNewPaletteModal() {
  // Darken background
  noStroke(); fill(0, 0, 0, 170);
  rect(0, 0, width, height);

  float boxW = min(480 * UI_TEXT_SCALE, width - 60);
  float boxH = 310 * UI_TEXT_SCALE;
  float boxX = width / 2f - boxW / 2f;
  float boxY = height / 2f - boxH / 2f;
  float pad  = 20 * UI_TEXT_SCALE;
  float cxB  = width / 2f;

  fill(20, 22, 28); stroke(70, 120, 190); strokeWeight(2);
  rect(boxX, boxY, boxW, boxH, 10);

  float y = boxY + 18 * UI_TEXT_SCALE;

  // Title
  textAlign(CENTER, TOP); fill(155); textSize(11 * UI_TEXT_SCALE); noStroke();
  text(editingPaletteIndex >= 0 ? "EDIT PALETTE" : "NEW PALETTE", cxB, y); y += 20 * UI_TEXT_SCALE;
  stroke(40, 45, 58); strokeWeight(1);
  line(boxX + pad, y, boxX + boxW - pad, y); y += 14 * UI_TEXT_SCALE;

  // Name field
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("NAME", boxX + pad, y); y += 13 * UI_TEXT_SCALE;
  float fieldW = boxW - pad * 2;
  float fieldH = 28 * UI_TEXT_SCALE;
  noStroke(); fill(14, 14, 20);
  rect(boxX + pad, y, fieldW, fieldH, 4);
  boolean nameHasContent = newPaletteName.length() > 0;
  stroke(nameHasContent ? color(70, 120, 190) : color(48, 50, 65)); strokeWeight(1.5f); noFill();
  rect(boxX + pad, y, fieldW, fieldH, 4);
  textAlign(LEFT, CENTER); fill(nameHasContent ? 210 : 70); textSize(11 * UI_TEXT_SCALE); noStroke();
  String cursor = (frameCount % 60 < 30) ? "_" : "";
  text((nameHasContent ? newPaletteName : "enter a name") + (nameHasContent ? cursor : ""),
       boxX + pad + 8, y + fieldH / 2f);
  y += fieldH + 14 * UI_TEXT_SCALE;

  // Color rows
  float swatchW = 30 * UI_TEXT_SCALE;
  float swatchH = 22 * UI_TEXT_SCALE;
  float pickW   = boxW - pad * 2 - swatchW - 8 * UI_TEXT_SCALE;

  // Start color
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("START COLOR", boxX + pad, y); y += 13 * UI_TEXT_SCALE;

  pushStyle(); colorMode(HSB, 360, 100, 100);
  fill(newPaletteStartH, newPaletteStartS, newPaletteStartB); noStroke();
  rect(boxX + pad, y, swatchW, swatchH, 3);
  popStyle();

  btnModalPickStart[0] = boxX + pad + swatchW + 8 * UI_TEXT_SCALE;
  btnModalPickStart[1] = y; btnModalPickStart[2] = pickW; btnModalPickStart[3] = swatchH;
  drawPickColorBtn(btnModalPickStart, colorPickerOpen && colorPickTarget == 0);
  y += swatchH + 10 * UI_TEXT_SCALE;

  // End color
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("END COLOR", boxX + pad, y); y += 13 * UI_TEXT_SCALE;

  pushStyle(); colorMode(HSB, 360, 100, 100);
  fill(newPaletteEndH, newPaletteEndS, newPaletteEndB); noStroke();
  rect(boxX + pad, y, swatchW, swatchH, 3);
  popStyle();

  btnModalPickEnd[0] = boxX + pad + swatchW + 8 * UI_TEXT_SCALE;
  btnModalPickEnd[1] = y; btnModalPickEnd[2] = pickW; btnModalPickEnd[3] = swatchH;
  drawPickColorBtn(btnModalPickEnd, colorPickerOpen && colorPickTarget == 1);
  y += swatchH + 12 * UI_TEXT_SCALE;

  // Preview gradient
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("PREVIEW", boxX + pad, y); y += 12 * UI_TEXT_SCALE;
  float prevH = 12 * UI_TEXT_SCALE;
  int   steps = max(2, (int)((boxW - pad * 2) / 4));
  float sw    = (boxW - pad * 2) / steps;
  pushStyle(); colorMode(HSB, 360, 100, 100); noStroke();
  for (int i = 0; i < steps; i++) {
    float t = (float)i / (steps - 1);
    fill(lerp(newPaletteStartH, newPaletteEndH, t),
         lerp(newPaletteStartS, newPaletteEndS, t),
         lerp(newPaletteStartB, newPaletteEndB, t));
    rect(boxX + pad + i * sw, y, sw + 0.5f, prevH);
  }
  popStyle();
  y += prevH + 16 * UI_TEXT_SCALE;

  // Create / Cancel
  float bW2 = (boxW - pad * 2 - 8) / 2f;
  float bH  = 28 * UI_TEXT_SCALE;
  boolean canCreate = newPaletteName.trim().length() > 0;

  btnModalCreate[0] = boxX + pad; btnModalCreate[1] = y;
  btnModalCreate[2] = bW2; btnModalCreate[3] = bH;
  boolean crHov = canCreate && mouseInRect(btnModalCreate);
  noStroke(); fill(canCreate ? (crHov ? color(28, 65, 42) : color(20, 50, 32)) : color(18, 25, 22));
  rect(btnModalCreate[0], y, bW2, bH, 4);
  stroke(canCreate ? (crHov ? color(100, 255, 150) : color(55, 120, 75)) : color(32, 42, 35));
  strokeWeight(1.5f); noFill();
  rect(btnModalCreate[0], y, bW2, bH, 4);
  textAlign(CENTER, CENTER); fill(canCreate ? (crHov ? 255 : 175) : 50);
  textSize(10 * UI_TEXT_SCALE); noStroke();
  text(editingPaletteIndex >= 0 ? "[ Update ]" : "[ Create ]", btnModalCreate[0] + bW2 / 2, y + bH / 2);
  if (crHov) wantedCursor = HAND;

  btnModalCancel[0] = boxX + pad + bW2 + 8; btnModalCancel[1] = y;
  btnModalCancel[2] = bW2; btnModalCancel[3] = bH;
  boolean caHov = mouseInRect(btnModalCancel);
  noStroke(); fill(caHov ? color(50, 20, 22) : color(28, 18, 20));
  rect(btnModalCancel[0], y, bW2, bH, 4);
  stroke(caHov ? color(255, 80, 80) : color(90, 38, 45)); strokeWeight(1); noFill();
  rect(btnModalCancel[0], y, bW2, bH, 4);
  textAlign(CENTER, CENTER); fill(caHov ? color(255, 100, 100) : color(135, 60, 65));
  textSize(10 * UI_TEXT_SCALE); noStroke();
  text("[ Cancel ]", btnModalCancel[0] + bW2 / 2, y + bH / 2);
  if (caHov) wantedCursor = HAND;
}

void drawPickColorBtn(float[] r, boolean picking) {
  boolean hov = !colorPickerOpen && mouseInRect(r);
  noStroke(); fill(hov ? color(28, 45, 70) : color(20, 30, 45));
  rect(r[0], r[1], r[2], r[3], 4);
  stroke(hov ? color(80, 140, 210) : (picking ? color(90, 130, 200) : color(45, 70, 110)));
  strokeWeight(1.5f); noFill();
  rect(r[0], r[1], r[2], r[3], 4);
  textAlign(CENTER, CENTER);
  fill(picking ? color(100, 140, 210) : (hov ? 230 : 155));
  textSize(9 * UI_TEXT_SCALE); noStroke();
  text(picking ? "Picking..." : "Pick Color...", r[0] + r[2] / 2, r[1] + r[3] / 2);
  if (hov) wantedCursor = HAND;
}

void openColorPicker(int target) {
  if (colorPickerOpen) return;
  colorPickerOpen  = true;
  colorPickTarget  = target;
  final int   tgt = target;
  final float ih  = (tgt == 0) ? newPaletteStartH : newPaletteEndH;
  final float is2 = (tgt == 0) ? newPaletteStartS : newPaletteEndS;
  final float ib  = (tgt == 0) ? newPaletteStartB : newPaletteEndB;
  javax.swing.SwingUtilities.invokeLater(new Runnable() {
    public void run() {
      java.awt.Color init = java.awt.Color.getHSBColor(ih / 360f, is2 / 100f, ib / 100f);
      java.awt.Color chosen = javax.swing.JColorChooser.showDialog(
        null, tgt == 0 ? "Start Color" : "End Color", init);
      if (chosen != null) {
        float[] hsb = new float[3];
        java.awt.Color.RGBtoHSB(chosen.getRed(), chosen.getGreen(), chosen.getBlue(), hsb);
        pendingPickedH     = hsb[0] * 360f;
        pendingPickedS     = hsb[1] * 100f;
        pendingPickedB     = hsb[2] * 100f;
        pendingPickedColor = tgt;
      }
      colorPickerOpen = false;
    }
  });
}

void commitNewPalette() {
  String trimmed = newPaletteName.trim();
  if (trimmed.length() == 0) return;
  newPaletteModalOpen = false;
  newPaletteName      = "";
  if (editingPaletteIndex >= 0 && editingPaletteIndex < customPalettes.size()) {
    CustomPalette cp = customPalettes.get(editingPaletteIndex);
    cp.name   = trimmed;
    cp.startH = newPaletteStartH; cp.startS = newPaletteStartS; cp.startB = newPaletteStartB;
    cp.endH   = newPaletteEndH;   cp.endS   = newPaletteEndS;   cp.endB   = newPaletteEndB;
    editingPaletteIndex = -1;
    saveConfig();
    notify("Palette updated: " + cp.name, 90, NOTIF_SUCCESS);
  } else {
    editingPaletteIndex = -1;
    CustomPalette cp = new CustomPalette();
    cp.name   = trimmed;
    cp.startH = newPaletteStartH; cp.startS = newPaletteStartS; cp.startB = newPaletteStartB;
    cp.endH   = newPaletteEndH;   cp.endS   = newPaletteEndS;   cp.endB   = newPaletteEndB;
    customPalettes.add(cp);
    currentPalette  = BUILTIN_PALETTE_COUNT + customPalettes.size() - 1;
    paletteReversed = false;
    saveConfig();
    notify("Palette created: " + cp.name, 90, NOTIF_SUCCESS);
  }
}

void openBgColorPicker() {
  if (bgPickerOpen) return;
  bgPickerOpen = true;
  final float ih = bgColorH, is2 = bgColorS, ib = bgColorB;
  javax.swing.SwingUtilities.invokeLater(new Runnable() {
    public void run() {
      java.awt.Color init = java.awt.Color.getHSBColor(ih / 360f, is2 / 100f, ib / 100f);
      java.awt.Color chosen = javax.swing.JColorChooser.showDialog(null, "Background Color", init);
      if (chosen != null) {
        float[] hsb = new float[3];
        java.awt.Color.RGBtoHSB(chosen.getRed(), chosen.getGreen(), chosen.getBlue(), hsb);
        pendingBgH     = hsb[0] * 360f;
        pendingBgS     = hsb[1] * 100f;
        pendingBgB     = hsb[2] * 100f;
        pendingBgReady = true;
      }
      bgPickerOpen = false;
    }
  });
}

void drawGifUncapToggle(float px, float pw, float y) {
  float pad = 14;
  btnGifUncap[0] = px+pad; btnGifUncap[1] = y; btnGifUncap[2] = pw-pad*2; btnGifUncap[3] = 26*UI_TEXT_SCALE;
  boolean uHov = mouseInRect(btnGifUncap);
  noStroke(); fill(gifUncapped ? color(65,42,12) : color(22,22,28));
  if (uHov) fill(gifUncapped ? color(78,52,16) : color(28,28,35));
  rect(btnGifUncap[0], y, btnGifUncap[2], btnGifUncap[3], 4);
  stroke(gifUncapped ? color(255,165,40) : color(60,60,70)); strokeWeight(1.5f); noFill();
  rect(btnGifUncap[0], y, btnGifUncap[2], btnGifUncap[3], 4);
  textAlign(CENTER, CENTER); fill(gifUncapped ? color(255,165,40) : color(140)); textSize(10*UI_TEXT_SCALE); noStroke();
  text("GIF uncapped: " + (gifUncapped ? "ON  (!)" : "OFF"), px+pad+(pw-pad*2)/2, y+btnGifUncap[3]/2);
  if (uHov) wantedCursor = HAND;
  if (gifUncapped) {
    textAlign(CENTER, TOP); fill(200,120,35); textSize(7*UI_TEXT_SCALE); noStroke();
    text("60 fps, no frame floor - may produce very large files", px+pad+(pw-pad*2)/2, y+btnGifUncap[3]+3);
  }
}


// panel 5 - about
void drawPanel5(float px, float pw) {
  float pad = 14;
  float y   = 18 * UI_TEXT_SCALE;
  float cxP = px + pw / 2f;

  textAlign(CENTER, TOP); fill(160); textSize(10 * UI_TEXT_SCALE); noStroke();
  text("ABOUT", cxP, y); y += 18 * UI_TEXT_SCALE;
  stroke(40, 40, 50); strokeWeight(1);
  line(px + pad, y, px + pw - pad, y); y += 10 * UI_TEXT_SCALE;

  // Diagnostics
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("DIAGNOSTICS", px + pad, y); y += 13 * UI_TEXT_SCALE;

  long totMB = Runtime.getRuntime().totalMemory() >> 20;
  long freMB = Runtime.getRuntime().freeMemory()  >> 20;
  long maxMB = Runtime.getRuntime().maxMemory()   >> 20;
  int  lim   = (int)((pw - pad * 2) / (7 * UI_TEXT_SCALE));

  String[][] rows = {
    {"Java",    System.getProperty("java.version")},
    {"Vendor",  System.getProperty("java.vendor")},
    {"Home",    tail(System.getProperty("java.home"), lim)},
    {"OS",      System.getProperty("os.name") + " " + System.getProperty("os.arch")},
    {"Config",  tail(configPath(), lim)},
    {"Exports", tail(exportsDir(), lim)},
    {"Memory",  (totMB - freMB) + " / " + maxMB + " MB"},
  };
  fill(125); textSize(8 * UI_TEXT_SCALE);
  for (String[] row : rows) {
    fill(80); text(row[0] + ": ", px + pad, y);
    fill(145); text(row[1], px + pad + textWidth(row[0] + ": "), y);
    y += 11 * UI_TEXT_SCALE;
  }
  y += 6 * UI_TEXT_SCALE;

  // Reset config
  stroke(40, 40, 50); strokeWeight(1);
  line(px + pad, y, px + pw - pad, y); y += 10 * UI_TEXT_SCALE;
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("SETTINGS", px + pad, y); y += 13 * UI_TEXT_SCALE;
  fill(75); textSize(7 * UI_TEXT_SCALE);
  text("Resets render settings, palettes and presets", px + pad, y); y += 10 * UI_TEXT_SCALE;
  text("to factory defaults.", px + pad, y); y += 12 * UI_TEXT_SCALE;
  btnResetConfig[0] = px+pad; btnResetConfig[1] = y; btnResetConfig[2] = pw-pad*2; btnResetConfig[3] = 26*UI_TEXT_SCALE;
  boolean rsHov = mouseInRect(btnResetConfig);
  noStroke(); fill(rsHov ? color(55,35,12) : color(36,22,8));
  rect(btnResetConfig[0], y, btnResetConfig[2], btnResetConfig[3], 4);
  stroke(rsHov ? color(230,140,45) : color(110,68,22)); strokeWeight(1.5f); noFill();
  rect(btnResetConfig[0], y, btnResetConfig[2], btnResetConfig[3], 4);
  textAlign(CENTER, CENTER); fill(rsHov ? color(245,160,70) : color(160,95,35));
  textSize(10*UI_TEXT_SCALE); noStroke();
  text("Reset Config to Defaults", cxP, y + btnResetConfig[3]/2);
  if (rsHov) wantedCursor = HAND;
  y += 26*UI_TEXT_SCALE + 14*UI_TEXT_SCALE;

  // Cleanup & exit
  stroke(40, 40, 50); strokeWeight(1);
  line(px + pad, y, px + pw - pad, y); y += 10 * UI_TEXT_SCALE;
  fill(100); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("CLEANUP", px + pad, y); y += 13 * UI_TEXT_SCALE;
  fill(75); textSize(7 * UI_TEXT_SCALE);
  text("Deletes exports/  config.json", px + pad, y); y += 10 * UI_TEXT_SCALE;
  text("and hex_spells.txt, then exits.", px + pad, y); y += 12 * UI_TEXT_SCALE;
  btnCleanupOpen[0] = px+pad; btnCleanupOpen[1] = y; btnCleanupOpen[2] = pw-pad*2; btnCleanupOpen[3] = 26*UI_TEXT_SCALE;
  boolean clHov = mouseInRect(btnCleanupOpen);
  noStroke(); fill(clHov ? color(70,18,20) : color(45,12,14));
  rect(btnCleanupOpen[0], y, btnCleanupOpen[2], btnCleanupOpen[3], 4);
  stroke(clHov ? color(255,75,80) : color(140,38,42)); strokeWeight(1.5f); noFill();
  rect(btnCleanupOpen[0], y, btnCleanupOpen[2], btnCleanupOpen[3], 4);
  textAlign(CENTER, CENTER); fill(clHov ? color(255,110,115) : color(200,68,72));
  textSize(10*UI_TEXT_SCALE); noStroke();
  text("Delete All Files & Exit", cxP, y + btnCleanupOpen[3]/2);
  if (clHov) wantedCursor = HAND;
}

String tail(String s, int maxChars) {
  if (s == null) return "?";
  if (s.length() <= maxChars) return s;
  return ".." + s.substring(s.length() - maxChars + 2);
}

// Cleanup confirm modal
void drawCleanupConfirmModal() {
  noStroke(); fill(0, 0, 0, 200); rect(0, 0, width, height);
  float boxW = min(420 * UI_TEXT_SCALE, width - 60);
  float boxH = 215 * UI_TEXT_SCALE;
  float boxX = width/2f - boxW/2f, boxY = height/2f - boxH/2f;
  float pad  = 20 * UI_TEXT_SCALE, cxB = width/2f;
  fill(28, 12, 14); stroke(210, 55, 60); strokeWeight(2);
  rect(boxX, boxY, boxW, boxH, 10);
  float y = boxY + 18 * UI_TEXT_SCALE;
  textAlign(CENTER, TOP); fill(225, 75, 80); textSize(12 * UI_TEXT_SCALE); noStroke();
  text("DELETE ALL FILES?", cxB, y); y += 22 * UI_TEXT_SCALE;
  stroke(80, 28, 32); strokeWeight(1); line(boxX+pad, y, boxX+boxW-pad, y); y += 12 * UI_TEXT_SCALE;
  fill(165); textSize(9 * UI_TEXT_SCALE); textAlign(LEFT, TOP); noStroke();
  text("This permanently removes:", boxX+pad, y); y += 13 * UI_TEXT_SCALE;
  fill(120); textSize(8 * UI_TEXT_SCALE);
  text("  exports/   config.json   hex_spells.txt", boxX+pad, y); y += 14 * UI_TEXT_SCALE;
  fill(210, 65, 70); textSize(8 * UI_TEXT_SCALE);
  text("The application closes afterwards. Cannot be undone.", boxX+pad, y); y += 20 * UI_TEXT_SCALE;
  float bW = (boxW - pad*2 - 8) / 2f, bH = 28 * UI_TEXT_SCALE;
  btnCleanupDo[0]=boxX+pad;      btnCleanupDo[1]=y; btnCleanupDo[2]=bW; btnCleanupDo[3]=bH;
  btnCleanupNo[0]=boxX+pad+bW+8; btnCleanupNo[1]=y; btnCleanupNo[2]=bW; btnCleanupNo[3]=bH;
  boolean doH = mouseInRect(btnCleanupDo), noH = mouseInRect(btnCleanupNo);
  noStroke(); fill(doH ? color(90,18,20) : color(62,12,14));
  rect(btnCleanupDo[0], y, bW, bH, 4);
  stroke(doH ? color(255,80,85) : color(180,42,48)); strokeWeight(1.5f); noFill();
  rect(btnCleanupDo[0], y, bW, bH, 4);
  textAlign(CENTER, CENTER); fill(doH ? color(255,115,120) : color(210,75,80));
  textSize(10*UI_TEXT_SCALE); noStroke(); text("Delete & Exit", btnCleanupDo[0]+bW/2, y+bH/2);
  if (doH) wantedCursor = HAND;
  noStroke(); fill(noH ? color(28,35,44) : color(20,24,30));
  rect(btnCleanupNo[0], y, bW, bH, 4);
  stroke(noH ? color(100,130,170) : color(52,65,82)); strokeWeight(1); noFill();
  rect(btnCleanupNo[0], y, bW, bH, 4);
  textAlign(CENTER, CENTER); fill(noH ? 205 : 130);
  textSize(10*UI_TEXT_SCALE); noStroke(); text("Cancel", btnCleanupNo[0]+bW/2, y+bH/2);
  if (noH) wantedCursor = HAND;
}

// goto overlay
void drawGotoOverlay(int totalCount) {
  noStroke(); fill(0, 0, 0, 170);
  rect(0, 0, width, height);

  float boxW = 420 * UI_TEXT_SCALE;
  float boxH = 160 * UI_TEXT_SCALE;
  float boxX = width / 2f - boxW / 2f;
  float boxY = height / 2f - boxH / 2f;

  fill(20, 25, 30); stroke(100, 255, 150); strokeWeight(2);
  rect(boxX, boxY, boxW, boxH, 10);

  textAlign(CENTER, CENTER); fill(100, 255, 150); textSize(16 * UI_TEXT_SCALE);
  text("GO TO PATTERN INDEX", width / 2f, boxY + 28 * UI_TEXT_SCALE);
  fill(160); textSize(11 * UI_TEXT_SCALE);
  text("Range: 1 to " + String.format("%,d", totalCount), width / 2f, boxY + 50 * UI_TEXT_SCALE);

  float fW  = boxW - 60 * UI_TEXT_SCALE;
  float fH  = 36 * UI_TEXT_SCALE;
  float fX  = width / 2f - fW / 2f;
  float fY  = boxY + 70 * UI_TEXT_SCALE;

  fill(13, 13, 18); stroke(100, 255, 150, 150); strokeWeight(1.5f);
  rect(fX, fY, fW, fH, 6);
  fill(100, 255, 150); textSize(18 * UI_TEXT_SCALE); textAlign(LEFT, CENTER);
  String shown = gotoInputBuffer + (frameCount % 60 < 30 ? "_" : "");
  text(shown, fX + 12, fY + fH / 2f - 2);

  fill(120); textSize(10 * UI_TEXT_SCALE); textAlign(CENTER, CENTER);
  text("[ENTER] confirm   |   [ESC] cancel", width / 2f, boxY + boxH - 18 * UI_TEXT_SCALE);
}

// helpers
String formatIndex(int current, int total) {
  return current + " / " + formatTotal(total);
}

String formatTotal(int total) {
  if (total >= 1000000) return nf(total / 1000000f, 1, 1) + "M";
  if (total >= 10000)   return nf(total / 1000f, 1, 1) + "k";
  return String.format("%,d", total);
}

void drawPanelBtn(float bx, float by, float bw, float bh, String label, boolean enabled) {
  boolean hovered = enabled && mouseInRect(bx, by, bw, bh);
  noStroke();
  if (!enabled) fill(18, 18, 23);
  else if (hovered) fill(32, 48, 38);
  else fill(22, 26, 30);
  rect(bx, by, bw, bh, 4);
  stroke(enabled ? (hovered ? color(100, 255, 150) : color(55, 60, 68)) : color(35, 35, 40));
  strokeWeight(1); noFill();
  rect(bx, by, bw, bh, 4);
  textAlign(CENTER, CENTER);
  fill(enabled ? (hovered ? 255 : 160) : 50);
  textSize(9 * UI_TEXT_SCALE); noStroke();
  text(label, bx + bw/2, by + bh/2);
  if (hovered) wantedCursor = HAND;
}

boolean mouseInRect(float[] r) {
  return mouseX >= r[0] && mouseX <= r[0]+r[2] && mouseY >= r[1] && mouseY <= r[1]+r[3];
}

boolean mouseInRect(float bx, float by, float bw, float bh) {
  return mouseX >= bx && mouseX <= bx+bw && mouseY >= by && mouseY <= by+bh;
}
