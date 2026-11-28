(() => {
  const toggle = document.getElementById('profileToggle');
  const panel = document.getElementById('profilePanel');
  const form = document.getElementById('profileForm');
  const google = document.getElementById('profileGoogle');
  const logout = document.getElementById('profileLogout');
  const status = document.getElementById('profileStatus');
  const teamForm = document.getElementById('profileTeamForm');
  const teamInput = document.getElementById('profileTeam');
  const SIGNED_IN = 'solar-signed-in';
  let connection, current = null;
  const listeners = new Set();

  // Favourites live on the account (Supabase user data) with the team you follow.
  function favorites(session = current) {
    const saved = session?.user.user_metadata?.favorites || {};
    return {teams: Array.isArray(saved.teams) ? saved.teams : [], events: Array.isArray(saved.events) ? saved.events : []};
  }
  // Every page's favourite buttons show whether that team or event is saved.
  function syncFavorites() {
    const saved = favorites();
    document.querySelectorAll('[data-favorite-team],[data-favorite-event]').forEach((button) => {
      const team = button.dataset.favoriteTeam, sku = button.dataset.favoriteEvent;
      const on = team ? saved.teams.includes(team) : saved.events.some((event) => event.sku === sku);
      button.setAttribute('aria-pressed', String(on));
      button.textContent = button.classList.contains('small') ? (on ? '★' : '☆') : on ? '★ Favorited' : '☆ Favorite';
      button.title = on ? 'Remove from favourites' : 'Add to favourites';
      button.dataset.synced = '1';
    });
  }
  // Pages redraw their headers often; new favourite buttons pick up their state on their own.
  let syncQueued = false;
  new MutationObserver(() => {
    if (syncQueued) return;
    syncQueued = true;
    requestAnimationFrame(() => {
      syncQueued = false;
      if (document.querySelector('[data-favorite-team]:not([data-synced]),[data-favorite-event]:not([data-synced])')) window.solarProfile?.syncFavorites();
    });
  }).observe(document.body, {childList: true, subtree: true});

  function showSession(session) {
    const was = Boolean(current);
    current = session;
    form.hidden = google.hidden = Boolean(session);
    logout.hidden = !session;
    status.textContent = session?.user.email || '';
    // Only the main site's panel has the team form; ScoutVision pages share the sign-in alone.
    if (teamForm) {
      teamForm.hidden = !session;
      teamInput.value = session?.user.user_metadata?.team || '';
    }
    // Remembered so the front page can open on the dashboard without waiting for sign-in.
    if (session) localStorage.setItem(SIGNED_IN, '1'); else localStorage.removeItem(SIGNED_IN);
    syncFavorites();
    listeners.forEach((listener) => listener(session));
    if (was !== Boolean(session) && location.pathname === '/' && !location.hash) dispatchEvent(new HashChangeEvent('hashchange'));
  }
  function connect() {
    return connection ??= (async () => {
      const config = await fetch('/api/profile-config');
      if (!config.ok) throw new Error('Profile sign-in is awaiting setup.');
      const {url, key} = await config.json();
      const {createClient} = await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.89.0/+esm');
      const client = createClient(url, key, {auth: {flowType:'pkce'}});
      client.auth.onAuthStateChange((_, session) => showSession(session));
      const {data} = await client.auth.getSession();
      showSession(data.session);
      return client.auth;
    })().catch((error) => {
      connection = undefined;
      throw error;
    });
  }
  function open(visible) {
    toggle.setAttribute('aria-expanded', String(visible));
    panel.hidden = !visible;
    if (visible) connect().catch((error) => { status.textContent = error.message; });
  }
  toggle.onclick = () => open(panel.hidden);
  document.addEventListener('click', (event) => {
    if (!panel.contains(event.target) && !toggle.contains(event.target)) open(false);
  });
  document.addEventListener('keydown', (event) => {
    if (event.key === 'Escape' && !panel.hidden) {
      open(false);
      toggle.focus();
    }
  });
  const redirect = location.origin + '/?profile=1';
  async function run(operation) {
    try {
      const {data, error} = await operation(await connect());
      if (error) throw error;
      return data;
    } catch (error) {
      status.textContent = /already (been )?registered|already exists/i.test(error.message)
        ? 'You already have an account with this email. Log in instead.' : error.message;
    }
  }
  google.onclick = () => run((auth) => auth.signInWithOAuth({provider:'google', options:{redirectTo:redirect}}));
  logout.onclick = () => run((auth) => auth.signOut());
  form.onsubmit = async (event) => {
    event.preventDefault();
    const {email, password} = Object.fromEntries(new FormData(form));
    const signup = event.submitter?.value === 'signup';
    const data = await run((auth) => signup
      ? auth.signUp({email, password, options:{emailRedirectTo:redirect}})
      : auth.signInWithPassword({email, password}));
    if (!data) return;
    // Supabase answers a sign-up for an email that already has an account with a user that
    // has no identities (and sends nothing): that person has to log in, not sign up again.
    if (signup && Array.isArray(data.user?.identities) && data.user.identities.length === 0) {
      status.textContent = 'You already have an account with this email. Log in instead.';
      form.elements.password.value = '';
      return;
    }
    form.reset();
    if (signup && !data.session) status.textContent = 'Check your email to confirm your account, then log in.';
    if (data.session) open(false);
  };
  async function saveData(patch) {
    const data = await run((auth) => auth.updateUser({data: patch}));
    if (data?.user) showSession({...current, user: data.user});
    return data;
  }
  // The team you follow is kept on your account (Supabase user data), not in a separate table.
  async function saveTeam(value) {
    const team = String(value || '').trim().toUpperCase();
    if (!/^\d{1,6}[A-Z]{0,2}$/.test(team)) { status.textContent = 'Enter a VEX team number like 98601B.'; return null; }
    const data = await saveData({team});
    if (data) status.textContent = 'Saved. Your dashboard follows ' + team + '.';
    return data ? team : null;
  }
  if (teamForm) teamForm.onsubmit = async (event) => {
    event.preventDefault();
    if (await saveTeam(teamInput.value)) window.solarAccount?.show();
  };
  async function toggleFavorite(kind, item) {
    await connect().catch(() => {});
    if (!current) {
      open(true);
      status.textContent = 'Sign in to save favourite teams and events.';
      return;
    }
    const saved = favorites();
    if (kind === 'team') {
      saved.teams = saved.teams.includes(item) ? saved.teams.filter((team) => team !== item) : [...saved.teams, item].slice(-24);
    } else {
      saved.events = saved.events.some((event) => event.sku === item.sku)
        ? saved.events.filter((event) => event.sku !== item.sku) : [...saved.events, item].slice(-24);
    }
    await saveData({favorites: saved});
  }
  document.addEventListener('click', (event) => {
    const button = event.target.closest?.('[data-favorite-team],[data-favorite-event]');
    if (!button) return;
    event.preventDefault();
    event.stopPropagation();
    if (button.dataset.favoriteTeam) toggleFavorite('team', button.dataset.favoriteTeam);
    else toggleFavorite('event', {sku: button.dataset.favoriteEvent, name: button.dataset.name || button.dataset.favoriteEvent});
  });

  window.solarProfile = {
    connect,
    get session() { return current; },
    get favorites() { return favorites(); },
    onChange(listener) { listeners.add(listener); return () => listeners.delete(listener); },
    open, saveTeam, saveData, toggleFavorite,
    // Called by pages after they draw favourite buttons.
    syncFavorites() {
      if (current || !localStorage.getItem(SIGNED_IN)) syncFavorites();
      else connect().then(syncFavorites).catch(() => {});
    },
  };
  if (new URLSearchParams(location.search).get('profile') === '1') open(true);
  if (location.hash === '#account' || localStorage.getItem(SIGNED_IN)) connect().catch(() => {});
})();
