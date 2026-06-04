color pathColorRaw(float t, int palette) {
  if (palette >= BUILTIN_PALETTE_COUNT) {
    int ci = palette - BUILTIN_PALETTE_COUNT;
    if (ci < customPalettes.size()) {
      CustomPalette cp = customPalettes.get(ci);
      return color(lerp(cp.startH, cp.endH, t),
                   lerp(cp.startS, cp.endS, t),
                   lerp(cp.startB, cp.endB, t));
    }
    return color(lerp(220, 0, t), 90, 100); // fallback
  }
  if (palette == 1) return color(200, 0, lerp(100, 35, t));   // Monochrome
  if (palette == 2) return color(lerp(280, 165, t), 85, 100); // Hexcasting
  return color(lerp(220, 0, t), 90, 100); // 0: Cool→Warm (default)
}

color pathColor(int edgeIndex, int totalEdgeCount, int palette) {
  float normalized = (totalEdgeCount > 1) ? (float)edgeIndex / (float)(totalEdgeCount - 1) : 0f;
  float t;
  if (gradientCycle < 0.05f) {
    t = normalized; // AUTO: no modulo - t==1.0 must not wrap back to 0 (last edge would get start color)
  } else {
    // Ping-pong: even cycles go forward, odd cycles go backward.
    // Avoids the hard colour jump that a sawtooth (modulo) produces.
    float val    = normalized * gradientCycle;
    int   cycleN = (int)val;
    float frac   = val - cycleN;
    t = (cycleN % 2 == 0) ? frac : 1.0f - frac;
  }
  if (paletteReversed) t = 1.0f - t;
  return pathColorRaw(t, palette);
}

void drawHexPath(byte[] dirs, float drawAreaW) {
  if (arcMode) drawHexPathArc(dirs, drawAreaW);
  else         drawHexPathStraight(dirs, drawAreaW);
  drawGridDots(drawAreaW); // always last - on top of path, clipped to draw area
}

// straight renderer
void drawHexPathStraight(byte[] dirs, float drawAreaW) {
  if (dirs == null || dirs.length == 0) return;
  if (traceSpeed >= 2.99f) currentStep = 9999f; // max = instant

  PVector[] vertices = buildVertices(dirs, drawAreaW);
  if (vertices == null) return;

  int N = dirs.length; // number of edges

  float dynamicStrokeWeight = constrain(strokeWidthBase * lastTargetScale, 1f, strokeWidthBase * 3f);
  strokeWeight(dynamicStrokeWeight); strokeJoin(ROUND); noFill();

  pushStyle();
  colorMode(HSB, 360, 100, 100);

  // Draw each edge as 3 sub-segments: color shifts smoothly across the midpoint.
  // Sub-seg colors: pathColor(i), midpoint between i and i+1, pathColor(i+1).
  int maxDrawIndex = min(floor(currentStep), N);
  for (int i = 0; i < maxDrawIndex; i++) {
    color cA = pathColor(i,     N + 1, currentPalette);
    color cB = pathColor(i + 1, N + 1, currentPalette);
    color cMid = lerpColor(cA, cB, 0.5f);
    PVector vA = vertices[i], vB = vertices[i + 1];
    PVector m1 = new PVector(lerp(vA.x, vB.x, 1f/3f), lerp(vA.y, vB.y, 1f/3f));
    PVector m2 = new PVector(lerp(vA.x, vB.x, 2f/3f), lerp(vA.y, vB.y, 2f/3f));
    stroke(cA);   line(vA.x, vA.y, m1.x, m1.y);
    stroke(cMid); line(m1.x, m1.y, m2.x, m2.y);
    stroke(cB);   line(m2.x, m2.y, vB.x, vB.y);
  }
  // Partial last segment - split proportionally across the 3 sub-segs
  if (currentStep < N) {
    float frac = currentStep - floor(currentStep);
    if (frac > 0 && floor(currentStep) < N) {
      int idx = floor(currentStep);
      color cA = pathColor(idx,     N + 1, currentPalette);
      color cB = pathColor(idx + 1, N + 1, currentPalette);
      color cMid = lerpColor(cA, cB, 0.5f);
      PVector vA = vertices[idx], vB = vertices[idx + 1];
      PVector m1 = new PVector(lerp(vA.x, vB.x, 1f/3f), lerp(vA.y, vB.y, 1f/3f));
      PVector m2 = new PVector(lerp(vA.x, vB.x, 2f/3f), lerp(vA.y, vB.y, 2f/3f));
      float px, py;
      if (frac < 1f/3f) {
        float t = frac * 3f;
        px = lerp(vA.x, m1.x, t); py = lerp(vA.y, m1.y, t);
        stroke(cA); line(vA.x, vA.y, px, py);
      } else if (frac < 2f/3f) {
        float t = (frac - 1f/3f) * 3f;
        px = lerp(m1.x, m2.x, t); py = lerp(m1.y, m2.y, t);
        stroke(cA);   line(vA.x, vA.y, m1.x, m1.y);
        stroke(cMid); line(m1.x, m1.y, px, py);
      } else {
        float t = (frac - 2f/3f) * 3f;
        px = lerp(m2.x, vB.x, t); py = lerp(m2.y, vB.y, t);
        stroke(cA);   line(vA.x, vA.y, m1.x, m1.y);
        stroke(cMid); line(m1.x, m1.y, m2.x, m2.y);
        stroke(cB);   line(m2.x, m2.y, px, py);
      }
    }
  }

  popStyle();

  if (currentStep < N) {
    currentStep += traceSpeed;
    return;
  }

  drawEndMarkers(vertices, lastTargetScale);
  drawPulse(vertices, dirs.length);
}

// arc renderer
void drawHexPathArc(byte[] dirs, float drawAreaW) {
  if (dirs == null || dirs.length == 0) return;
  if (traceSpeed >= 2.99f) currentStep = 9999f; // max = instant

  PVector[] v = buildVertices(dirs, drawAreaW);
  if (v == null) return;

  int N = dirs.length;

  // Compute inset points for each edge.
  PVector[] insetStart = new PVector[N];
  PVector[] insetEnd   = new PVector[N];
  for (int i = 0; i < N; i++) {
    insetStart[i] = PVector.lerp(v[i],   v[i+1], arcInset);
    insetEnd[i]   = PVector.lerp(v[i+1], v[i],   arcInset);
  }
  insetStart[0]   = v[0].copy(); // terminal: first segment reaches start node
  insetEnd[N-1]   = v[N].copy(); // terminal: last segment reaches end node

  float sw = constrain(strokeWidthBase * lastTargetScale, 1f, strokeWidthBase * 3f);
  strokeWeight(sw); strokeJoin(ROUND); noFill();

  pushStyle();
  colorMode(HSB, 360, 100, 100);

  // 2N-1 drawable elements: seg[0], arc[1], seg[1], arc[2], seg[2], ...
  // element 2i   = straight segment i
  // element 2i+1 = arc at vertex i+1 (for i in 0..N-2)
  // Map currentStep (0..N) to arcStep (0..2N-1):
  // arcStep = currentStep * (2N-1) / N  (approx: one "step" covers one segment + one arc)
  // Actually simpler: each edge = two drawing elements, so arcStep = currentStep * 2
  // But the last edge has no arc after it. Total elements = 2N-1.
  // Let's just use arcStep = currentStep * (2N-1) / N.
  int totalElements = max(1, 2 * N - 1);
  float arcStep = (N > 0) ? currentStep * (float)totalElements / (float)N : 0f;
  int maxEl = min(floor(arcStep), totalElements);

  for (int el = 0; el < maxEl; el++) {
    if (el % 2 == 0) {
      // Straight segment el/2
      int si = el / 2;
      stroke(pathColor(si, N, currentPalette));
      line(insetStart[si].x, insetStart[si].y, insetEnd[si].x, insetEnd[si].y);
    } else {
      // Arc at vertex (el+1)/2
      int vi = (el + 1) / 2;
      stroke(pathColor(vi - 1, N, currentPalette));
      noFill();
      bezier(insetEnd[vi-1].x,  insetEnd[vi-1].y,
             v[vi].x,           v[vi].y,
             v[vi].x,           v[vi].y,
             insetStart[vi].x,  insetStart[vi].y);
    }
  }
  // Partial current element
  if (arcStep < totalElements) {
    float elFrac = arcStep - floor(arcStep);
    int el = floor(arcStep);
    if (el < totalElements) {
      if (el % 2 == 0) {
        int si = el / 2;
        stroke(pathColor(si, N, currentPalette));
        float px = lerp(insetStart[si].x, insetEnd[si].x, elFrac);
        float py = lerp(insetStart[si].y, insetEnd[si].y, elFrac);
        line(insetStart[si].x, insetStart[si].y, px, py);
      }
      // Arc partial: skip for simplicity (arcs are short, partial looks choppy)
    }
  }

  popStyle();

  if (currentStep < N) {
    currentStep += traceSpeed;
    return;
  }

  drawEndMarkers(v, lastTargetScale);
  drawPulse(v, N); // follow straight vertex path - same as straight mode
}

// helpers

float lastTargetScale  = 1.0f; // set by buildVertices, used by caller for markers/pulse
float lastGridOriginX  = 0f;   // screen position of axial (0,0), set by buildVertices
float lastGridOriginY  = 0f;

PVector[] buildVertices(byte[] dirs, float drawAreaW) {
  int N = dirs.length;
  PVector[] vertices = new PVector[N + 1];
  vertices[0] = new PVector(0, 0);

  float minX = 0, maxX = 0, minY = 0, maxY = 0;
  for (int i = 0; i < N; i++) {
    int normalizedDir = (dirs[i] + currentPatternStartDir) % 6;
    float angle = START_ANGLE + normalizedDir * (PI / 3f);
    PVector step = PVector.fromAngle(angle).mult(HEX_LINE_LENGTH);
    vertices[i+1] = PVector.add(vertices[i], step);
    minX = min(minX, vertices[i+1].x); maxX = max(maxX, vertices[i+1].x);
    minY = min(minY, vertices[i+1].y); maxY = max(maxY, vertices[i+1].y);
  }

  float patW = maxX - minX;
  float patH = maxY - minY;

  float topMargin    = 30 * UI_TEXT_SCALE;
  float bottomMargin = 72 * UI_TEXT_SCALE; // signature + strip
  float availW = drawAreaW - 40;
  float availH = height - topMargin - bottomMargin;
  if (availW <= 0 || availH <= 0) return null;

  float tScale = 1.0f;
  if (patW > 0 || patH > 0) {
    float sX = (patW > 0) ? availW / patW : Float.MAX_VALUE;
    float sY = (patH > 0) ? availH / patH : Float.MAX_VALUE;
    tScale = min(sX, sY, 4.0f);
  }
  lastTargetScale = tScale;

  for (PVector vv : vertices) vv.mult(tScale);
  minX *= tScale; maxX *= tScale; minY *= tScale; maxY *= tScale;

  float drawAreaCX = drawAreaW / 2f + START_OFFSET_X;
  float drawAreaCY = topMargin + (height - topMargin - bottomMargin) / 2f + START_OFFSET_Y;
  float patCX = (minX + maxX) / 2f;
  float patCY = (minY + maxY) / 2f;
  float dx = drawAreaCX - patCX;
  float dy = drawAreaCY - patCY;
  for (PVector vv : vertices) { vv.x += dx; vv.y += dy; }

  // Store origin for grid-dot rendering (screen position of axial 0,0 = first vertex)
  lastGridOriginX = vertices[0].x;
  lastGridOriginY = vertices[0].y;

  return vertices;
}

void drawGridDots(float drawAreaW) {
  if (!gridDotsMode) return;

  float step = HEX_LINE_LENGTH * lastTargetScale;
  if (step < 8) return; // too dense to be useful

  // Basis vectors for the hex grid, accounting for pattern rotation.
  float baseAngle = START_ANGLE + currentPatternStartDir * (PI / 3f);
  float bqx = cos(baseAngle),          bqy = sin(baseAngle);
  float brx = cos(baseAngle + PI/3f),  bry = sin(baseAngle + PI/3f);

  float ox = lastGridOriginX, oy = lastGridOriginY;

  // How many hex steps can fit across the max screen dimension.
  int R = ceil(max(drawAreaW, (float)height) / step) + 2;

  float dotDiam = constrain(step * 0.10f, 3f, 7f);

  pushStyle();
  noStroke();
  fill(160, 160, 175, 120); // semi-transparent overlay on top of path
  clip(0, 0, drawAreaW, height); // hard clip - never bleed into the panel

  for (int r = -R; r <= R; r++) {
    for (int q = -R; q <= R; q++) {
      float dotX = ox + (q * bqx + r * brx) * step;
      float dotY = oy + (q * bqy + r * bry) * step;
      if (dotX >= -step && dotX <= drawAreaW + step &&
          dotY >= -step && dotY <= height    + step) {
        circle(dotX, dotY, dotDiam);
      }
    }
  }

  noClip();
  popStyle();
}

void drawEndMarkers(PVector[] vertices, float ms) {
  ms = constrain(ms, 0.6f, 1.2f);
  // Start marker: filled green circle
  stroke(0, 255, 120); strokeWeight(2); fill(20, 40, 25, 200);
  circle(vertices[0].x, vertices[0].y, 16 * ms);
  fill(0, 255, 120); noStroke();
  circle(vertices[0].x, vertices[0].y, 6 * ms);

  // End marker: red circle + cross
  PVector endV = vertices[vertices.length - 1];
  stroke(255, 50, 80); strokeWeight(2); noFill();
  circle(endV.x, endV.y, 14 * ms);
  float cs = 10 * ms;
  line(endV.x - cs, endV.y, endV.x + cs, endV.y);
  line(endV.x, endV.y - cs, endV.x, endV.y + cs);
}

void drawPulse(PVector[] vertices, int N) {
  if (pulseSpeed <= 0.0031f) return; // min = disabled
  float ms = constrain(lastTargetScale, 0.6f, 1.2f);
  pulseProgress += pulseSpeed;
  if (pulseProgress >= N) pulseProgress = 0;

  int seg      = floor(pulseProgress);
  float segFrac = pulseProgress - seg;
  if (seg < N) {
    float pulseX = lerp(vertices[seg].x,   vertices[seg+1].x, segFrac);
    float pulseY = lerp(vertices[seg].y,   vertices[seg+1].y, segFrac);
    noStroke();
    fill(255, 255, 255, 60);  circle(pulseX, pulseY, 16 * ms);
    fill(255, 255, 255, 255); circle(pulseX, pulseY, 8  * ms);
  }
}
