void startDecoding(String sig, int startDirIdx) {
  cancelSolver = true;
  if (solverThread != null && solverThread.isAlive()) {
    try { solverThread.join(5000); } catch (InterruptedException ignored) {}
  }
  cancelSolver = false;

  baseSignature = sig;
  currentPatternStartDir = startDirIdx;

  adjList.clear();
  startNodeIndices.clear();
  seenPermutations.clear();
  synchronized(totalGallery) { totalGallery.clear(); }

  totalPathsFound.set(0);
  branchesChecked.set(0L);
  illegalUTurnsSkipped.set(0L);
  galleryIndex = 0;
  resetAnimation();

  String buildErr = buildGraph(baseSignature);
  if (buildErr != null) {
    showError(buildErr);
    return;
  }

  if (totalEdges > MAX_EDGES) {
    showError("Signature requires " + totalEdges + " edges, but the solver uses a 64-bit edge bitmask " +
              "and supports at most " + MAX_EDGES + " unique edges. Try a shorter pattern.");
    return;
  }
  if (totalEdges == 0) {
    showError("Signature produced zero edges. Nothing to decode.");
    return;
  }

  flattenGraph();
  currentState = AppState.CALCULATING;
  solverThread = new Thread(() -> runSolverBackground());
  solverThread.setDaemon(true);
  solverThread.start();
}

void resetAnimation() {
  currentStep   = 0.0f;
  pulseProgress = 0.0f;
}

void runSolverBackground() {
  int[] pathBuffer = new int[totalEdges + 1];
  for (int startNode : startNodeIndices) {
    if (cancelSolver || currentState == AppState.PLAYGROUND) break;
    backtrackDFS(startNode, 0L, pathBuffer, 0);
  }

  if (illegalUTurnsSkipped.get() > 0)
    println("Solver finished. Skipped " + illegalUTurnsSkipped.get() + " path(s) with illegal 180° turns.");

  // Sort gallery by signature string so index N always refers to the same
  // permutation regardless of which starting direction was used for input.
  if (!cancelSolver && currentState != AppState.PLAYGROUND) {
    synchronized(totalGallery) {
      if (totalGallery.size() > 1) {
        final byte[][] arr = totalGallery.toArray(new byte[0][]);
        java.util.Arrays.sort(arr, new java.util.Comparator<byte[]>() {
          public int compare(byte[] x, byte[] y) {
            return bytesToSignature(x).compareTo(bytesToSignature(y));
          }
        });
        totalGallery.clear();
        for (byte[] p : arr) totalGallery.add(p);
      }
      // Open at the input signature's position in the sorted results.
      galleryIndex = 0;
      for (int i = 0; i < totalGallery.size(); i++) {
        if (bytesToSignature(totalGallery.get(i)).equals(baseSignature)) {
          galleryIndex = i; break;
        }
      }
    }
  }

  // Write file in the same order as the gallery so line N == gallery index N.
  synchronized(totalGallery) {
    PrintWriter out = createWriter(sketchPath("hex_spells.txt"));
    out.println("# Hexcasting Decoder Outputs Sequence: " + baseSignature);
    for (byte[] p : totalGallery) out.println(bytesToSignature(p));
    out.flush();
    out.close();
  }

  if (!cancelSolver && currentState == AppState.CALCULATING) currentState = AppState.GALLERY;
}

void backtrackDFS(int u, long mask, int[] path, int depth) {
  if (cancelSolver || currentState == AppState.PLAYGROUND) return;

  if (mask == targetMask) {
    String sigString = dirsToSignatureSafe(path, depth);
    if (sigString == null) { illegalUTurnsSkipped.incrementAndGet(); return; }
    if (!seenPermutations.contains(sigString)) {
      seenPermutations.add(sigString);
      totalPathsFound.incrementAndGet();
      byte[] packedPath = new byte[depth];
      for (int i = 0; i < depth; i++) packedPath[i] = (byte)path[i];
      synchronized(totalGallery) { totalGallery.add(packedPath); }
    }
    return;
  }

  int count      = numEdges[u];
  int[] targets  = neighborTarget[u];
  int[] edgeIds  = neighborEdgeId[u];
  int[] dirs     = neighborDir[u];

  for (int i = 0; i < count; i++) {
    int eId = edgeIds[i];
    if ((mask & (1L << eId)) == 0L) {
      path[depth] = dirs[i];
      branchesChecked.incrementAndGet();
      backtrackDFS(targets[i], mask | (1L << eId), path, depth + 1);
    }
  }
}

void flattenGraph() {
  numNodes = adjList.size();

  Long[] boxed = adjList.keySet().toArray(new Long[0]);
  Arrays.sort(boxed);
  long[] nodeKeys = new long[boxed.length];
  for (int i = 0; i < boxed.length; i++) nodeKeys[i] = boxed[i];

  HashMap<Long, Integer> nodeToIndex = new HashMap<>();
  for (int i = 0; i < numNodes; i++) nodeToIndex.put(nodeKeys[i], i);

  numEdges       = new int[numNodes];
  neighborTarget = new int[numNodes][];
  neighborEdgeId = new int[numNodes][];
  neighborDir    = new int[numNodes][];

  for (int i = 0; i < numNodes; i++) {
    ArrayList<Edge> edges = adjList.get(nodeKeys[i]);
    edges.sort((a, b) -> Integer.compare(a.edgeId, b.edgeId));
    int count = edges.size();
    numEdges[i]       = count;
    neighborTarget[i] = new int[count];
    neighborEdgeId[i] = new int[count];
    neighborDir[i]    = new int[count];
    for (int e = 0; e < count; e++) {
      Edge edge = edges.get(e);
      neighborTarget[i][e] = nodeToIndex.get(edge.target);
      neighborEdgeId[i][e] = edge.edgeId;
      neighborDir[i][e]    = edge.dir;
    }
  }

  for (int i = 0; i < numNodes; i++) {
    if (numEdges[i] % 2 != 0) startNodeIndices.add(i);
  }
  if (startNodeIndices.isEmpty()) {
    for (int i = 0; i < numNodes; i++) startNodeIndices.add(i);
  }
}

int sigCharToTurn(char c) {
  switch (c) {
    case 'w': return 0;
    case 'e': return 1;
    case 'd': return 2;
    case 'a': return 4;
    case 'q': return 5;
    default:  return -1;
  }
}

String buildGraph(String sig) {
  int q = 0, r = 0;
  int currentAbsDir = 0;
  ArrayList<Integer> tempDirs = new ArrayList<>();
  tempDirs.add(currentAbsDir);

  for (int i = 0; i < sig.length(); i++) {
    char c = sig.charAt(i);
    int turn = sigCharToTurn(c);
    if (turn < 0) return "Signature contains an invalid character: '" + c + "' (allowed: a q w e d).";
    currentAbsDir = (currentAbsDir + turn) % 6;
    tempDirs.add(currentAbsDir);
  }

  ArrayList<Long> coords = new ArrayList<>();
  coords.add(packQR(0, 0));
  for (int d : tempDirs) {
    q += DIR_OFFSETS[d][0]; r += DIR_OFFSETS[d][1];
    coords.add(packQR(q, r));
  }

  HashSet<String> seenEdgeKeys = new HashSet<>();
  int edgeId = 0;
  for (int i = 0; i < tempDirs.size(); i++) {
    long n1 = coords.get(i);
    long n2 = coords.get(i + 1);
    int  d  = tempDirs.get(i);
    String edgeKey = edgeKeyFor(n1, n2);
    if (!seenEdgeKeys.add(edgeKey)) {
      int step = i + 1;
      return "Invalid pattern: the input traverses the same edge more than once " +
             "(step " + step + " repeats an earlier edge). Hexcasting patterns must traverse each edge at most once.";
    }
    adjList.putIfAbsent(n1, new ArrayList<Edge>());
    adjList.putIfAbsent(n2, new ArrayList<Edge>());
    adjList.get(n1).add(new Edge(n2, edgeId, d));
    adjList.get(n2).add(new Edge(n1, edgeId, (d + 3) % 6));
    edgeId++;
  }
  totalEdges = edgeId;
  targetMask = (totalEdges >= 64) ? -1L : (1L << totalEdges) - 1L;
  return null;
}

String edgeKeyFor(long a, long b) {
  long lo = Math.min(a, b);
  long hi = Math.max(a, b);
  return lo + "," + hi;
}

String dirsToSignatureSafe(int[] dirs, int length) {
  StringBuilder sig = new StringBuilder(length);
  char[] turns = {'w', 'e', 'd', '_', 'a', 'q'};
  for (int i = 1; i < length; i++) {
    int diff = (dirs[i] - dirs[i-1] + 6) % 6;
    if (diff == 3) return null;
    sig.append(turns[diff]);
  }
  return sig.toString();
}

String bytesToSignature(byte[] dirs) {
  StringBuilder sig = new StringBuilder(dirs.length);
  char[] turns = {'w', 'e', 'd', '?', 'a', 'q'};
  for (int i = 1; i < dirs.length; i++) {
    int diff = (dirs[i] - dirs[i-1] + 6) % 6;
    sig.append(turns[diff]);
  }
  return sig.toString();
}

int firstInvalidIndex(String sig) {
  if (sig == null || sig.length() == 0) return -1;

  int cq = 0, cr = 0;
  int currentAbsDir = 0;

  ArrayList<Integer> tempDirs = new ArrayList<>();
  tempDirs.add(currentAbsDir);

  for (int i = 0; i < sig.length(); i++) {
    char c = sig.charAt(i);
    int turn = sigCharToTurn(c);
    if (turn < 0) return i;
    currentAbsDir = (currentAbsDir + turn) % 6;
    tempDirs.add(currentAbsDir);
  }

  ArrayList<Long> coords = new ArrayList<>();
  coords.add(packQR(0, 0));
  for (int d : tempDirs) {
    cq += DIR_OFFSETS[d][0]; cr += DIR_OFFSETS[d][1];
    coords.add(packQR(cq, cr));
  }

  HashSet<String> seenEdgeKeys = new HashSet<>();
  for (int i = 0; i < tempDirs.size(); i++) {
    long n1 = coords.get(i);
    long n2 = coords.get(i + 1);
    String edgeKey = edgeKeyFor(n1, n2);
    if (!seenEdgeKeys.add(edgeKey)) {
      return Math.max(0, i - 1);
    }
  }
  return -1;
}

String sigFromDrawPath() {
  if (drawPath.size() <= 1) return "";
  char[] t = {'w', 'e', 'd', '?', 'a', 'q'};
  StringBuilder sb = new StringBuilder();
  for (int i = 1; i < drawPath.size(); i++) {
    int diff = (drawPath.get(i) - drawPath.get(i-1) + 6) % 6;
    sb.append(t[diff]);
  }
  return sb.toString();
}

boolean loadSigToDrawPath(String sig) {
  drawPath.clear();
  drawUsedEdges.clear();
  drawStartAxial[0] = 0; drawStartAxial[1] = 0;
  drawEndAxial[0]   = 0; drawEndAxial[1]   = 0;
  if (sig == null || sig.length() == 0) return true;

  ArrayList<Byte> newPath = new ArrayList<Byte>();
  int startDir = ((currentPatternStartDir % 6) + 6) % 6;
  newPath.add((byte) startDir); // initial direction matches current visual rotation
  int absDir = startDir;
  for (int i = 0; i < sig.length(); i++) {
    char c = sig.charAt(i);
    int turn = sigCharToTurn(c);
    if (turn < 0) return false;
    absDir = (absDir + turn) % 6;
    newPath.add((byte) absDir);
  }

  int q = 0, r = 0;
  for (int i = 0; i < newPath.size(); i++) {
    int d  = newPath.get(i);
    int nq = q + DIR_OFFSETS[d][0];
    int nr = r + DIR_OFFSETS[d][1];
    String ek = edgeKeyFor(packQR(q, r), packQR(nq, nr));
    if (!drawUsedEdges.add(ek)) return false;
    q = nq; r = nr;
  }
  drawPath = newPath;
  drawEndAxial[0] = q; drawEndAxial[1] = r;
  return true;
}
