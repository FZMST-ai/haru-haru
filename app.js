(() => {
  'use strict';

  const STORE_KEY = 'haruharu:v1';
  const $ = (sel) => document.querySelector(sel);

  // ---- Dates (local time, YYYY-MM-DD) ----
  const pad = (n) => String(n).padStart(2, '0');
  const keyOf = (d) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
  const today = () => keyOf(new Date());
  const shift = (key, days) => {
    const [y, m, d] = key.split('-').map(Number);
    return keyOf(new Date(y, m - 1, d + days));
  };
  const parse = (key) => {
    const [y, m, d] = key.split('-').map(Number);
    return new Date(y, m - 1, d);
  };

  // ---- State ----
  const blank = () => ({ v: 1, daily: [], once: [], log: {} });

  function load() {
    try {
      const raw = localStorage.getItem(STORE_KEY);
      if (!raw) return blank();
      return sanitize(JSON.parse(raw));
    } catch {
      return blank();
    }
  }

  function sanitize(s) {
    if (!s || typeof s !== 'object') throw new Error('Invalid data');
    const out = blank();
    out.daily = (Array.isArray(s.daily) ? s.daily : [])
      .filter((t) => t && t.id && typeof t.title === 'string')
      .map((t) => ({ id: String(t.id), title: t.title, created: t.created || today() }));
    out.once = (Array.isArray(s.once) ? s.once : [])
      .filter((t) => t && t.id && typeof t.title === 'string')
      .map((t) => ({ id: String(t.id), title: t.title, created: t.created || today(), doneOn: t.doneOn || null }));
    if (s.log && typeof s.log === 'object') {
      for (const [k, ids] of Object.entries(s.log)) {
        if (/^\d{4}-\d\d-\d\d$/.test(k) && Array.isArray(ids)) out.log[k] = ids.map(String);
      }
    }
    return out;
  }

  let state = load();

  function save() {
    try {
      localStorage.setItem(STORE_KEY, JSON.stringify(state));
    } catch {
      toast('Could not save — storage is full or blocked.');
    }
  }

  // Drop one-off tasks finished on earlier days and log entries older than ~1 year.
  function prune() {
    const t = today();
    const cutoff = shift(t, -400);
    state.once = state.once.filter((x) => !x.doneOn || x.doneOn === t);
    for (const k of Object.keys(state.log)) if (k < cutoff) delete state.log[k];
  }

  const uid = () => Date.now().toString(36) + Math.random().toString(36).slice(2, 7);

  const doneSet = (day) => new Set(state.log[day] || []);
  const isDailyDone = (id, day = today()) => doneSet(day).has(id);

  function streakOf(id) {
    let day = today();
    if (!isDailyDone(id, day)) day = shift(day, -1);
    let n = 0;
    while (isDailyDone(id, day)) {
      n++;
      day = shift(day, -1);
    }
    return n;
  }

  // ---- Actions ----
  function addTask(title, kind) {
    title = title.trim();
    if (!title) return;
    const task = { id: uid(), title, created: today() };
    if (kind === 'daily') state.daily.push(task);
    else state.once.push({ ...task, doneOn: null });
    save();
    render();
  }

  function toggleDaily(id) {
    const t = today();
    const set = doneSet(t);
    set.has(id) ? set.delete(id) : set.add(id);
    if (set.size) state.log[t] = [...set];
    else delete state.log[t];
    save();
    render();
    buzz();
  }

  function toggleOnce(id) {
    const task = state.once.find((x) => x.id === id);
    if (!task) return;
    task.doneOn = task.doneOn ? null : today();
    save();
    render();
    buzz();
  }

  function listFor(kind) {
    return kind === 'daily' ? state.daily : state.once;
  }

  function removeTask(kind, id) {
    const list = listFor(kind);
    const i = list.findIndex((x) => x.id === id);
    if (i < 0) return;
    const [removed] = list.splice(i, 1);
    save();
    render();
    toast(`Deleted “${removed.title}”`, 'Undo', () => {
      listFor(kind).splice(i, 0, removed);
      save();
      render();
    });
  }

  function moveTask(kind, id, dir) {
    const list = listFor(kind);
    const i = list.findIndex((x) => x.id === id);
    const j = i + dir;
    if (i < 0 || j < 0 || j >= list.length) return;
    [list[i], list[j]] = [list[j], list[i]];
    save();
    render();
  }

  function renameTask(kind, id) {
    const task = listFor(kind).find((x) => x.id === id);
    if (!task) return;
    const next = prompt('Rename task', task.title);
    if (next && next.trim()) {
      task.title = next.trim().slice(0, 120);
      save();
      render();
    }
  }

  function buzz() {
    if (navigator.vibrate) navigator.vibrate(10);
  }

  // ---- Rendering ----
  const ICONS = {
    check: '<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    up: '<svg viewBox="0 0 24 24"><path d="M6 15l6-6 6 6"/></svg>',
    down: '<svg viewBox="0 0 24 24"><path d="M6 9l6 6 6-6"/></svg>',
    del: '<svg viewBox="0 0 24 24"><path d="M4 7h16M10 11v6M14 11v6M6 7l1 12a2 2 0 002 2h6a2 2 0 002-2l1-12M9 7V4h6v3"/></svg>',
  };

  const weekdayFmt = new Intl.DateTimeFormat(undefined, { weekday: 'long' });
  const dateFmt = new Intl.DateTimeFormat(undefined, { month: 'long', day: 'numeric' });
  const shortDayFmt = new Intl.DateTimeFormat(undefined, { weekday: 'narrow' });
  const sinceFmt = new Intl.DateTimeFormat(undefined, { month: 'short', day: 'numeric' });

  let editing = false;
  let renderedDay = today();

  function el(tag, cls, html) {
    const n = document.createElement(tag);
    if (cls) n.className = cls;
    if (html != null) n.innerHTML = html;
    return n;
  }

  function taskRow(kind, task, list, index, done, metaText, metaCls) {
    const li = el('li', 'task' + (done ? ' done' : ''));

    const btn = el('button', 'check');
    btn.type = 'button';
    btn.setAttribute('role', 'checkbox');
    btn.setAttribute('aria-checked', String(done));
    btn.append(el('span', 'box', ICONS.check));
    const title = el('span', 'title');
    title.textContent = task.title;
    btn.append(title);
    btn.addEventListener('click', () => {
      if (editing) renameTask(kind, task.id);
      else if (kind === 'daily') toggleDaily(task.id);
      else toggleOnce(task.id);
    });
    li.append(btn);

    if (metaText) {
      const meta = el('span', 'meta' + (metaCls ? ' ' + metaCls : ''));
      meta.textContent = metaText;
      li.append(meta);
    }

    const tools = el('div', 'tools');
    const mk = (icon, label, fn, disabled, extra = '') => {
      const b = el('button', 'tool' + extra, ICONS[icon]);
      b.type = 'button';
      b.setAttribute('aria-label', label);
      b.disabled = disabled;
      b.addEventListener('click', fn);
      return b;
    };
    tools.append(
      mk('up', 'Move up', () => moveTask(kind, task.id, -1), index === 0),
      mk('down', 'Move down', () => moveTask(kind, task.id, 1), index === list.length - 1),
      mk('del', 'Delete', () => removeTask(kind, task.id), false, ' del'),
    );
    li.append(tools);
    return li;
  }

  function render() {
    const t = today();
    renderedDay = t;
    const now = parse(t);
    $('#weekday').textContent = weekdayFmt.format(now);
    $('#date').textContent = dateFmt.format(now);
    document.body.classList.toggle('editing', editing);
    $('#edit-toggle').textContent = editing ? 'Done' : 'Edit';

    // Daily habits
    const dailyList = $('#daily-list');
    dailyList.replaceChildren();
    const done = doneSet(t);
    let dailyDone = 0;
    state.daily.forEach((task, i) => {
      const isDone = done.has(task.id);
      if (isDone) dailyDone++;
      const streak = streakOf(task.id);
      dailyList.append(taskRow('daily', task, state.daily, i, isDone, streak > 1 ? `🔥 ${streak}` : '', 'streak'));
    });
    $('#daily-empty').hidden = state.daily.length > 0;
    $('#daily-count').textContent = state.daily.length ? `${dailyDone}/${state.daily.length}` : '';

    // One-off tasks: unfinished ones from earlier days carry over.
    const onceList = $('#once-list');
    onceList.replaceChildren();
    let onceDone = 0;
    state.once.forEach((task, i) => {
      const isDone = !!task.doneOn;
      if (isDone) onceDone++;
      const carried = !isDone && task.created < t ? `since ${sinceFmt.format(parse(task.created))}` : '';
      onceList.append(taskRow('once', task, state.once, i, isDone, carried));
    });
    $('#once-empty').hidden = state.once.length > 0;
    $('#once-count').textContent = state.once.length ? `${onceDone}/${state.once.length}` : '';

    // Progress ring
    const total = state.daily.length + state.once.length;
    const finished = dailyDone + onceDone;
    const frac = total ? finished / total : 0;
    $('#ring-fill').style.strokeDashoffset = String(113.1 * (1 - frac));
    $('#ring-label').textContent = `${finished}/${total}`;
    $('#ring').classList.toggle('complete', total > 0 && finished === total);
    $('#ring').setAttribute('aria-label', `${finished} of ${total} done today`);

    renderWeek(t);
  }

  function renderWeek(t) {
    const week = $('#week');
    week.replaceChildren();
    for (let i = 6; i >= 0; i--) {
      const day = shift(t, -i);
      const habits = state.daily.filter((x) => x.created <= day);
      const set = doneSet(day);
      const hit = habits.filter((x) => set.has(x.id)).length;
      const p = habits.length ? hit / habits.length : 0;
      const cell = el('div', 'day' + (i === 0 ? ' today' : '') + (habits.length && p === 1 ? ' full' : ''));
      cell.title = `${sinceFmt.format(parse(day))}: ${hit}/${habits.length} habits`;
      const dot = el('span', 'dot');
      dot.style.setProperty('--p', String(p));
      const label = el('span');
      label.textContent = shortDayFmt.format(parse(day));
      cell.append(dot, label);
      week.append(cell);
    }
  }

  // ---- Toast ----
  let toastTimer;
  function toast(msg, actionLabel, action) {
    const box = $('#toast');
    box.replaceChildren();
    const span = el('span');
    span.textContent = msg;
    box.append(span);
    if (actionLabel) {
      const b = el('button');
      b.type = 'button';
      b.textContent = actionLabel;
      b.addEventListener('click', () => {
        box.classList.remove('show');
        action();
      });
      box.append(b);
    }
    box.classList.add('show');
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => box.classList.remove('show'), 4000);
  }

  // ---- Wiring ----
  $('#composer').addEventListener('submit', (e) => {
    e.preventDefault();
    const input = $('#new-title');
    const kind = new FormData(e.target).get('kind');
    addTask(input.value, kind);
    input.value = '';
    input.focus();
  });

  $('#edit-toggle').addEventListener('click', () => {
    editing = !editing;
    render();
  });

  $('#export').addEventListener('click', () => {
    const blob = new Blob([JSON.stringify(state, null, 2)], { type: 'application/json' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `haru-haru-${today()}.json`;
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(a.href), 1000);
  });

  $('#import').addEventListener('click', () => $('#import-file').click());
  $('#import-file').addEventListener('change', async (e) => {
    const file = e.target.files[0];
    e.target.value = '';
    if (!file) return;
    try {
      const next = sanitize(JSON.parse(await file.text()));
      if (!confirm('Replace your current tasks with the imported file?')) return;
      state = next;
      prune();
      save();
      render();
      toast('Imported.');
    } catch {
      toast('That file is not a Haru-haru export.');
    }
  });

  // Re-render when the day changes (app left open overnight or resumed from background).
  function checkDay() {
    if (today() !== renderedDay) {
      prune();
      save();
      render();
    }
  }
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') checkDay();
  });
  window.addEventListener('focus', checkDay);
  setInterval(checkDay, 60 * 1000);

  // Keep tabs/windows in sync.
  window.addEventListener('storage', (e) => {
    if (e.key === STORE_KEY) {
      state = load();
      render();
    }
  });

  // Home-screen shortcuts: ?add=once or ?add=daily opens straight into the composer.
  const params = new URLSearchParams(location.search);
  const addKind = params.get('add');
  if (addKind === 'once' || addKind === 'daily') {
    const radio = document.querySelector(`input[name="kind"][value="${addKind}"]`);
    if (radio) radio.checked = true;
    setTimeout(() => $('#new-title').focus(), 50);
  }

  prune();
  save();
  render();

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => {
      navigator.serviceWorker.register('sw.js').catch(() => {});
    });
  }
})();
