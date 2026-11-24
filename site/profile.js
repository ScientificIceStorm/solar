(() => {
  const toggle = document.getElementById('profileToggle');
  const panel = document.getElementById('profilePanel');
  const form = document.getElementById('profileForm');
  const google = document.getElementById('profileGoogle');
  const logout = document.getElementById('profileLogout');
  const status = document.getElementById('profileStatus');
  let connection;
  function showSession(session) {
    form.hidden = google.hidden = Boolean(session);
    logout.hidden = !session;
    status.textContent = session?.user.email || '';
  }
  function connect() {
    return connection ??= (async () => {
      const config = await fetch('/api/profile-config');
      if (!config.ok) throw new Error('Profile sign-in is awaiting setup.');
      const {url, key} = await config.json();
      const {createClient} = await import('https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2.89.0/+esm');
      const client = createClient(url, key, {auth: {flowType:'pkce'}});
      client.auth.onAuthStateChange((_, session) => showSession(session));
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
      status.textContent = error.message;
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
    if (data) form.reset();
    if (signup && data && !data.session) status.textContent = 'Check your email to confirm your account.';
  };
  if (new URLSearchParams(location.search).get('profile') === '1') open(true);
})();
