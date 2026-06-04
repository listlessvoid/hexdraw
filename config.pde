// resolves to the jar's directory so config stays next to the executable; falls back to sketchPath() in the IDE
String configRoot() {
  try {
    java.net.URL loc = getClass().getProtectionDomain().getCodeSource().getLocation();
    java.io.File src = new java.io.File(loc.toURI());
    if (src.isFile() && src.getName().endsWith(".jar")) {
      return src.getParent();
    }
  } catch (Exception ignored) {}
  return sketchPath();
}

String configPath() {
  return new java.io.File(configRoot(), "config.json").getAbsolutePath();
}

String exportsDir() {
  return new java.io.File(configRoot(), "exports").getAbsolutePath();
}

String exportsPath(String filename) {
  return new java.io.File(configRoot(), "exports/" + filename).getAbsolutePath();
}

void resetConfig() {
  currentPalette = 0; paletteReversed = false;
  arcMode = false; gridDotsMode = true; showExportMarkers = false; gifUncapped = false;
  traceSpeed = 0.4f; pulseSpeed = 0.04f;
  gradientCycle = 0.0f; strokeWidthBase = 5.0f; arcInset = 0.40f;
  showBackground = false; bgColorH = 0; bgColorS = 0; bgColorB = 100;
  customPalettes.clear();
  presets.clear(); addDefaultPresets();
  saveConfig();
  notify("Config reset to defaults", 120, NOTIF_SUCCESS);
}

void cleanupAndExit() {
  exitCleanup = true;
  try { deleteRecursive(new java.io.File(exportsDir())); } catch (Exception ignored) {}
  try { new java.io.File(configPath()).delete(); }        catch (Exception ignored) {}
  try { new java.io.File(configRoot(), "hex_spells.txt").delete(); } catch (Exception ignored) {}
  exit();
}

// plain Java only - safe to call from settings() before Processing initialises
int[] readSavedWindowSize() {
  int defW = Math.max(900,  (int)(displayWidth  * 0.60f));
  int defH = Math.max(700,  (int)(displayHeight * 0.85f));
  try {
    java.io.File f = new java.io.File(configPath());
    if (!f.exists()) return new int[]{defW, defH};
    byte[] bytes = java.nio.file.Files.readAllBytes(f.toPath());
    processing.data.JSONObject cfg = processing.data.JSONObject.parse(new String(bytes, "UTF-8"));
    int w = cfg.getInt("windowW", 0);
    int h = cfg.getInt("windowH", 0);
    if (w >= 600 && h >= 400) return new int[]{w, h};
  } catch (Exception ignored) {}
  return new int[]{defW, defH};
}

void saveWindowGeometry() {
  if (sketchFrame == null) return;
  if ((sketchFrame.getExtendedState() & java.awt.Frame.ICONIFIED) != 0) return;
  java.awt.Point loc = sketchFrame.getLocation();
  windowX = loc.x; windowY = loc.y;
  windowW = width;  windowH = height;
  saveConfig();
}

boolean isPositionOnScreen(int x, int y, int w, int h) {
  try {
    java.awt.Rectangle all = new java.awt.Rectangle();
    for (java.awt.GraphicsDevice gd :
         java.awt.GraphicsEnvironment.getLocalGraphicsEnvironment().getScreenDevices()) {
      all = all.union(gd.getDefaultConfiguration().getBounds());
    }
    return all.contains(x + w / 2, y + h / 2);
  } catch (Exception ignored) { return false; }
}

void deleteRecursive(java.io.File f) {
  if (!f.exists()) return;
  if (f.isDirectory()) {
    java.io.File[] files = f.listFiles();
    if (files != null) for (java.io.File c : files) deleteRecursive(c);
  }
  f.delete();
}

void addDefaultPresets() {
  presets.add(new Preset("Create Lava",             "eaqawqadaqd",                          0));
  presets.add(new Preset("Summon Lightning",        "waadwawdaaweewq",                      0));
  presets.add(new Preset("Summon Rain",             "wwweeewwweewdawdwad",                  3));
  presets.add(new Preset("Dispel Rain",             "eeewwweeewwaqqddqdqd",                 3));
  presets.add(new Preset("Altiora",                 "eawwaeawawaa",                         1));
  presets.add(new Preset("Greater Teleport",        "wwwqqqwwwqqeqqwwwqqwqqdqqqqqdqq",      0));
  presets.add(new Preset("White Sun Zenith",        "qqqqaawawaedd",                        4));
  presets.add(new Preset("Blue Sun Zenith",         "qqqaawawaeqdd",                        3));
  presets.add(new Preset("Black Sun Zenith",        "qqaawawaeqqdd",                        2));
  presets.add(new Preset("Red Sun Zenith",          "qaawawaeqqqdd",                        1));
  presets.add(new Preset("Green Sun Zenith",        "aawawaeqqqqdd",                        0));
  presets.add(new Preset("Summon Greater Sentinel", "waeawaeqqqwqwqqwq",                    0));
  presets.add(new Preset("Craft Phial",             "aqqqaqwwaqqqqqeqaqqqawwqwqwqwqwqw",    2));
  presets.add(new Preset("Flay Mind",               "qeqwqwqwqwqeqaeqeaqeqaeqaqded",        5));
}

void loadConfig() {
  java.io.File f = new java.io.File(configPath());
  if (!f.exists()) {
    addDefaultPresets();
    saveConfig(); // write defaults so the file exists next run
    return;
  }
  try {
    JSONObject cfg = loadJSONObject(f.getAbsolutePath());
    if (cfg == null) return;
    windowW           = cfg.getInt("windowW",              0);
    windowH           = cfg.getInt("windowH",              0);
    windowX           = cfg.getInt("windowX",             -1);
    windowY           = cfg.getInt("windowY",             -1);
    currentPalette    = cfg.getInt("palette",             currentPalette);
    paletteReversed   = cfg.getBoolean("paletteReversed", false);
    arcMode           = cfg.getBoolean("arcMode",         arcMode);
    gridDotsMode      = cfg.getBoolean("gridDotsMode",    gridDotsMode);
    showExportMarkers = cfg.getBoolean("showExportMarkers", showExportMarkers);
    traceSpeed        = cfg.getFloat("traceSpeed",        traceSpeed);
    pulseSpeed        = cfg.getFloat("pulseSpeed",        pulseSpeed);
    gradientCycle     = cfg.getFloat("gradientCycle",     gradientCycle);
    strokeWidthBase   = cfg.getFloat("strokeWidthBase",   strokeWidthBase);
    arcInset          = cfg.getFloat("arcInset",          arcInset);
    gifUncapped       = cfg.getBoolean("gifUncapped",      gifUncapped);
    showBackground    = cfg.getBoolean("showBackground",  showBackground);
    bgColorH          = cfg.getFloat("bgColorH",          bgColorH);
    bgColorS          = cfg.getFloat("bgColorS",          bgColorS);
    bgColorB          = cfg.getFloat("bgColorB",          bgColorB);
    JSONArray palArr  = cfg.getJSONArray("customPalettes");
    if (palArr != null) {
      for (int i = 0; i < palArr.size(); i++) {
        JSONObject p = palArr.getJSONObject(i);
        CustomPalette cp = new CustomPalette();
        cp.name   = p.getString("name",   "Custom");
        cp.startH = p.getFloat("startH",   220f);
        cp.startS = p.getFloat("startS",    90f);
        cp.startB = p.getFloat("startB",   100f);
        cp.endH   = p.getFloat("endH",       0f);
        cp.endS   = p.getFloat("endS",      90f);
        cp.endB   = p.getFloat("endB",     100f);
        customPalettes.add(cp);
      }
    }
    int total = BUILTIN_PALETTE_COUNT + customPalettes.size();
    if (currentPalette >= total) { currentPalette = 0; paletteReversed = false; }
    JSONArray presArr = cfg.getJSONArray("presets");
    if (presArr != null) {
      for (int i = 0; i < presArr.size(); i++) {
        JSONObject po = presArr.getJSONObject(i);
        presets.add(new Preset(po.getString("name", ""), po.getString("signature", ""), po.getInt("startDir", 0)));
      }
    } else {
      addDefaultPresets(); // legacy config without presets key
    }
  } catch (Exception e) {
    println("Config load failed: " + e.getMessage());
  }
}

void saveConfig() {
  try {
    JSONObject cfg = new JSONObject();
    cfg.setInt("windowW",               windowW > 0 ? windowW : width);
    cfg.setInt("windowH",               windowH > 0 ? windowH : height);
    cfg.setInt("windowX",               windowX);
    cfg.setInt("windowY",               windowY);
    cfg.setInt("palette",               currentPalette);
    cfg.setBoolean("paletteReversed",   paletteReversed);
    cfg.setBoolean("arcMode",           arcMode);
    cfg.setBoolean("gridDotsMode",      gridDotsMode);
    cfg.setBoolean("showExportMarkers", showExportMarkers);
    cfg.setFloat("traceSpeed",          traceSpeed);
    cfg.setFloat("pulseSpeed",          pulseSpeed);
    cfg.setFloat("gradientCycle",       gradientCycle);
    cfg.setFloat("strokeWidthBase",     strokeWidthBase);
    cfg.setFloat("arcInset",            arcInset);
    cfg.setBoolean("gifUncapped",        gifUncapped);
    cfg.setBoolean("showBackground",    showBackground);
    cfg.setFloat("bgColorH",            bgColorH);
    cfg.setFloat("bgColorS",            bgColorS);
    cfg.setFloat("bgColorB",            bgColorB);
    JSONArray palArr = new JSONArray();
    for (CustomPalette cp : customPalettes) {
      JSONObject p = new JSONObject();
      p.setString("name",   cp.name);
      p.setFloat("startH",  cp.startH);
      p.setFloat("startS",  cp.startS);
      p.setFloat("startB",  cp.startB);
      p.setFloat("endH",    cp.endH);
      p.setFloat("endS",    cp.endS);
      p.setFloat("endB",    cp.endB);
      palArr.append(p);
    }
    cfg.setJSONArray("customPalettes", palArr);
    JSONArray presArr = new JSONArray();
    for (Preset p : presets) {
      JSONObject po = new JSONObject();
      po.setString("name",      p.name);
      po.setString("signature", p.signature);
      po.setInt("startDir",     p.startDir);
      presArr.append(po);
    }
    cfg.setJSONArray("presets", presArr);
    saveJSONObject(cfg, configPath());
  } catch (Exception e) {
    println("Config save failed: " + e.getMessage());
  }
}
