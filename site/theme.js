// Solar page chrome shared by the main pages: light/dark theme toggle, the masthead fade once the
// page scrolls, and the circle ripple on nav items, filters and buttons.
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

  // ---- Ripple ------------------------------------------------------------------------------------
  // Selects can't hold children, so each toolbar select gets a wrapper the ripple can live in.
  const wrapSelects = () => document.querySelectorAll('.toolbar select, .detail-toolbar select').forEach((select) => {
    if (select.parentElement.classList.contains('select-wrap')) return;
    const wrap = document.createElement('span');
    wrap.className = 'select-wrap';
    select.replaceWith(wrap);
    wrap.append(select);
  });
  wrapSelects();
  new MutationObserver(wrapSelects).observe(document.body, {childList: true, subtree: true});

  const RIPPLE = '.top-nav > a, #profileToggle, .theme-toggle, .select-wrap, .toolbar button, .table-footer button, .detail-tabs button, #profilePanel button, .home-search button, .event-search-trigger';
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
