// Solar page chrome shared by the main pages: light/dark theme toggle, the masthead fade once the
// page scrolls, custom filter dropdowns, and the circle ripple on nav items, filters and buttons.
(() => {
  const root = document.documentElement;
  const meta = document.querySelector('meta[name="theme-color"]');

  // ---- Theme ------------------------------------------------------------------------------------
  // The saved choice (or the system setting) is applied by the inline snippet in <head> before
  // first paint; this wires the toggle and keeps the browser chrome colour in step.
  const apply = (theme) => {
    root.dataset.theme = theme;
    if (meta) meta.content = theme === 'dark' ? '#050b1c' : '#103cbb';
    document.querySelectorAll('.theme-toggle').forEach((button) => {
      button.setAttribute('aria-pressed', String(theme === 'dark'));
      button.title = theme === 'dark' ? 'Switch to light mode' : 'Switch to dark mode';
    });
  };
  apply(root.dataset.theme === 'dark' ? 'dark' : 'light');
  document.addEventListener('click', (event) => {
    if (!event.target.closest('.theme-toggle')) return;
    const next = root.dataset.theme === 'dark' ? 'light' : 'dark';
    try { localStorage.setItem('solarTheme', next); } catch {}
    root.classList.add('theme-shift');
    apply(next);
    setTimeout(() => root.classList.remove('theme-shift'), 450);
  });

  // ---- Masthead: its height for sticky bars below it, and a fade once content slides under it --
  const mast = document.querySelector('.masthead');
  if (mast) {
    const measure = () => root.style.setProperty('--mast-h', mast.offsetHeight + 'px');
    new ResizeObserver(measure).observe(mast);
    measure();
    const onScroll = () => root.classList.toggle('scrolled', scrollY > 6);
    addEventListener('scroll', onScroll, {passive: true});
    onScroll();
  }

  // ---- Nav pill ---------------------------------------------------------------------------------
  // The main site's app.js drives the pill itself; every other page gets it here.
  const nav = document.querySelector('.top-nav');
  if (nav && !document.querySelector('script[src*="/app.js"]')) {
    let pill = nav.querySelector('.nav-indicator');
    if (!pill) { pill = document.createElement('span'); pill.className = 'nav-indicator'; pill.setAttribute('aria-hidden', 'true'); nav.prepend(pill); }
    const links = () => [...nav.children].filter((el) => el.matches('a, #profileToggle'));
    const sync = (target = nav.querySelector(':scope > a[aria-current]')) => {
      if (target) { pill.style.transform = `translateX(${target.offsetLeft}px)`; pill.style.width = `${target.offsetWidth}px`; }
      pill.classList.toggle('shown', Boolean(target));
    };
    nav.addEventListener('pointerover', (event) => {
      if (event.pointerType === 'touch') return;
      const target = links().find((el) => el.contains(event.target));
      if (target) sync(target);
    });
    nav.addEventListener('pointerleave', () => sync());
    nav.addEventListener('focusin', (event) => { if (links().includes(event.target)) sync(event.target); });
    nav.addEventListener('focusout', (event) => { if (!nav.contains(event.relatedTarget)) sync(); });
    new ResizeObserver(() => sync()).observe(nav);
    requestAnimationFrame(() => sync());
    document.fonts?.ready.then(() => sync());
  }

  // ---- Dropdowns -----------------------------------------------------------------------------------
  // Filter selects get a custom button and list. The real <select> stays in the page (hidden), so
  // app.js keeps reading .value and listening for 'change' exactly as before.
  const SELECTS = '.toolbar select, .detail-toolbar select, #mapFilter';
  let open = null;
  const labelOf = (select) => select.selectedOptions[0]?.textContent || select.options[0]?.textContent || '';
  function setLabel(dropdown, animate) {
    const text = labelOf(dropdown.select);
    dropdown.button.disabled = dropdown.select.disabled;
    if (dropdown.text === text) return;
    const old = dropdown.label.querySelector('span:last-child');
    const next = document.createElement('span');
    next.textContent = text;
    dropdown.text = text;
    dropdown.label.dataset.text = text;                     // sizes the button; the spans animate
    if (animate && old && !matchMedia('(prefers-reduced-motion: reduce)').matches) {
      old.classList.add('out');
      next.classList.add('in');
      dropdown.label.append(next);
      setTimeout(() => old.remove(), 260);
      requestAnimationFrame(() => requestAnimationFrame(() => next.classList.remove('in')));
    } else {
      dropdown.label.replaceChildren(next);
    }
  }
  function enhance(select) {
    if (select.closest('.select-wrap')) return;
    const wrap = document.createElement('span');
    wrap.className = 'select-wrap';
    const button = document.createElement('button');
    button.type = 'button';
    button.className = 'select-button';
    button.setAttribute('aria-haspopup', 'listbox');
    button.setAttribute('aria-expanded', 'false');
    if (select.getAttribute('aria-label')) button.setAttribute('aria-label', select.getAttribute('aria-label'));
    button.innerHTML = '<span class="select-label"></span><svg viewBox="0 0 16 16" aria-hidden="true"><path d="m4 6 4 4 4-4"/></svg>';
    select.replaceWith(wrap);
    select.tabIndex = -1;
    select.setAttribute('aria-hidden', 'true');
    wrap.append(select, button);
    const dropdown = {select, wrap, button, label: button.querySelector('.select-label'), text: null};
    setLabel(dropdown, false);
    select.addEventListener('change', () => setLabel(dropdown, true));
    new MutationObserver(() => setLabel(dropdown, false)).observe(select, {childList: true, subtree: true, attributes: true, characterData: true});
    button.addEventListener('click', () => (open?.dropdown === dropdown ? close() : show(dropdown)));
    button.addEventListener('keydown', (event) => {
      if (['ArrowDown', 'ArrowUp'].includes(event.key) && !open) { event.preventDefault(); show(dropdown); }
    });
  }
  function place() {
    if (!open) return;
    const box = open.dropdown.button.getBoundingClientRect();
    const below = innerHeight - box.bottom - 12, above = box.top - 12;
    const up = below < 220 && above > below;
    Object.assign(open.list.style, {
      left: `${Math.min(box.left, innerWidth - open.list.offsetWidth - 8)}px`,
      minWidth: `${box.width}px`,
      maxHeight: `${Math.max(160, Math.min(360, up ? above : below))}px`,
      top: up ? '' : `${box.bottom + 6}px`,
      bottom: up ? `${innerHeight - box.top + 6}px` : '',
    });
    open.list.classList.toggle('up', up);
  }
  function highlight(index, scroll) {
    if (!open) return;
    const items = [...open.list.querySelectorAll('[role=option]')];
    index = Math.max(0, Math.min(items.length - 1, index));
    open.active = index;
    items.forEach((item, k) => item.classList.toggle('active', k === index));
    const item = items[index];
    if (!item) return;
    open.pill.style.transform = `translateY(${item.offsetTop}px)`;
    open.pill.style.height = `${item.offsetHeight}px`;
    open.pill.classList.add('shown');
    if (scroll) item.scrollIntoView({block: 'nearest'});
  }
  function show(dropdown) {
    close(true);
    const {select, button} = dropdown;
    const list = document.createElement('div');
    list.className = 'select-list';
    list.setAttribute('role', 'listbox');
    list.tabIndex = -1;
    if (select.getAttribute('aria-label')) list.setAttribute('aria-label', select.getAttribute('aria-label'));
    const pill = document.createElement('i');
    pill.className = 'select-pill';
    list.append(pill);
    let selected = 0;
    [...select.options].forEach((option, k) => {
      if (option.hidden || option.disabled) return;
      const item = document.createElement('div');
      item.setAttribute('role', 'option');
      item.dataset.value = option.value;
      item.style.setProperty('--i', Math.min(list.children.length, 12));
      item.textContent = option.textContent;
      if (k === select.selectedIndex) { item.setAttribute('aria-selected', 'true'); selected = list.children.length - 1; }
      list.append(item);
    });
    document.body.append(list);
    open = {dropdown, list, pill, active: selected};
    button.setAttribute('aria-expanded', 'true');
    dropdown.wrap.classList.add('open');
    place();
    highlight(selected, true);
    requestAnimationFrame(() => list.classList.add('shown'));
    list.addEventListener('pointermove', (event) => {
      const item = event.target.closest('[role=option]');
      if (item) highlight([...list.querySelectorAll('[role=option]')].indexOf(item));
    });
    list.addEventListener('click', (event) => {
      const item = event.target.closest('[role=option]');
      if (item) choose(item.dataset.value);
    });
    list.focus({preventScroll: true});
    list.addEventListener('keydown', (event) => {
      const count = list.querySelectorAll('[role=option]').length;
      if (event.key === 'ArrowDown') highlight(open.active + 1, true);
      else if (event.key === 'ArrowUp') highlight(open.active - 1, true);
      else if (event.key === 'Home') highlight(0, true);
      else if (event.key === 'End') highlight(count - 1, true);
      else if (event.key === 'Enter' || event.key === ' ') choose(list.querySelectorAll('[role=option]')[open.active]?.dataset.value);
      else if (event.key === 'Escape' || event.key === 'Tab') { close(); button.focus(); return; }
      else if (event.key.length === 1) {
        const items = [...list.querySelectorAll('[role=option]')];
        const hit = items.findIndex((item, k) => k > open.active && item.textContent.toLowerCase().includes(event.key.toLowerCase()));
        const any = items.findIndex((item) => item.textContent.toLowerCase().includes(event.key.toLowerCase()));
        if (hit >= 0 || any >= 0) highlight(hit >= 0 ? hit : any, true);
      } else return;
      event.preventDefault();
    });
  }
  function choose(value) {
    if (!open || value === undefined) return;
    const {select, button} = open.dropdown;
    const changed = select.value !== value;
    close();
    button.focus({preventScroll: true});
    if (!changed) return;
    select.value = value;
    select.dispatchEvent(new Event('input', {bubbles: true}));
    select.dispatchEvent(new Event('change', {bubbles: true}));
  }
  function close(instant) {
    if (!open) return;
    const {list, dropdown} = open;
    open = null;
    dropdown.button.setAttribute('aria-expanded', 'false');
    dropdown.wrap.classList.remove('open');
    if (instant) { list.remove(); return; }
    list.classList.remove('shown');
    list.classList.add('closing');
    setTimeout(() => list.remove(), 180);
  }
  document.addEventListener('pointerdown', (event) => {
    if (open && !open.list.contains(event.target) && !open.dropdown.wrap.contains(event.target)) close();
  });
  addEventListener('resize', () => close(true));
  addEventListener('scroll', place, {passive: true});
  const enhanceAll = () => document.querySelectorAll(SELECTS).forEach(enhance);
  enhanceAll();
  new MutationObserver(enhanceAll).observe(document.body, {childList: true, subtree: true});

  // ---- Ripple ------------------------------------------------------------------------------------
  const RIPPLE = '.top-nav > a, #profileToggle, .theme-toggle, .select-button, .toolbar button, .table-footer button, .detail-tabs button, #profilePanel button, .home-search button, .event-search-trigger';
  document.addEventListener('pointerdown', (event) => {
    const host = event.target.closest(RIPPLE);
    if (!host || host.disabled || matchMedia('(prefers-reduced-motion: reduce)').matches) return;
    const box = host.getBoundingClientRect();
    const size = Math.hypot(box.width, box.height) * 2;
    const ripple = document.createElement('span');
    ripple.className = 'ripple';
    ripple.style.cssText = `width:${size}px;height:${size}px;left:${event.clientX - box.left - size / 2}px;top:${event.clientY - box.top - size / 2}px`;
    host.classList.add('ripple-host');
    host.append(ripple);
    ripple.addEventListener('animationend', () => ripple.remove());
  });
})();
