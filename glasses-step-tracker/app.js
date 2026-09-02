(function() {
  'use strict';

  // ==================== CONFIG ====================
  var CONFIG = {
    appName: 'Wander',
    storageKey: 'mdg_wander_steps',
    dailyGoal: 6000,
    strideMeters: 0.762,
    stepThreshold: 1.2,       // m/s^2 delta above filtered baseline to count as a step
    minStepIntervalMs: 280,   // debounce between steps (~3.6 steps/sec cap)
    demoFallbackMs: 1500,     // if no motion events land in this window, switch to demo mode
    demoStepIntervalMs: 900,
    leafCount: 8,
    leafGlyphs: ['\u{1F342}', '\u{1F343}', '\u{1F341}'], // fallen leaf, leaf fluttering, maple leaf
    glowStepMin: 15,          // a Glow orb spawns after this many-to-glowStepMax new steps
    glowStepMax: 35,
    glowOrbSize: 56,
  };

  // ==================== STATE ====================
  var state = {
    currentScreen: 'home',
    screenHistory: [],
    isLoading: false,
    error: null,
    data: { history: {}, glow: 0 },
    cache: {},
    tracking: false,
    demoMode: false,
    activeOrb: null,
    nextGlowTarget: 0,
  };

  var motion = {
    filtered: null,
    lastStepAt: 0,
    watchdogTimer: null,
    demoTimer: null,
    handler: null,
  };

  // ==================== DOM REFS ====================
  var screens = {};

  function collectScreens() {
    document.querySelectorAll('.screen').forEach(function(s) {
      if (s.id) screens[s.id] = s;
    });
  }

  // ==================== NAVIGATION ====================
  function navigateTo(screenId, options) {
    options = options || {};
    var addToHistory = options.addToHistory !== false;

    if (state.currentScreen === 'home' && screenId !== 'home' && state.tracking) {
      stopTracking();
      showToast('Tracking paused');
    }

    if (addToHistory && state.currentScreen) {
      state.screenHistory.push(state.currentScreen);
    }

    Object.values(screens).forEach(function(s) { s.classList.add('hidden'); });
    if (screens[screenId]) {
      screens[screenId].classList.remove('hidden');
      state.currentScreen = screenId;
      onScreenEnter(screenId);
      focusFirst(screens[screenId]);
    }
  }

  function navigateBack() {
    if (state.screenHistory.length > 0) {
      navigateTo(state.screenHistory.pop(), { addToHistory: false });
    }
  }

  // ==================== FOCUS MANAGEMENT ====================
  function focusFirst(container) {
    var el = container.querySelector('.focusable:not([disabled]):not(.hidden)');
    if (el) el.focus();
  }

  function moveFocus(direction) {
    var container = screens[state.currentScreen];
    if (!container) return;

    var focusables = Array.from(
      container.querySelectorAll('.focusable:not([disabled]):not(.hidden)')
    );
    if (focusables.length === 0) return;

    var current = document.activeElement;
    var idx = focusables.indexOf(current);

    if (idx === -1) {
      focusFirst(container);
      return;
    }

    var nextIdx;
    if (direction === 'up' || direction === 'left') {
      nextIdx = idx > 0 ? idx - 1 : focusables.length - 1;
    } else {
      nextIdx = idx < focusables.length - 1 ? idx + 1 : 0;
    }
    focusables[nextIdx].focus();

    var scrollParent = focusables[nextIdx].closest('.content, .list-container');
    if (scrollParent) {
      focusables[nextIdx].scrollIntoView({ block: 'nearest', behavior: 'smooth' });
    }
  }

  // ==================== UI HELPERS ====================
  function setError(message) {
    state.error = message;
    var errorEl = document.getElementById('error');
    if (errorEl) {
      errorEl.classList.remove('hidden');
      var msgEl = errorEl.querySelector('.error-message');
      if (msgEl) msgEl.textContent = message;
    }
  }

  function clearError() {
    state.error = null;
    var errorEl = document.getElementById('error');
    if (errorEl) errorEl.classList.add('hidden');
  }

  function showToast(message, type) {
    var toast = document.getElementById('toast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'toast';
      toast.className = 'toast';
      document.body.appendChild(toast);
    }
    toast.textContent = message;
    toast.className = 'toast' + (type ? ' ' + type : '');
    toast.offsetHeight;
    toast.classList.add('visible');
    setTimeout(function() { toast.classList.remove('visible'); }, 2500);
  }

  // ==================== DATA PERSISTENCE ====================
  function todayKey() {
    var d = new Date();
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0');
  }

  function loadData() {
    try {
      var saved = localStorage.getItem(CONFIG.storageKey);
      if (saved) {
        var parsed = JSON.parse(saved);
        if (parsed && parsed.history) state.data.history = parsed.history;
        if (parsed && typeof parsed.glow === 'number') state.data.glow = parsed.glow;
      }
    } catch (e) {
      console.error('[Storage] Load error:', e);
    }
    if (!state.data.history[todayKey()]) {
      state.data.history[todayKey()] = 0;
    }
  }

  function saveData() {
    try {
      localStorage.setItem(CONFIG.storageKey, JSON.stringify(state.data));
    } catch (e) {
      console.error('[Storage] Save error:', e);
    }
  }

  function todaySteps() {
    return state.data.history[todayKey()] || 0;
  }

  function addStep() {
    var key = todayKey();
    state.data.history[key] = (state.data.history[key] || 0) + 1;
    saveData();
    updateStepDisplay();

    if (state.tracking && !state.activeOrb && todaySteps() >= state.nextGlowTarget) {
      spawnGlowOrb();
    }
  }

  // ==================== GLOW ORB ====================
  function scheduleNextGlowTarget() {
    var span = CONFIG.glowStepMax - CONFIG.glowStepMin;
    state.nextGlowTarget = todaySteps() + CONFIG.glowStepMin + Math.floor(Math.random() * span);
  }

  function spawnGlowOrb() {
    var homeEl = screens.home;
    if (!homeEl || state.activeOrb) return;

    var size = CONFIG.glowOrbSize;
    var minLeft = 20, maxLeft = 600 - size - 20;
    var minTop = 140, maxTop = 420;

    var orb = document.createElement('div');
    orb.className = 'glow-orb focusable';
    orb.tabIndex = 0;
    orb.dataset.action = 'collect-glow';
    orb.setAttribute('aria-label', 'Glow orb');
    orb.style.left = (minLeft + Math.random() * (maxLeft - minLeft)) + 'px';
    orb.style.top = (minTop + Math.random() * (maxTop - minTop)) + 'px';

    homeEl.appendChild(orb);
    state.activeOrb = orb;
  }

  function removeActiveOrb() {
    if (state.activeOrb && state.activeOrb.parentNode) {
      state.activeOrb.parentNode.removeChild(state.activeOrb);
    }
    state.activeOrb = null;
  }

  function collectGlow(orbEl) {
    state.data.glow = (state.data.glow || 0) + 1;
    saveData();
    updateGlowDisplay();
    showToast('+1 Glow', 'success');

    if (orbEl) {
      orbEl.classList.add('collected');
      setTimeout(function() {
        if (orbEl.parentNode) orbEl.parentNode.removeChild(orbEl);
      }, 260);
    }
    state.activeOrb = null;
    scheduleNextGlowTarget();
  }

  // ==================== LEAVES ====================
  function initLeafLayer() {
    var layer = document.getElementById('leaf-layer');
    if (!layer) return;

    for (var i = 0; i < CONFIG.leafCount; i++) {
      var leaf = document.createElement('span');
      var duration = 8 + Math.random() * 6;
      leaf.className = 'leaf';
      leaf.textContent = CONFIG.leafGlyphs[i % CONFIG.leafGlyphs.length];
      leaf.style.left = (Math.random() * 92) + '%';
      leaf.style.fontSize = (16 + Math.random() * 12) + 'px';
      leaf.style.animationDuration = duration + 's';
      leaf.style.animationDelay = '-' + (Math.random() * duration) + 's';
      layer.appendChild(leaf);
    }
  }

  function setLeavesActive(active) {
    var layer = document.getElementById('leaf-layer');
    if (layer) layer.classList.toggle('active', active);
  }

  // ==================== STEP DETECTION ====================
  function handleMotion(event) {
    var a = event.accelerationIncludingGravity || event.acceleration;
    if (!a || a.x === null) return;

    clearTimeout(motion.watchdogTimer);

    var magnitude = Math.sqrt(
      (a.x || 0) * (a.x || 0) +
      (a.y || 0) * (a.y || 0) +
      (a.z || 0) * (a.z || 0)
    );

    if (motion.filtered === null) {
      motion.filtered = magnitude;
      return;
    }

    var alpha = 0.9;
    motion.filtered = alpha * motion.filtered + (1 - alpha) * magnitude;
    var delta = magnitude - motion.filtered;

    var now = Date.now();
    if (delta > CONFIG.stepThreshold && now - motion.lastStepAt > CONFIG.minStepIntervalMs) {
      motion.lastStepAt = now;
      addStep();
    }
  }

  function startDemoMode() {
    if (state.demoMode) return;
    state.demoMode = true;
    setStatus('Demo mode');
    motion.demoTimer = setInterval(function() {
      if (!state.tracking) return;
      addStep();
    }, CONFIG.demoStepIntervalMs);
  }

  function stopDemoMode() {
    state.demoMode = false;
    clearInterval(motion.demoTimer);
    motion.demoTimer = null;
  }

  function startTracking() {
    function attach() {
      motion.filtered = null;
      motion.handler = handleMotion;
      window.addEventListener('devicemotion', motion.handler);

      motion.watchdogTimer = setTimeout(function() {
        startDemoMode();
      }, CONFIG.demoFallbackMs);

      state.tracking = true;
      setStatus('Walking');
      var btn = document.getElementById('toggle-btn');
      if (btn) btn.textContent = 'Stop';
      clearError();
      setLeavesActive(true);
      scheduleNextGlowTarget();
    }

    if (typeof DeviceMotionEvent === 'undefined') {
      state.tracking = true;
      setStatus('Demo mode');
      var btn = document.getElementById('toggle-btn');
      if (btn) btn.textContent = 'Stop';
      setLeavesActive(true);
      scheduleNextGlowTarget();
      startDemoMode();
      return;
    }

    if (typeof DeviceMotionEvent.requestPermission === 'function') {
      DeviceMotionEvent.requestPermission()
        .then(function(result) {
          if (result === 'granted') {
            attach();
          } else {
            setError('Motion permission denied');
          }
        })
        .catch(function() {
          setError('Motion permission unavailable');
        });
    } else {
      attach();
    }
  }

  function stopTracking() {
    state.tracking = false;
    clearTimeout(motion.watchdogTimer);
    if (motion.handler) {
      window.removeEventListener('devicemotion', motion.handler);
      motion.handler = null;
    }
    stopDemoMode();
    setStatus('Idle');
    var btn = document.getElementById('toggle-btn');
    if (btn) btn.textContent = 'Start';
    setLeavesActive(false);
    removeActiveOrb();
  }

  function setStatus(text) {
    var el = document.getElementById('status-indicator');
    if (el) el.textContent = text;
  }

  // ==================== RENDERING ====================
  function updateStepDisplay() {
    var steps = todaySteps();
    var countEl = document.getElementById('step-count');
    if (countEl) countEl.textContent = steps.toLocaleString();

    var goalEl = document.getElementById('goal-label');
    if (goalEl) goalEl.textContent = 'Goal: ' + CONFIG.dailyGoal.toLocaleString();

    var progressEl = document.getElementById('goal-progress');
    if (progressEl) {
      var pct = Math.min(100, (steps / CONFIG.dailyGoal) * 100);
      progressEl.style.width = pct + '%';
    }

    var distanceKm = (steps * CONFIG.strideMeters) / 1000;
    var distEl = document.getElementById('distance-value');
    if (distEl) distEl.innerHTML = distanceKm.toFixed(1) + '<span class="unit">km</span>';

    updateGlowDisplay();
  }

  function updateGlowDisplay() {
    var glowEl = document.getElementById('glow-value');
    if (glowEl) glowEl.innerHTML = (state.data.glow || 0).toLocaleString() + '<span class="unit">Glow</span>';
  }

  function renderHistory() {
    var container = document.getElementById('history-list');
    if (!container) return;

    var days = Object.keys(state.data.history).sort().reverse();
    if (days.length === 0) {
      container.innerHTML = '<div class="error-container"><div class="error-message">No history yet</div></div>';
      return;
    }

    container.innerHTML = days.map(function(day) {
      var steps = state.data.history[day];
      var metGoal = steps >= CONFIG.dailyGoal;
      var badgeClass = metGoal ? 'badge-success' : 'badge-info';
      var label = day === todayKey() ? 'Today' : day;
      return (
        '<div class="list-item focusable" tabindex="0">' +
          '<span class="list-item-icon">&#128099;</span>' +
          '<div class="list-item-content">' +
            '<div class="list-item-title">' + label + '</div>' +
            '<div class="list-item-meta">' + steps.toLocaleString() + ' steps</div>' +
          '</div>' +
          '<span class="list-item-badge ' + badgeClass + '">' + (metGoal ? 'Goal met' : Math.round((steps / CONFIG.dailyGoal) * 100) + '%') + '</span>' +
        '</div>'
      );
    }).join('');
  }

  // ==================== ACTION HANDLING ====================
  function handleAction(action, element) {
    switch (action) {
      case 'back':
        navigateBack();
        break;
      default:
        handleAppAction(action, element);
        break;
    }
  }

  function handleAppAction(action, element) {
    switch (action) {
      case 'toggle-tracking':
        if (state.tracking) {
          stopTracking();
        } else {
          startTracking();
        }
        break;
      case 'view-history':
        navigateTo('history');
        break;
      case 'reset-today':
        state.data.history[todayKey()] = 0;
        saveData();
        updateStepDisplay();
        showToast('Today reset');
        break;
      case 'collect-glow':
        collectGlow(element);
        break;
      default:
        console.log('[Action]', action);
    }
  }

  function onScreenEnter(screenId) {
    if (screenId === 'home') {
      updateStepDisplay();
    } else if (screenId === 'history') {
      renderHistory();
    }
  }

  // ==================== EVENT LISTENERS ====================
  function setupEvents() {
    document.addEventListener('click', function(e) {
      var actionEl = e.target.closest('[data-action]');
      if (actionEl) handleAction(actionEl.dataset.action, actionEl);
    });

    document.addEventListener('keydown', function(e) {
      var isInput = document.activeElement &&
        (document.activeElement.tagName === 'INPUT' ||
         document.activeElement.tagName === 'TEXTAREA');
      if (isInput && !['Escape', 'Enter'].includes(e.key)) {
        return;
      }

      switch (e.key) {
        case 'ArrowUp':
          moveFocus('up');
          e.preventDefault();
          break;
        case 'ArrowDown':
          moveFocus('down');
          e.preventDefault();
          break;
        case 'ArrowLeft':
          moveFocus('left');
          e.preventDefault();
          break;
        case 'ArrowRight':
          moveFocus('right');
          e.preventDefault();
          break;
        case 'Enter':
          if (document.activeElement && document.activeElement.classList.contains('focusable')) {
            document.activeElement.click();
          }
          e.preventDefault();
          break;
        case 'Escape':
          navigateBack();
          e.preventDefault();
          break;
      }
    });

    document.addEventListener('visibilitychange', function() {
      if (document.hidden && state.tracking) {
        stopTracking();
      }
    });
  }

  // ==================== INITIALIZATION ====================
  function init() {
    collectScreens();
    setupEvents();
    loadData();
    initLeafLayer();

    setTimeout(function() {
      navigateTo('home', { addToHistory: false });
    }, 100);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
