// The sliding highlight in the Credits, Privacy and Terms menu. It behaves like the main
// menu's (wireSlidingIndicator in app.js), which these pages do not load.
(() => {
  const nav = document.querySelector('.legal-nav');
  const indicator = nav.querySelector('.nav-indicator');
  function sync(target = nav.querySelector('[aria-current]')) {
    if (target) {
      indicator.style.transform = 'translateX(' + target.offsetLeft + 'px)';
      indicator.style.width = target.offsetWidth + 'px';
    }
    indicator.classList.toggle('shown', Boolean(target));
  }
  nav.addEventListener('pointerover', (event) => {
    if (event.pointerType === 'touch') return;
    const target = event.target.closest('a');
    if (target) sync(target);
  });
  nav.addEventListener('pointerleave', () => sync());
  nav.addEventListener('focusin', (event) => sync(event.target));
  nav.addEventListener('focusout', (event) => {
    if (!nav.contains(event.relatedTarget)) sync();
  });
  const observer = new ResizeObserver(() => sync());
  observer.observe(nav);
  nav.querySelectorAll('a').forEach((link) => observer.observe(link));
  sync();
})();
