// notification engine

class AppNotification {
  String message;
  int    spawnFrame;
  int    duration;
  int    type;
  boolean persistent;
  String  persistentId;

  AppNotification(String msg, int dur, int t) {
    message = msg; spawnFrame = frameCount; duration = dur; type = t;
  }
}

// api

void notify(String msg) {
  notify(msg, 120, NOTIF_INFO);
}

void notify(String msg, int duration, int type) {
  // Avoid duplicate non-persistent messages spamming the queue.
  for (AppNotification n : notifQueue) {
    if (!n.persistent && n.message.equals(msg)) {
      n.spawnFrame = frameCount; // reset timer
      return;
    }
  }
  notifQueue.add(new AppNotification(msg, duration, type));
}

void notifyPersistent(String id, String msg, int type) {
  for (AppNotification n : notifQueue) {
    if (n.persistent && id.equals(n.persistentId)) {
      n.message = msg;
      return;
    }
  }
  AppNotification n = new AppNotification(msg, 0, type);
  n.persistent    = true;
  n.persistentId  = id;
  notifQueue.add(n);
}

void dismissPersistent(String id) {
  for (int i = notifQueue.size() - 1; i >= 0; i--) {
    AppNotification n = notifQueue.get(i);
    if (n.persistent && id.equals(n.persistentId)) {
      notifQueue.remove(i);
      return;
    }
  }
}

// renderer

void drawNotifications() {
  // Expire timed-out non-persistent notifications.
  for (int i = notifQueue.size() - 1; i >= 0; i--) {
    AppNotification n = notifQueue.get(i);
    if (!n.persistent && frameCount - n.spawnFrame >= n.duration) {
      notifQueue.remove(i);
    }
  }
  if (notifQueue.isEmpty()) return;

  float toastW   = 320 * UI_TEXT_SCALE;
  float toastH   = 34 * UI_TEXT_SCALE;
  float gapY     = 6;
  float baseY    = 14 * UI_TEXT_SCALE; // top edge of top-most toast

  textSize(12 * UI_TEXT_SCALE);
  textAlign(CENTER, CENTER);

  for (int j = 0; j < notifQueue.size(); j++) {
    AppNotification n = notifQueue.get(j);

    float toastY = baseY + j * (toastH + gapY);
    float toastX = width / 2f - toastW / 2f;

    // Compute alpha
    float alpha = 255;
    if (!n.persistent) {
      int elapsed   = frameCount - n.spawnFrame;
      int fadeStart = (n.duration * 2) / 3;
      if (elapsed > fadeStart) alpha = map(elapsed, fadeStart, n.duration, 255, 0);
    }

    // Type colors
    int[] bgRGB, borderRGB, fgRGB;
    if (n.type == NOTIF_SUCCESS) {
      bgRGB     = new int[]{30, 80, 50};
      borderRGB = new int[]{100, 255, 150};
      fgRGB     = new int[]{180, 255, 200};
    } else if (n.type == NOTIF_WARN) {
      bgRGB     = new int[]{70, 55, 15};
      borderRGB = new int[]{255, 200, 80};
      fgRGB     = new int[]{255, 230, 160};
    } else if (n.type == NOTIF_ERROR) {
      bgRGB     = new int[]{70, 18, 22};
      borderRGB = new int[]{255, 80, 100};
      fgRGB     = new int[]{255, 150, 160};
    } else { // INFO
      bgRGB     = new int[]{18, 35, 65};
      borderRGB = new int[]{80, 160, 255};
      fgRGB     = new int[]{150, 205, 255};
    }

    noStroke();
    fill(bgRGB[0], bgRGB[1], bgRGB[2], alpha);
    rect(toastX, toastY, toastW, toastH, 6);

    stroke(borderRGB[0], borderRGB[1], borderRGB[2], alpha);
    strokeWeight(1.5f); noFill();
    rect(toastX, toastY, toastW, toastH, 6);

    noStroke();
    fill(fgRGB[0], fgRGB[1], fgRGB[2], alpha);
    text(n.message, width / 2f, toastY + toastH / 2f - 1);
  }
}
