
// input - event, paste/copy, helpers
boolean isModifierForShortcut() {
  return keyEvent != null && (keyEvent.isControlDown() || keyEvent.isMetaDown());
}

// mouse
void mousePressed() {
  if (cleanupConfirmOpen)  { handleCleanupConfirmMouse(); return; }
  if (presetModalOpen)     { handlePresetModalMouse(); return; }
  if (newPaletteModalOpen) { handleNewPaletteModalMouse(); return; }

  if (mouseButton == RIGHT && openPanel == 2 && panelSlide > 0.5f
      && paletteListArea[2] > 0 && mouseInRect(paletteListArea)) {
    handlePanel2PaletteRightClick();
    return;
  }

  if (currentState == AppState.ERROR) { returnToPlayground(); return; }
  if (mouseButton == RIGHT && currentState != AppState.PLAYGROUND) { returnToPlayground(); return; }

  if (currentState == AppState.PLAYGROUND || currentState == AppState.CALCULATING) {
    if (mouseButton == RIGHT) {
      drawPanning    = true;
      drawPanStartMX = mouseX; drawPanStartMY = mouseY;
      drawPanStartVX = drawViewX; drawPanStartVY = drawViewY;
      return;
    }
    if (mouseButton != LEFT) return;

    float panelW = width * panelSlide * PANEL_WIDTH_FRAC;
    float panelX = width - panelW;
    if (panelSlide > 0.5f && mouseX >= panelX) {
      if      (openPanel == 1) handlePlaygroundPanel1Mouse(panelX, panelW);
      else if (openPanel == 2) handlePanel2Mouse();
      else if (openPanel == 3) handlePanel3Mouse();
      else if (openPanel == 4) handlePlaygroundPanel4Mouse();
      else if (openPanel == 5) handlePanel5Mouse();
      return;
    }

    if (mouseX < panelX) handleDrawMousePressed();
    return;
  }

  if (currentState == AppState.GALLERY && mouseButton == LEFT && !gotoInputActive) {
    float panelW = width * panelSlide * PANEL_WIDTH_FRAC;
    float panelX = width - panelW;

    if (panelSlide > 0.5f && mouseX >= panelX) {
      if (openPanel == 1) handlePanel1Mouse(panelX, panelW);
      else if (openPanel == 2) handlePanel2Mouse();
      else if (openPanel == 3) handlePanel3Mouse();
      else if (openPanel == 4) handlePanel4Mouse();
      else if (openPanel == 5) handlePanel5Mouse();
      return;
    }

    int currentAvailableSize;
    synchronized(totalGallery) { currentAvailableSize = totalGallery.size(); }
    if (currentAvailableSize <= 1) return;
  }
}

void handlePanel1Mouse(float panelX, float panelW) {
  int sz;
  synchronized(totalGallery) { sz = totalGallery.size(); }
  if (sz <= 0) return;

  float[] bar = panelScrubBar;
  if (bar[2] > 0 && mouseInRect(bar[0], bar[1] - 4, bar[2], bar[3] + 8)) {
    scrubberDragging = true;
    updatePanelScrubber(sz);
    return;
  }

  // nav buttons
  float pad  = 14;
  float btnH = 26 * UI_TEXT_SCALE;
  float gap  = 5;
  float bW2  = (panelW - pad * 2 - gap) / 2f;
  float bW3  = (panelW - pad * 2 - gap * 2) / 3f;
  float y    = 18 * UI_TEXT_SCALE + 18 * UI_TEXT_SCALE + 12 * UI_TEXT_SCALE + 10 * UI_TEXT_SCALE + 14 * UI_TEXT_SCALE + 18 * UI_TEXT_SCALE;

  if (mouseInRect(panelX + pad, y, bW2, btnH)) { galleryIndex = 0; resetAnimation(); return; }
  if (mouseInRect(panelX + pad + bW2 + gap, y, bW2, btnH)) { galleryIndex = sz - 1; resetAnimation(); return; }
  y += btnH + gap;

  if (mouseInRect(panelX + pad, y, bW3, btnH))                    { galleryIndex = clampIndex(galleryIndex - 100, sz); resetAnimation(); return; }
  if (mouseInRect(panelX + pad + bW3 + gap, y, bW3, btnH))        { galleryIndex = clampIndex(galleryIndex - 10,  sz); resetAnimation(); return; }
  if (mouseInRect(panelX + pad + (bW3 + gap)*2, y, bW3, btnH))    { galleryIndex = clampIndex(galleryIndex - 1,   sz); resetAnimation(); return; }
  y += btnH + gap;

  if (mouseInRect(panelX + pad, y, bW3, btnH))                    { galleryIndex = clampIndex(galleryIndex + 1,   sz); resetAnimation(); return; }
  if (mouseInRect(panelX + pad + bW3 + gap, y, bW3, btnH))        { galleryIndex = clampIndex(galleryIndex + 10,  sz); resetAnimation(); return; }
  if (mouseInRect(panelX + pad + (bW3 + gap)*2, y, bW3, btnH))    { galleryIndex = clampIndex(galleryIndex + 100, sz); resetAnimation(); return; }
  y += btnH + gap;

  if (mouseInRect(panelX + pad, y, panelW - pad * 2, btnH) && sz > 1) {
    int newIdx; do { newIdx = (int)random(sz); } while (newIdx == galleryIndex);
    galleryIndex = newIdx; resetAnimation(); return;
  }
}

// Panel 2 - color
void handlePanel2Mouse() {
  // New palette button
  if (mouseInRect(btnNewPalette)) {
    newPaletteModalOpen = true;
    editingPaletteIndex = -1;
    newPaletteName      = "";
    newPaletteStartH = 220; newPaletteStartS = 90; newPaletteStartB = 100;
    newPaletteEndH   =   0; newPaletteEndS   = 90; newPaletteEndB   = 100;
    return;
  }

  // Palette list rows
  if (mouseInRect(paletteListArea) && paletteListArea[2] > 0) {
    float rowH   = 28 * UI_TEXT_SCALE;
    float nameH  = 14 * UI_TEXT_SCALE;
    float delW   = 20 * UI_TEXT_SCALE;
    int   totalP = BUILTIN_PALETTE_COUNT + customPalettes.size();
    int   row    = (int)((mouseY - paletteListArea[1] + paletteListScrollY) / rowH);
    if (row >= 0 && row < totalP) {
      // Delete button (custom palettes only, only when row is fully in view)
      if (row >= BUILTIN_PALETTE_COUNT) {
        float rowScreenY = paletteListArea[1] + row * rowH - paletteListScrollY;
        if (rowScreenY >= paletteListArea[1] && rowScreenY + rowH <= paletteListArea[1] + paletteListArea[3]) {
          float delX = paletteListArea[0] + paletteListArea[2] - delW;
          if (mouseInRect(delX + 2, rowScreenY + 2, delW - 4, nameH - 4)) {
            int ci = row - BUILTIN_PALETTE_COUNT;
            if (ci < customPalettes.size()) {
              if (currentPalette == row)       { currentPalette = 0; paletteReversed = false; }
              else if (currentPalette > row)   currentPalette--;
              customPalettes.remove(ci);
              float newContentH = (BUILTIN_PALETTE_COUNT + customPalettes.size()) * rowH;
              paletteListScrollY = constrain(paletteListScrollY, 0, max(0, newContentH - paletteListArea[3]));
              saveConfig();
              notify("Palette deleted", 60, NOTIF_INFO);
              return;
            }
          }
        }
      }
      // Select or reverse
      if (row == currentPalette) paletteReversed = !paletteReversed;
      else { currentPalette = row; paletteReversed = false; }
      resetAnimation(); saveConfig();
    }
    return;
  }

  // Background toggle / color picker
  if (mouseInRect(btnBgToggle)) { showBackground = !showBackground; saveConfig(); return; }
  if (showBackground && !bgPickerOpen && mouseInRect(btnBgPick)) { openBgColorPicker(); return; }

  // Gradient cycle slider
  if (mouseInRect(gradientSliderBar)) {
    float frac = constrain((mouseX - gradientSliderBar[0]) / gradientSliderBar[2], 0f, 1f);
    gradientCycle = frac * 5f; sliderDragging = DRAG_GRADIENT; return;
  }
}

// panel 3 - render
void handlePanel3Mouse() {
  // Rotation buttons
  if (mouseInRect(btnRotMinus)) {
    currentPatternStartDir = ((currentPatternStartDir - 1) % 6 + 6) % 6;
    syncSigToPath(false); saveConfig(); return;
  }
  if (mouseInRect(btnRotPlus)) {
    currentPatternStartDir = (currentPatternStartDir + 1) % 6;
    syncSigToPath(false); saveConfig(); return;
  }
  if (mouseInRect(btnArcToggle))     { arcMode = !arcMode; resetAnimation(); saveConfig(); return; }
  if (mouseInRect(btnGridToggle))    { gridDotsMode = !gridDotsMode; saveConfig(); return; }
  if (mouseInRect(btnMarkersToggle)) { showExportMarkers = !showExportMarkers; saveConfig(); return; }
  if (mouseInRect(traceSliderBar)) {
    float frac = constrain((mouseX - traceSliderBar[0]) / traceSliderBar[2], 0f, 1f);
    traceSpeed = 0.04f * pow(3.0f / 0.04f, frac); sliderDragging = DRAG_TRACE; return;
  }
  if (mouseInRect(pulseSliderBar)) {
    float frac = constrain((mouseX - pulseSliderBar[0]) / pulseSliderBar[2], 0f, 1f);
    pulseSpeed = 0.003f * pow(0.25f / 0.003f, frac); sliderDragging = DRAG_PULSE; return;
  }
  if (mouseInRect(strokeSliderBar)) {
    float frac = constrain((mouseX - strokeSliderBar[0]) / strokeSliderBar[2], 0f, 1f);
    strokeWidthBase = 1f + frac * 11f; sliderDragging = DRAG_STROKE; return;
  }
  if (mouseInRect(arcInsetSliderBar)) {
    float frac = constrain((mouseX - arcInsetSliderBar[0]) / arcInsetSliderBar[2], 0f, 1f);
    arcInset = 0.05f + frac * 0.60f; sliderDragging = DRAG_ARC_INSET; return;
  }
}

// panel 4 - export
void handlePanel4Mouse() {
  if (mouseInRect(btnCopySig))    { copySignature();    return; }
  if (mouseInRect(btnCopyImg))    { exportImage();      return; }
  if (mouseInRect(btnExportGIF))  { exportCurrentGIF(); return; }
  if (mouseInRect(btnGifUncap))   { gifUncapped = !gifUncapped; saveConfig(); return; }
  if (mouseInRect(btnOpenFolder)) { openExportsFolder(); return; }
}

void handlePanel5Mouse() {
  if (mouseInRect(btnResetConfig)) { resetConfig(); return; }
  if (mouseInRect(btnCleanupOpen)) { cleanupConfirmOpen = true; return; }
}

byte[] currentPathBytes() {
  if (currentState == AppState.GALLERY) {
    synchronized(totalGallery) {
      if (totalGallery.isEmpty() || galleryIndex < 0 || galleryIndex >= totalGallery.size()) return new byte[0];
      return totalGallery.get(galleryIndex);
    }
  }
  return sigToBytes(customSignature);
}

void exportImage() {
  byte[] path = currentPathBytes();
  if (path.length == 0) { notify("Nothing to export - pattern is empty", 90, NOTIF_WARN); return; }
  exportPatternCanvas(path, -1.0f);
  notify("Image saved + copied to clipboard", 120, NOTIF_SUCCESS);
}

void exportCurrentGIF() {
  exportGIF(currentPathBytes(), galleryIndex);
}

void copySignature() {
  String sig;
  if (currentState == AppState.GALLERY) {
    byte[] path = currentPathBytes();
    if (path.length == 0) { notify("Nothing to copy", 90, NOTIF_WARN); return; }
    sig = bytesToSignature(path);
  } else {
    if (customSignature.length() == 0) { notify("Nothing to copy", 90, NOTIF_WARN); return; }
    sig = customSignature;
  }
  try {
    StringSelection sel = new StringSelection(sig);
    Toolkit.getDefaultToolkit().getSystemClipboard().setContents(sel, sel);
    notify("Copied to clipboard", 90, NOTIF_SUCCESS);
  } catch (Exception e) { notify("Copy failed", 90, NOTIF_ERROR); }
}

void exportGIF(byte[] activePath, int fileIdx) {
  if (gifExporting) { notify("Export already in progress", 90, NOTIF_WARN); return; }
  int N = activePath.length;
  if (N == 0) { notify("Pattern is empty", 90, NOTIF_WARN); return; }

  boolean usePulse = pulseSpeed > 0.0031f;
  boolean useTrace = !usePulse && traceSpeed < 2.99f;
  if (!usePulse && !useTrace) {
    notify("Nothing to animate - trace is instant and pulse is off", 150, NOTIF_WARN);
    return;
  }

  float speed    = usePulse ? pulseSpeed : traceSpeed;
  float cycleMs  = N * 1000f / (max(0.005f, speed) * 60f);
  int   delayMs  = gifUncapped ? 17 : 50;
  int   frames   = gifUncapped ? max(1, round(cycleMs / delayMs))
                               : max(4, round(cycleMs / delayMs));
  int   holdFrames  = (usePulse || gifUncapped) ? 0 : round(1000f / delayMs);

  gifExportDirs    = activePath;
  gifExportFrames  = frames;
  gifExportTotal   = frames + holdFrames;
  gifExportDelay   = delayMs;
  gifExportIsPulse = usePulse;
  gifExportFrame   = usePulse ? 0 : -1; // -1 = pretrain step needed first
  gifExporting     = true;

  gifRecorderStart();
}

void updatePanelScrubber(int totalCount) {
  float[] bar = panelScrubBar;
  if (bar[2] <= 0) return;
  float frac = constrain((mouseX - bar[0]) / bar[2], 0f, 1f);
  int newIdx = round(frac * (totalCount - 1));
  if (newIdx != galleryIndex) { galleryIndex = newIdx; resetAnimation(); }
}

void mouseDragged() {
  if (drawPanning) {
    float nx = drawPanStartVX + (mouseX - drawPanStartMX);
    float ny = drawPanStartVY + (mouseY - drawPanStartMY);
    drawViewX = drawTargetX = nx;
    drawViewY = drawTargetY = ny;
    return;
  }
  if (currentState == AppState.GALLERY && scrubberDragging) {
    int sz; synchronized(totalGallery) { sz = totalGallery.size(); }
    if (sz > 1) updatePanelScrubber(sz);
  }
  if (sliderDragging == DRAG_TRACE && traceSliderBar[2] > 0) {
    float frac = constrain((mouseX - traceSliderBar[0]) / traceSliderBar[2], 0f, 1f);
    traceSpeed = 0.04f * pow(3.0f / 0.04f, frac);
  }
  if (sliderDragging == DRAG_PULSE && pulseSliderBar[2] > 0) {
    float frac = constrain((mouseX - pulseSliderBar[0]) / pulseSliderBar[2], 0f, 1f);
    pulseSpeed = 0.003f * pow(0.25f / 0.003f, frac);
  }
  if (sliderDragging == DRAG_GRADIENT && gradientSliderBar[2] > 0) {
    float frac = constrain((mouseX - gradientSliderBar[0]) / gradientSliderBar[2], 0f, 1f);
    gradientCycle = frac * 5f;
  }
  if (sliderDragging == DRAG_STROKE && strokeSliderBar[2] > 0) {
    float frac = constrain((mouseX - strokeSliderBar[0]) / strokeSliderBar[2], 0f, 1f);
    strokeWidthBase = 1f + frac * 11f;
  }
  if (sliderDragging == DRAG_ARC_INSET && arcInsetSliderBar[2] > 0) {
    float frac = constrain((mouseX - arcInsetSliderBar[0]) / arcInsetSliderBar[2], 0f, 1f);
    arcInset = 0.05f + frac * 0.60f;
  }
  if ((currentState == AppState.PLAYGROUND || currentState == AppState.CALCULATING)
      && drawDragging) {
    handleDrawMouseDragged();
  }
}

void mouseReleased() {
  if (drawPanning) { drawPanning = false; return; }
  scrubberDragging = false;
  if (sliderDragging != DRAG_NONE) saveConfig();
  sliderDragging = DRAG_NONE;
  if (drawDragging) handleDrawMouseReleased();
}

// keyboard
void keyPressed() {
  if (cleanupConfirmOpen)  { handleCleanupConfirmKey(); return; }
  if (presetModalOpen)     { handlePresetModalKey();    return; }
  if (newPaletteModalOpen) { handleNewPaletteModalKey(); return; }

  if (currentState == AppState.ERROR) {
    if (key == ENTER || key == RETURN || key == BACKSPACE) returnToPlayground();
    else if (key == ESC) { key = 0; returnToPlayground(); }
    return;
  }

  // gallery goto-input captures all keys before shared handling
  if (currentState == AppState.GALLERY && gotoInputActive) { handleGalleryKey(); return; }

  if (handleSharedKey()) return;

  if (currentState == AppState.PLAYGROUND || currentState == AppState.CALCULATING) {
    handlePlaygroundKey();
  } else if (currentState == AppState.GALLERY) {
    handleGalleryKey();
  }
}

boolean handleSharedKey() {
  if (key == '1') { openPanel = (openPanel == 1) ? 0 : 1; return true; }
  if (key == '2') { openPanel = (openPanel == 2) ? 0 : 2; return true; }
  if (key == '3') { openPanel = (openPanel == 3) ? 0 : 3; return true; }
  if (key == '4') { openPanel = (openPanel == 4) ? 0 : 4; return true; }
  if (key == '5') { openPanel = (openPanel == 5) ? 0 : 5; return true; }

  char lc = Character.toLowerCase(key);
  boolean shiftHeld = keyEvent != null && keyEvent.isShiftDown();

  if (lc == 'h' && !isModifierForShortcut()) {
    arcMode = !arcMode; resetAnimation(); saveConfig();
    notify("Arc mode " + (arcMode ? "ON" : "OFF"), 90, NOTIF_INFO); return true;
  }
  if (lc == 'g' && !isModifierForShortcut()) {
    gridDotsMode = !gridDotsMode; saveConfig();
    notify("Grid dots " + (gridDotsMode ? "ON" : "OFF"), 90, NOTIF_INFO); return true;
  }
  if (lc == 'p' && !isModifierForShortcut() && shiftHeld) {
    paletteReversed = !paletteReversed; saveConfig(); return true;
  }
  if (lc == 'p' && !isModifierForShortcut() && !shiftHeld) {
    currentPalette = (currentPalette + 1) % (BUILTIN_PALETTE_COUNT + customPalettes.size());
    saveConfig(); return true;
  }
  if (lc == 't' && !isModifierForShortcut()) {
    int delta = shiftHeld ? -1 : 1;
    currentPatternStartDir = ((currentPatternStartDir + delta) % 6 + 6) % 6;
    syncSigToPath(false); return true;
  }
  if (lc == 'i' && !isModifierForShortcut()) { exportImage();      return true; }
  if (lc == 'j' && !isModifierForShortcut()) { exportCurrentGIF(); return true; }
  if (lc == 'c' && !isModifierForShortcut() && shiftHeld)  { copyInlineFormat(); return true; }
  if (lc == 'c' && !isModifierForShortcut() && !shiftHeld) { copySignature();    return true; }

  return false;
}

void handleTypeKey() {
  if (isModifierForShortcut() && (key == 'v' || key == 'V' || key == 22)) {
    pasteIntoCustomSignature(); return;
  }
  if (key == BACKSPACE && isModifierForShortcut()) {
    customSignature = ""; cursorPos = 0; inputScrollX = 0;
    notify("Cleared input"); return;
  }
  if (key == CODED) {
    if (keyCode == LEFT)  { cursorPos = max(0, cursorPos - 1); return; }
    if (keyCode == RIGHT) { cursorPos = min(customSignature.length(), cursorPos + 1); return; }
    if (keyCode == java.awt.event.KeyEvent.VK_HOME) { cursorPos = 0; return; }
    if (keyCode == java.awt.event.KeyEvent.VK_END)  { cursorPos = customSignature.length(); return; }
    if (keyCode == java.awt.event.KeyEvent.VK_DELETE) {
      if (cursorPos < customSignature.length())
        customSignature = customSignature.substring(0, cursorPos) + customSignature.substring(cursorPos + 1);
      return;
    }
    return;
  }
  if (key == BACKSPACE) {
    if (cursorPos > 0) {
      customSignature = customSignature.substring(0, cursorPos - 1) + customSignature.substring(cursorPos);
      cursorPos--;
    }
    return;
  }
  if (key == DELETE) {
    if (cursorPos < customSignature.length())
      customSignature = customSignature.substring(0, cursorPos) + customSignature.substring(cursorPos + 1);
    return;
  }
  char c = Character.toLowerCase(key);
  if (c == 'a' || c == 'q' || c == 'w' || c == 'e' || c == 'd') {
    customSignature = customSignature.substring(0, cursorPos) + c + customSignature.substring(cursorPos);
    cursorPos++;
  }
}

void handlePlaygroundKey() {
  if (key == ESC) {
    if (openPanel > 0) { openPanel = 0; key = 0; } else { key = 0; }
    return;
  }
  if (key == '\t') { key = 0; centerDrawViewOnPath(); return; }

  char lc = Character.toLowerCase(key);
  if (lc == 's' && !isModifierForShortcut()) { triggerSolve(); return; }
  if (isModifierForShortcut() && key == BACKSPACE) { clearPlayground(); return; }

  // Type keys always active; sync drawPath after each change (valid prefix only).
  handleTypeKey();
  {
    int inv = firstInvalidIndex(customSignature);
    String validSig = (inv == 0) ? "" : (inv > 0) ? customSignature.substring(0, inv) : customSignature;
    if (!loadSigToDrawPath(validSig)) {
      drawPath.clear(); drawUsedEdges.clear();
      drawStartAxial[0] = 0; drawStartAxial[1] = 0;
      drawEndAxial[0]   = 0; drawEndAxial[1]   = 0;
    }
  }
  // If either endpoint went off-screen while typing, smoothly recenter.
  float areaW  = width - width * panelSlide * PANEL_WIDTH_FRAC;
  float margin = 40f;
  float[] sp   = axialToScreen(drawStartAxial[0], drawStartAxial[1]);
  float[] ep   = axialToScreen(drawEndAxial[0],   drawEndAxial[1]);
  boolean sOk  = sp[0] > margin && sp[0] < areaW - margin && sp[1] > margin && sp[1] < height - margin;
  boolean eOk  = ep[0] > margin && ep[0] < areaW - margin && ep[1] > margin && ep[1] < height - margin;
  if (!sOk || !eOk) centerDrawViewOnPath(false);
}

void handleGalleryKey() {
  int currentAvailableSize;
  synchronized(totalGallery) { currentAvailableSize = totalGallery.size(); }

  if (gotoInputActive) {
    if (key == ENTER || key == RETURN) {
      if (gotoInputBuffer.length() > 0 && currentAvailableSize > 0) {
        try {
          long parsed = Long.parseLong(gotoInputBuffer);
          int target = (int) Math.min(Math.max(parsed - 1, 0L), (long)(currentAvailableSize - 1));
          galleryIndex = target;
          resetAnimation();
        } catch (NumberFormatException e) { /* ignore */ }
      }
      gotoInputActive = false;
      gotoInputBuffer = "";
    } else if (key == ESC) {
      gotoInputActive = false; gotoInputBuffer = ""; key = 0;
    } else if (key == BACKSPACE) {
      if (gotoInputBuffer.length() > 0)
        gotoInputBuffer = gotoInputBuffer.substring(0, gotoInputBuffer.length() - 1);
    } else if (key >= '0' && key <= '9') {
      if (gotoInputBuffer.length() < 12) gotoInputBuffer += key;
    }
    return;
  }

  if (key == ESC) {
    if (openPanel > 0) { openPanel = 0; key = 0; return; }
    key = 0; returnToPlayground(); return;
  }
  if (key == BACKSPACE) { returnToPlayground(); return; }

  if (currentAvailableSize == 0) return;

  boolean shiftHeld = (keyEvent != null && keyEvent.isShiftDown());

  if (key == CODED) {
    if (keyCode == java.awt.event.KeyEvent.VK_HOME) { galleryIndex = 0; resetAnimation(); return; }
    if (keyCode == java.awt.event.KeyEvent.VK_END)  { galleryIndex = currentAvailableSize - 1; resetAnimation(); return; }

    int onePct = max(1, currentAvailableSize / 100);
    int tenPct = max(1, currentAvailableSize / 10);

    if (shiftHeld) {
      if      (keyCode == RIGHT) { galleryIndex = clampIndex(galleryIndex + onePct, currentAvailableSize); resetAnimation(); }
      else if (keyCode == LEFT)  { galleryIndex = clampIndex(galleryIndex - onePct, currentAvailableSize); resetAnimation(); }
      else if (keyCode == UP)    { galleryIndex = clampIndex(galleryIndex + tenPct, currentAvailableSize); resetAnimation(); }
      else if (keyCode == DOWN)  { galleryIndex = clampIndex(galleryIndex - tenPct, currentAvailableSize); resetAnimation(); }
    } else {
      if (currentAvailableSize <= 1) return;
      if      (keyCode == RIGHT) { galleryIndex = (galleryIndex + 1)   % currentAvailableSize; resetAnimation(); }
      else if (keyCode == LEFT)  { galleryIndex = (galleryIndex - 1 + currentAvailableSize) % currentAvailableSize; resetAnimation(); }
      else if (keyCode == UP)    { galleryIndex = (galleryIndex + 100) % currentAvailableSize; resetAnimation(); }
      else if (keyCode == DOWN)  { galleryIndex = (galleryIndex - 100 + currentAvailableSize) % currentAvailableSize; resetAnimation(); }
    }
    return;
  }

  char lc = Character.toLowerCase(key);
  if (lc == 'o') { gotoInputActive = true; gotoInputBuffer = ""; }
  else if (lc == 'r') {
    if (currentAvailableSize > 1) {
      int newIdx; do { newIdx = (int)random(currentAvailableSize); } while (newIdx == galleryIndex);
      galleryIndex = newIdx; resetAnimation();
    }
  }
}

// Mouse wheel
float wheelAccumulator = 0;
float wheelStepThreshold = 1.0f;
boolean wheelCalibrated = false;

void mouseWheel(MouseEvent event) {
  // Preset list scroll (playground panel 1)
  if (openPanel == 1 && panelSlide > 0.5f && presetListArea[2] > 0 && mouseInRect(presetListArea)) {
    float rowH = (26 * UI_TEXT_SCALE + 4);
    float contentH = presets.size() * rowH;
    float maxScroll = max(0, contentH - presetListArea[3]);
    presetScrollY = constrain(presetScrollY + event.getCount() * rowH, 0, maxScroll);
    return;
  }

  // Palette list scroll when panel 2 is open (works in any state)
  if (openPanel == 2 && panelSlide > 0.5f && paletteListArea[2] > 0 && mouseInRect(paletteListArea)) {
    float rowH = 28 * UI_TEXT_SCALE;
    int   totalP = BUILTIN_PALETTE_COUNT + customPalettes.size();
    float contentH = totalP * rowH;
    float maxScroll = max(0, contentH - paletteListArea[3]);
    paletteListScrollY = constrain(paletteListScrollY + event.getCount() * rowH, 0, maxScroll);
    return;
  }

  // Playground: scroll zooms the canvas
  if (currentState == AppState.PLAYGROUND || currentState == AppState.CALCULATING) {
    zoomDrawView(event.getCount(), mouseX, mouseY);
    return;
  }

  if (currentState != AppState.GALLERY || gotoInputActive) return;
  int sz; synchronized(totalGallery) { sz = totalGallery.size(); }
  if (sz <= 1) return;

  float rawCount = event.getCount();
  if (rawCount == 0) return;
  float magnitude = abs(rawCount);
  if (!wheelCalibrated || magnitude < wheelStepThreshold) {
    wheelStepThreshold = magnitude; wheelCalibrated = true;
  }
  wheelAccumulator += rawCount;
  int rawSteps = (int)(wheelAccumulator / wheelStepThreshold);
  if (rawSteps == 0) return;
  wheelAccumulator -= rawSteps * wheelStepThreshold;

  boolean shiftHeld = event.isShiftDown();
  int stepMag = shiftHeld ? max(1, sz / 100) : 1;
  long steps = (long)rawSteps * stepMag;

  if (shiftHeld) {
    galleryIndex = clampIndex(
      (int)Math.min(Math.max((long)galleryIndex + steps, 0L), (long)(sz - 1)), sz);
  } else {
    long size = sz;
    galleryIndex = (int)(((galleryIndex + steps) % size + size) % size);
  }
  resetAnimation();
}

// Clipboard helpers
void pasteIntoCustomSignature() {
  try {
    Clipboard clipboard = Toolkit.getDefaultToolkit().getSystemClipboard();
    Transferable contents = clipboard.getContents(null);
    if (contents == null || !contents.isDataFlavorSupported(DataFlavor.stringFlavor)) {
      notify("Clipboard is empty"); return;
    }
    String raw = (String) contents.getTransferData(DataFlavor.stringFlavor);
    if (raw == null) { notify("Clipboard is empty"); return; }

    StringBuilder cleaned = new StringBuilder();
    int dropped = 0;
    for (int i = 0; i < raw.length(); i++) {
      char c = Character.toLowerCase(raw.charAt(i));
      if (c == 'a' || c == 'q' || c == 'w' || c == 'e' || c == 'd') cleaned.append(c);
      else if (!Character.isWhitespace(c)) dropped++;
    }
    if (cleaned.length() == 0) { notify("Clipboard had no valid aqwed characters"); return; }

    String inserted = cleaned.toString();
    customSignature = customSignature.substring(0, cursorPos) + inserted + customSignature.substring(cursorPos);
    cursorPos += inserted.length();
    syncSigToPath(); // recenter on pasted pattern

    String pasteMsg = "Pasted " + inserted.length() + " chars";
    if (dropped > 0) pasteMsg += " (dropped " + dropped + " invalid)";
    notify(pasteMsg, 120, NOTIF_INFO);
  } catch (Exception e) {
    println("Paste failed: " + e.getMessage());
    notify("Paste failed");
  }
}

void copyInlineFormat() {
  String[] dirNames = {"EAST", "SOUTH_EAST", "SOUTH_WEST", "WEST", "NORTH_WEST", "NORTH_EAST"};
  String sig, dir;
  if (currentState == AppState.GALLERY) {
    byte[] path = currentPathBytes();
    if (path.length == 0) { notify("Nothing to copy", 90, NOTIF_WARN); return; }
    dir = dirNames[path[0] & 0xFF];
    sig = bytesToSignature(path);
  } else {
    if (customSignature.length() == 0) { notify("Nothing to copy", 90, NOTIF_WARN); return; }
    dir = dirNames[currentPatternStartDir];
    sig = customSignature;
  }
  try {
    StringSelection sel = new StringSelection("HexPattern[" + dir + ", " + sig + "]");
    Toolkit.getDefaultToolkit().getSystemClipboard().setContents(sel, sel);
    notify("Copied as HexPattern", 90, NOTIF_SUCCESS);
  } catch (Exception e) { notify("Copy failed", 90, NOTIF_ERROR); }
}

// Utilities
int clampIndex(int idx, int total) {
  if (idx < 0)      return 0;
  if (idx >= total) return total - 1;
  return idx;
}

void returnToPlayground() {
  pendingRestart   = false;
  drawExtendSide   = 0;
  currentState     = AppState.PLAYGROUND;
  gotoInputActive  = false;
  gotoInputBuffer  = "";
  scrubberDragging = false;
  sliderDragging   = DRAG_NONE;
  errorMessage     = "";
  openPanel        = 0;
  panelSlide       = 0f;
  inputScrollX     = 0f;
  wheelAccumulator = 0f;
  wheelCalibrated  = false;
}

void showError(String msg) {
  errorMessage = msg;
  currentState = AppState.ERROR;
}

// Draw mode interaction
void handleDrawMousePressed() {
  float step = drawStepSize();
  float snapR = step * 0.55f;

  if (drawPath.size() == 0) {
    // Click anywhere to snap to the nearest grid node and prepare to draw.
    // Rebase the viewport so axial (0,0) sits at that position - keeps all
    // subsequent coordinate arithmetic near zero regardless of pan distance.
    int[] ax = screenToNearestAxial(mouseX, mouseY);
    float[] sc = axialToScreen(ax[0], ax[1]);
    drawViewX = drawTargetX = sc[0];
    drawViewY = drawTargetY = sc[1];
    drawStartAxial[0] = 0; drawStartAxial[1] = 0;
    drawEndAxial[0]   = 0; drawEndAxial[1]   = 0;
    drawExtendSide    = 1;
    drawDragging      = true;
    return;
  }

  float[] startScr = axialToScreen(drawStartAxial[0], drawStartAxial[1]);
  float[] endScr   = axialToScreen(drawEndAxial[0],   drawEndAxial[1]);

  if (dist(mouseX, mouseY, endScr[0], endScr[1]) < snapR) {
    drawExtendSide = 1;
    drawDragging   = true;
  } else if (dist(mouseX, mouseY, startScr[0], startScr[1]) < snapR) {
    drawExtendSide = -1;
    drawDragging   = true;
  } else {
    // Click away from both endpoints: mark a pending restart.
    // The old path stays intact until the user actually drags to a neighbour.
    int[] ax = screenToNearestAxial(mouseX, mouseY);
    pendingRestartAxial[0] = ax[0];
    pendingRestartAxial[1] = ax[1];
    pendingRestart = true;
    drawExtendSide = 1;
    drawDragging   = true;
  }
}

void handleDrawMouseDragged() {
  trySnapToNeighbor(mouseX, mouseY);
}

void handleDrawMouseReleased() {
  pendingRestart = false; // cancelled without drawing, old path preserved
  drawDragging   = false;
  drawExtendSide = 0;
  syncDrawToType();
}

void trySnapToNeighbor(float mx, float my) {
  if (drawExtendSide == 0) return;

  // Pending restart: snap from the new origin; commit (clear old path) on first edge.
  if (pendingRestart) {
    float step  = drawStepSize();
    float snapR = step * 0.5f;
    for (int d = 0; d < 6; d++) {
      int nq = pendingRestartAxial[0] + DIR_OFFSETS[d][0];
      int nr = pendingRestartAxial[1] + DIR_OFFSETS[d][1];
      float[] s = axialToScreen(nq, nr);
      if (dist(mx, my, s[0], s[1]) < snapR) {
        // Rebase: shift the viewport so axial (0,0) = pendingRestartAxial's screen position.
        // Screen positions are unchanged; all new coords stay near zero.
        float[] originSc = axialToScreen(pendingRestartAxial[0], pendingRestartAxial[1]);
        drawViewX = drawTargetX = originSc[0];
        drawViewY = drawTargetY = originSc[1];
        drawPath.clear(); drawUsedEdges.clear();
        drawStartAxial[0] = 0; drawStartAxial[1] = 0;
        drawEndAxial[0]   = 0; drawEndAxial[1]   = 0;
        pendingRestart = false;
        syncDrawToType();
        String ek = edgeKeyFor(packQR(0, 0), packQR(DIR_OFFSETS[d][0], DIR_OFFSETS[d][1]));
        drawUsedEdges.add(ek);
        drawPath.add((byte) d);
        drawEndAxial[0] = DIR_OFFSETS[d][0]; drawEndAxial[1] = DIR_OFFSETS[d][1];
        return;
      }
    }
    return; // not over a neighbour yet, keep waiting
  }

  int[] activeAxial = (drawExtendSide == 1) ? drawEndAxial : drawStartAxial;
  float step = drawStepSize();
  float snapR = step * 0.5f;

  for (int d = 0; d < 6; d++) {
    int nq = activeAxial[0] + DIR_OFFSETS[d][0];
    int nr = activeAxial[1] + DIR_OFFSETS[d][1];
    float[] s = axialToScreen(nq, nr);
    if (dist(mx, my, s[0], s[1]) >= snapR) continue;

    int[] neighbor = {nq, nr};

    if (drawExtendSide == 1) {
      // Check if this is a backtrack (snap to the node before the end)
      if (drawPath.size() >= 1) {
        // The node before drawEndAxial is drawEndAxial - DIR_OFFSETS[lastDir]
        int lastDir = drawPath.get(drawPath.size() - 1);
        int prevQ = drawEndAxial[0] - DIR_OFFSETS[lastDir][0];
        int prevR = drawEndAxial[1] - DIR_OFFSETS[lastDir][1];
        if (nq == prevQ && nr == prevR) {
          // Backtrack: remove last step
          String ek = edgeKeyFor(packQR(drawEndAxial[0], drawEndAxial[1]),
                                 packQR(prevQ, prevR));
          drawUsedEdges.remove(ek);
          drawPath.remove(drawPath.size() - 1);
          drawEndAxial[0] = prevQ;
          drawEndAxial[1] = prevR;
          return;
        }
      }
      // Forward step from end.
      // drawPath: every entry is a real edge; index 0 = first/initial edge direction.
      if (!isDrawDirAllowed(d)) return;
      String ek = edgeKeyFor(packQR(activeAxial[0], activeAxial[1]), packQR(nq, nr));
      if (drawUsedEdges.contains(ek)) return;
      drawUsedEdges.add(ek);
      drawPath.add((byte) d);
      drawEndAxial[0] = nq;
      drawEndAxial[1] = nr;

    } else {
      // drawExtendSide == -1 (prepend from start)
      // drawPath[0] = first/initial edge direction; all entries are real edges.
      // Backtrack: neighbor is the node that the first edge reaches from drawStartAxial.
      if (drawPath.size() > 0) {
        int firstEdgeDir = drawPath.get(0);
        int nextQ = drawStartAxial[0] + DIR_OFFSETS[firstEdgeDir][0];
        int nextR = drawStartAxial[1] + DIR_OFFSETS[firstEdgeDir][1];
        if (nq == nextQ && nr == nextR) {
          // Backtrack: un-prepend the first edge.
          String ek = edgeKeyFor(packQR(drawStartAxial[0], drawStartAxial[1]),
                                 packQR(nextQ, nextR));
          drawUsedEdges.remove(ek);
          drawPath.remove(0);
          drawStartAxial[0] = nextQ;
          drawStartAxial[1] = nextR;
          return;
        }
      }
      // Prepend: new start = neighbor, edge goes neighbor -> old_start (dir = (d+3)%6).
      if (!isDrawDirAllowed(d)) return;
      String ek = edgeKeyFor(packQR(activeAxial[0], activeAxial[1]), packQR(nq, nr));
      if (drawUsedEdges.contains(ek)) return;
      drawUsedEdges.add(ek);
      drawPath.add(0, (byte)((d + 3) % 6));
      drawStartAxial[0] = nq;
      drawStartAxial[1] = nr;
    }
    return;
  }
}


// Palette list right-click, open edit modal for custom palettes
void handlePanel2PaletteRightClick() {
  float rowH   = 28 * UI_TEXT_SCALE;
  int   totalP = BUILTIN_PALETTE_COUNT + customPalettes.size();
  int   row    = (int)((mouseY - paletteListArea[1] + paletteListScrollY) / rowH);
  if (row < BUILTIN_PALETTE_COUNT || row >= totalP) return;
  int ci = row - BUILTIN_PALETTE_COUNT;
  if (ci >= customPalettes.size()) return;
  CustomPalette cp = customPalettes.get(ci);
  editingPaletteIndex = ci;
  newPaletteName      = cp.name;
  newPaletteStartH    = cp.startH; newPaletteStartS = cp.startS; newPaletteStartB = cp.startB;
  newPaletteEndH      = cp.endH;   newPaletteEndS   = cp.endS;   newPaletteEndB   = cp.endB;
  newPaletteModalOpen = true;
}

// Cleanup confirmation modal handlers
void handleCleanupConfirmMouse() {
  if (mouseButton != LEFT) return;
  if (mouseInRect(btnCleanupDo)) { cleanupAndExit(); return; }
  if (mouseInRect(btnCleanupNo)) { cleanupConfirmOpen = false; return; }
}

void handleCleanupConfirmKey() {
  if (key == ESC) { cleanupConfirmOpen = false; key = 0; }
}

// Preset modal input handlers
void handlePresetModalMouse() {
  if (mouseButton != LEFT) return;
  if (mouseInRect(btnPresetSave))   { commitNewPreset(); return; }
  if (mouseInRect(btnPresetCancel)) { presetModalOpen = false; newPresetName = ""; return; }
}

void handlePresetModalKey() {
  if (key == ESC) { presetModalOpen = false; newPresetName = ""; key = 0; return; }
  if (key == ENTER || key == RETURN) { commitNewPreset(); return; }
  if (key == BACKSPACE) {
    if (newPresetName.length() > 0)
      newPresetName = newPresetName.substring(0, newPresetName.length() - 1);
    return;
  }
  if (key == DELETE) {
    // forward delete not applicable in this single-line field - ignore
    return;
  }
  if (key != CODED && key >= ' ' && newPresetName.length() < 32)
    newPresetName += key;
}

// New-palette modal input handlers
void handleNewPaletteModalMouse() {
  if (mouseButton != LEFT) return;
  if (!colorPickerOpen && mouseInRect(btnModalPickStart)) { openColorPicker(0); return; }
  if (!colorPickerOpen && mouseInRect(btnModalPickEnd))   { openColorPicker(1); return; }
  if (mouseInRect(btnModalCreate))  { commitNewPalette(); return; }
  if (mouseInRect(btnModalCancel))  { newPaletteModalOpen = false; newPaletteName = ""; editingPaletteIndex = -1; return; }
}

void handleNewPaletteModalKey() {
  if (key == ESC) {
    newPaletteModalOpen = false; newPaletteName = ""; editingPaletteIndex = -1; key = 0; return;
  }
  if (key == ENTER || key == RETURN) { commitNewPalette(); return; }
  if (key == BACKSPACE) {
    if (newPaletteName.length() > 0)
      newPaletteName = newPaletteName.substring(0, newPaletteName.length() - 1);
    return;
  }
  if (key != CODED && key >= ' ' && newPaletteName.length() < 28) {
    newPaletteName += key;
  }
}
