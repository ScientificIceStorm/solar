// ScoutVision sub-nav: a soft pill follows the pointer across the tabs and slides to the one you
// click while the next page loads.
(() => {
  for (const nav of document.querySelectorAll('.sv-nav')) {
    const pill = document.createElement('span');
    pill.className = 'sv-pill';
    pill.setAttribute('aria-hidden', 'true');
    nav.prepend(pill);
    const to = (link) => {
      if (!link) { pill.classList.remove('shown'); return; }
      pill.style.transform = `translateX(${link.offsetLeft}px)`;
      pill.style.width = `${link.offsetWidth}px`;
      pill.classList.add('shown');
    };
    nav.addEventListener('pointerover', (event) => {
      const link = event.target.closest('a');
      if (link && !link.hasAttribute('aria-current')) to(link);
    });
    nav.addEventListener('pointerleave', () => to(null));
    nav.addEventListener('focusin', (event) => to(event.target.closest('a:not([aria-current])')));
  }
})();
