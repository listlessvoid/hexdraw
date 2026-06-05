import java.util.*;
import java.io.*;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.awt.Toolkit;
import java.awt.datatransfer.StringSelection;
import java.awt.datatransfer.DataFlavor;
import java.awt.datatransfer.Clipboard;
import java.awt.datatransfer.Transferable;
import java.awt.datatransfer.*;
import java.awt.image.BufferedImage;
import javax.imageio.*;
import javax.imageio.metadata.*;
import javax.imageio.stream.*;



// user configuration
javax.swing.JFrame sketchFrame   = null;
boolean            exitCleanup   = false;
int windowW = 0, windowH = 0, windowX = -1, windowY = -1;

final float UI_TEXT_SCALE   = 1.5f;
final float HEX_LINE_LENGTH = 44.0f;

final float START_OFFSET_X = 0.0f;
final float START_OFFSET_Y = 0.0f;
final float START_ANGLE    = 0;

final float BTN_WIDTH   = 380f;
final float BTN_HEIGHT  = 35f;
final float GRID_START_Y = 160f;

final int MAX_EDGES = 63;

// notif types
final int NOTIF_INFO    = 0;
final int NOTIF_SUCCESS = 1;
final int NOTIF_WARN    = 2;
final int NOTIF_ERROR   = 3;

// panel vars
final float PANEL_WIDTH_FRAC = 0.28f;  // panel = 28 % of screen width
final float PANEL_ANIM_SPEED = 0.12f;  // lerp speed per frame (60 fps ≈ ~0.4 s open/close)

// slider ids
final int DRAG_NONE          = 0;
final int DRAG_TRACE         = 1;
final int DRAG_PULSE         = 2;
final int DRAG_GRADIENT      = 3;
final int DRAG_STROKE        = 4;
final int DRAG_ARC_INSET     = 5;

// gif export
boolean gifExporting     = false;
int     gifExportFrame   = 0;
int     gifExportFrames  = 0;
int     gifExportTotal   = 0;
int     gifExportDelay   = 50;
boolean gifExportIsPulse = false;
byte[]  gifExportDirs    = null;

// app states
enum AppState { PLAYGROUND, CALCULATING, GALLERY, ERROR }
volatile AppState currentState = AppState.PLAYGROUND;
String errorMessage = "";

// presets
class Preset {
  String name; String signature; int startDir;
  Preset(String name, String signature, int startDir) {
    this.name = name; this.signature = signature; this.startDir = startDir;
  }
}

ArrayList<Preset> presets = new ArrayList<Preset>();

// solve states
String customSignature     = "";
String baseSignature       = "";
int    currentPatternStartDir = 0;

HashMap<Long, ArrayList<Edge>> adjList = new HashMap<>();
int   totalEdges  = 0;
long  targetMask  = 0L;

int     numNodes;
int[]   numEdges;
int[][] neighborTarget;
int[][] neighborEdgeId;
int[][] neighborDir;
ArrayList<Integer> startNodeIndices = new ArrayList<>();

HashSet<String>           seenPermutations = new HashSet<>();
final ArrayList<byte[]>   totalGallery     = new ArrayList<byte[]>();

volatile boolean cancelSolver = false;
Thread           solverThread  = null;

final AtomicInteger totalPathsFound     = new AtomicInteger(0);
final AtomicLong    branchesChecked     = new AtomicLong(0L);
final AtomicLong    illegalUTurnsSkipped = new AtomicLong(0L);

// gallery
int   galleryIndex   = 0;
float currentStep    = 0;
float pulseProgress  = 0;

boolean gotoInputActive  = false;
String  gotoInputBuffer  = "";

boolean scrubberDragging = false;
int     sliderDragging   = DRAG_NONE;

// panels
int   openPanel  = 0;
float panelSlide = 0f;

// rendering options
final int BUILTIN_PALETTE_COUNT = 3;

class CustomPalette {
  String name;
  float startH, startS, startB;
  float endH,   endS,   endB;
}
ArrayList<CustomPalette> customPalettes = new ArrayList<CustomPalette>();

int     currentPalette  = 0;
boolean paletteReversed = false;
boolean arcMode         = false;
boolean gridDotsMode    = true;
float   traceSpeed      = 0.4f;
float   pulseSpeed      = 0.04f;
float   gradientCycle   = 0.0f;
float   strokeWidthBase = 5.0f;
float   arcInset        = 0.40f;

boolean gifUncapped       = false;
boolean showExportMarkers = false;

boolean showBackground = false;
float   bgColorH = 0f, bgColorS = 0f, bgColorB = 100f;
volatile boolean bgPickerOpen   = false;
volatile boolean pendingBgReady = false;
volatile float   pendingBgH = 0, pendingBgS = 0, pendingBgB = 100;

boolean cleanupConfirmOpen = false;

boolean presetModalOpen = false;
String  newPresetName   = "";

// palette modal
boolean newPaletteModalOpen  = false;
int     editingPaletteIndex  = -1;
String  newPaletteName       = "";
float   newPaletteStartH = 220, newPaletteStartS = 90, newPaletteStartB = 100;
float   newPaletteEndH   =   0, newPaletteEndS   = 90, newPaletteEndB   = 100;

// colorchooser
volatile int   pendingPickedColor = -1;
volatile float pendingPickedH = 0, pendingPickedS = 0, pendingPickedB = 0;
volatile boolean colorPickerOpen = false;
int colorPickTarget = 0;

// cursor state
int   cursorPos    = 0;
float inputScrollX = 0f;
int wantedCursor = ARROW;
int activeCursor = ARROW;

// playground
ArrayList<Byte> drawPath      = new ArrayList<Byte>();
HashSet<String> drawUsedEdges = new HashSet<String>();
int[]   drawStartAxial  = {0, 0};
int[]   drawEndAxial    = {0, 0};
int     drawExtendSide  = 0;
boolean drawDragging    = false;
boolean drawPanning     = false;
boolean pendingRestart      = false;
int[]   pendingRestartAxial = {0, 0};
float   drawPanStartMX  = 0f;
float   drawPanStartMY  = 0f;
float   drawPanStartVX  = 0f;
float   drawPanStartVY  = 0f;
float   drawViewX       = 0f;
float   drawViewY       = 0f;
float   drawViewScale   = 1.0f;
float   drawTargetX     = 0f;
float   drawTargetY     = 0f;
float   drawTargetScale = 1.0f;
final float DRAW_LERP_SPEED = 0.12f;

PFont monoFont;

// notification stuff
ArrayList<AppNotification> notifQueue = new ArrayList<AppNotification>();

// graph helpers
final int[][] DIR_OFFSETS = {{1,0},{0,1},{-1,1},{-1,0},{0,-1},{1,-1}};

class Edge {
  long target; int edgeId; int dir;
  Edge(long target, int edgeId, int dir) {
    this.target = target; this.edgeId = edgeId; this.dir = dir;
  }
}

long packQR(int q, int r)  { return ((long)q << 32) | (r & 0xFFFFFFFFL); }
int  unpackQ(long k)       { return (int)(k >> 32); }
int  unpackR(long k)       { return (int)(k & 0xFFFFFFFFL); }

// sketch
void settings() {
  int[] wh = readSavedWindowSize();
  size(wh[0], wh[1]);
  pixelDensity(1);
}

void setup() {
  frameRate(60);
  surface.setTitle("hexdraw");
  surface.setResizable(true);
  new java.io.File(exportsDir()).mkdirs();
  initExportCounter();
  loadConfig();
  monoFont = createFont("Monospaced", 1);
  centerDrawViewOnPath();

  javax.swing.SwingUtilities.invokeLater(() -> {
    Object nat = getSurface().getNative();
    if (nat instanceof java.awt.Component) {
      java.awt.Window win = javax.swing.SwingUtilities.getWindowAncestor((java.awt.Component) nat);
      if (win instanceof javax.swing.JFrame) {
        sketchFrame = (javax.swing.JFrame) win;
        sketchFrame.setMinimumSize(new java.awt.Dimension(700, 500));
        if (windowX >= 0 && windowY >= 0 && isPositionOnScreen(windowX, windowY, windowW, windowH)) {
          sketchFrame.setLocation(windowX, windowY);
        }
        sketchFrame.addWindowListener(new java.awt.event.WindowAdapter() {
          public void windowClosing(java.awt.event.WindowEvent e) { saveWindowGeometry(); }
        });
      }
    }
  });
}

void exit() {
  if (!exitCleanup) saveWindowGeometry();
  super.exit();
}

void draw() {
  if (pendingBgReady) {
    bgColorH = pendingBgH; bgColorS = pendingBgS; bgColorB = pendingBgB;
    pendingBgReady = false;
  }

  if (pendingPickedColor >= 0) {
    if (pendingPickedColor == 0) {
      newPaletteStartH = pendingPickedH;
      newPaletteStartS = pendingPickedS;
      newPaletteStartB = pendingPickedB;
    } else {
      newPaletteEndH = pendingPickedH;
      newPaletteEndS = pendingPickedS;
      newPaletteEndB = pendingPickedB;
    }
    pendingPickedColor = -1;
  }

  background(20, 20, 25);
  wantedCursor = ARROW;

  panelSlide = lerp(panelSlide, openPanel > 0 ? 1f : 0f, PANEL_ANIM_SPEED);

  if      (currentState == AppState.PLAYGROUND) drawPlayground();
  else if (currentState == AppState.ERROR)      drawErrorScreen();
  else                                          drawGalleryInterface();

  if (cleanupConfirmOpen)  drawCleanupConfirmModal();
  if (presetModalOpen)     drawPresetModal();
  if (newPaletteModalOpen) drawNewPaletteModal();
  drawNotifications();

  if (gifExporting) { tickGifExport(); drawGifProgressOverlay(); }

  String stateLabel = (currentState == AppState.GALLERY || currentState == AppState.CALCULATING)
    ? "gallery" : "playground";
  surface.setTitle("hexdraw - " + stateLabel);

  if (wantedCursor != activeCursor) { cursor(wantedCursor); activeCursor = wantedCursor; }
}
