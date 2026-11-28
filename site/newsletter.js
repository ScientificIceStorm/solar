// Newsletter sign-up forms (Vision UI and ScoutVision). Posts the address to /api/newsletter,
// which stores it in the site's KV store; nothing else about the visitor is kept.
(() => {
  for (const form of document.querySelectorAll('.newsletter-form')) {
    const note = form.nextElementSibling?.classList.contains('newsletter-note') ? form.nextElementSibling : null;
    const original = note?.innerHTML;
    const say = (text, tone) => {
      if (!note) return;
      note.textContent = text;
      note.dataset.tone = tone;
    };
    form.addEventListener('submit', async (event) => {
      event.preventDefault();
      const email = form.email.value.trim();
      if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(email) || email.length > 254) {
        say('Enter a full email address, like you@example.com.', 'error');
        form.email.focus();
        return;
      }
      const button = form.querySelector('button');
      button.disabled = true;
      form.classList.add('sending');
      try {
        const response = await fetch('/api/newsletter', {
          method: 'POST',
          headers: {'Content-Type': 'application/json'},
          body: JSON.stringify({email, source: form.dataset.source || '', website: form.website?.value || ''}),
          signal: AbortSignal.timeout(15000),
        });
        const data = await response.json().catch(() => ({}));
        if (!response.ok) throw new Error(data.error || 'Sign-up failed.');
        form.classList.add('done');
        form.email.value = '';
        say(data.already ? 'You’re already on the list. Thanks!' : 'You’re in. We’ll email you when there’s news.', 'ok');
      } catch (error) {
        say(error.message === 'Sign-up failed.' || !error.message ? 'Couldn’t sign you up just now. Try again in a minute.' : error.message, 'error');
      } finally {
        button.disabled = false;
        form.classList.remove('sending');
      }
    });
    form.email.addEventListener('input', () => {
      if (note && note.dataset.tone === 'error') { note.innerHTML = original; delete note.dataset.tone; }
    });
  }
})();
