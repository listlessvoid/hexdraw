void drawErrorScreen() {
  float boxW = 720 * UI_TEXT_SCALE;
  float boxH = 280 * UI_TEXT_SCALE;
  float boxX = width / 2f - boxW / 2f;
  float boxY = height / 2f - boxH / 2f;

  fill(35, 18, 22);
  stroke(255, 80, 100);
  strokeWeight(2);
  rect(boxX, boxY, boxW, boxH, 12);

  textAlign(CENTER, CENTER);
  fill(255, 120, 130);
  textSize(24 * UI_TEXT_SCALE);
  text("INPUT REJECTED", width / 2f, boxY + 45 * UI_TEXT_SCALE);

  fill(220);
  textSize(14 * UI_TEXT_SCALE);
  textAlign(CENTER, TOP);
  text(errorMessage, boxX + 30, boxY + 90 * UI_TEXT_SCALE, boxW - 60, boxH - 140 * UI_TEXT_SCALE);

  fill(160);
  textSize(12 * UI_TEXT_SCALE);
  textAlign(CENTER, CENTER);
  text("[ENTER] or [BACKSPACE] or click to return to playground", width / 2f, boxY + boxH - 28 * UI_TEXT_SCALE);
}
