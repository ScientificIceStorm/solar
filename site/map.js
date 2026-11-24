(() => {
  const width = 620;
  const height = 705;
  let projection;
  const get = (id) => document.getElementById(id);
  const svg = get('californiaMap');
  const list = get('mapEvents');
  const filter = get('mapFilter');
  const search = get('mapSearch');
  let geometry, calendar, season, failure, selected;
  let events = [];
  let viewport = {x:0, y:0, zoom:1};
  const pointers = new Map();
  const maxZoom = 320;

  function svgNode(tag, attributes) {
    const element = document.createElementNS('http://www.w3.org/2000/svg', tag);
    for (const [key, value] of Object.entries(attributes)) element.setAttribute(key, value);
    return element;
  }

  function buttonMarker(group, label, callback) {
    group.setAttribute('role','button');
    group.setAttribute('tabindex','0');
    group.setAttribute('aria-label', label);
    group.addEventListener('click', callback);
    group.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        callback();
      }
    });
  }

  function label(parent, text, x, y, className) {
    const element = svgNode('text', {x,y,class:className});
    element.textContent = text;
    parent.append(element);
  }

  function visibleEvents() {
    const now = Date.now();
    const query = search.value.trim().toLowerCase();
    return events.filter((event) => {
      if (query && ![event.name,event.location.city,event.sku].join(' ').toLowerCase().includes(query)) return false;
      const end = Date.parse(event.end || event.start) + 86400000;
      return filter.value === 'all' || (filter.value === 'upcoming' ? end > now : end <= now);
    });
  }

  function displayList(title, rows) {
    const heading = document.createElement('h2');
    heading.textContent = title;
    list.replaceChildren(heading);
    const caption = document.createElement('p');
    caption.className = 'map-note';
    caption.textContent = failure ? 'The season calendar is temporarily unavailable.' :
      !calendar && !rows.length ? 'Loading U.S. events…' :
      rows.length ? rows.length + (rows.length === 1 ? ' event' : ' events') : 'No events match this filter.';
    list.append(caption);
    for (const event of rows) {
      const link = document.createElement('a');
      link.className = 'map-event';
      link.href = '/event/' + encodeURIComponent(event.sku);
      const title = document.createElement('strong');
      title.textContent = event.name;
      const details = document.createElement('small');
      const date = Date.parse(event.start);
      details.textContent = [event.location.city, Number.isFinite(date) ?
        new Intl.DateTimeFormat(undefined,{month:'short',day:'numeric',timeZone:'UTC'}).format(date) : ''].filter(Boolean).join(' · ');
      link.append(title, details);
      list.append(link);
    }
  }

  function updateList() {
    const visible = visibleEvents();
    if (selected?.skus) {
      displayList('Events at this location', visible.filter((event) => selected.skus.has(event.sku)));
    } else {
      displayList('U.S. events', visible);
    }
  }

  function drawMarkers() {
    if (!projection) return;
    svg.querySelector('.map-markers')?.remove();
    const markers = svgNode('g', {class:'map-markers'});
    const clusters = new Map();
    const cell = 29 / viewport.zoom;
    for (const event of visibleEvents()) {
      const {latitude, longitude} = event.location;
      if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) continue;
      const [x,y] = projection([longitude,latitude]);
      const key = Math.round(x / cell) + ':' + Math.round(y / cell);
      if (!clusters.has(key)) clusters.set(key, {x:0,y:0,rows:[]});
      const group = clusters.get(key);
      group.x += x;
      group.y += y;
      group.rows.push(event);
    }
    for (const group of clusters.values()) {
      const count = group.rows.length;
      const point = svgNode('g', {class:'map-dot', transform:'translate(' +
        group.x/count + ' ' + group.y/count + ') scale(' + 1/viewport.zoom + ')'});
      point.append(svgNode('circle',{r:count > 1 ? 14 : 6}));
      if (count > 1) label(point, count, 0, 4, 'map-dot-label');
      buttonMarker(point, count + (count === 1 ? ' event near ' : ' events near ') + group.rows[0].location.city, () => {
        selected = {skus:new Set(group.rows.map((event) => event.sku))};
        updateList();
      });
      markers.append(point);
    }
    svg.append(markers);
  }

  async function drawBase() {
    const [geo, topo, atlas] = await Promise.all([
      import('https://cdn.jsdelivr.net/npm/d3-geo@3.1.1/+esm'),
      import('https://cdn.jsdelivr.net/npm/topojson-client@3.1.0/+esm'),
      fetch('https://cdn.jsdelivr.net/npm/us-atlas@3.0.1/states-10m.json').then((response) => response.json()),
    ]);
    projection = geo.geoOrthographic().rotate([109,-39]).scale(285).translate([width/2,height/2]);
    const path = geo.geoPath(projection);
    const land = svgNode('g',{class:'map-land'});
    land.append(svgNode('path', {class:'map-globe', d:path({type:'Sphere'})}));
    for (const state of topo.feature(atlas, atlas.objects.states).features) {
      const outline = path(state);
      if (outline) land.append(svgNode('path', {d:outline}));
    }
    svg.prepend(land);
    drawMarkers();
  }

  function updateViewport() {
    viewport.x = Math.min(width - width/viewport.zoom, Math.max(0,viewport.x));
    viewport.y = Math.min(height - height/viewport.zoom, Math.max(0,viewport.y));
    svg.setAttribute('viewBox',[viewport.x,viewport.y,width/viewport.zoom,height/viewport.zoom].join(' '));
    get('mapZoomIn').disabled = viewport.zoom >= maxZoom;
    get('mapZoomOut').disabled = viewport.zoom === 1;
  }

  function zoom(factor, anchor) {
    const next = Math.min(maxZoom, Math.max(1, viewport.zoom * factor));
    const center = anchor?.matrixTransform(svg.getScreenCTM().inverse()) ||
      {x:viewport.x + width / viewport.zoom / 2, y:viewport.y + height / viewport.zoom / 2};
    const ratio = viewport.zoom / next;
    viewport.x = center.x - (center.x - viewport.x) * ratio;
    viewport.y = center.y - (center.y - viewport.y) * ratio;
    viewport.zoom = next;
    updateViewport();
    drawMarkers();
  }

  get('mapZoomIn').onclick = () => zoom(1.5);
  get('mapZoomOut').onclick = () => zoom(1/1.5);
  svg.addEventListener('wheel', (event) => {
    event.preventDefault();
    const delta = Math.max(-150, Math.min(150, event.deltaY));
    zoom(Math.exp(-delta * .004), new DOMPoint(event.clientX, event.clientY));
  }, {passive:false});
  get('mapReset').onclick = () => {
    viewport = {x:0,y:0,zoom:1};
    updateViewport();
    drawMarkers();
  };
  svg.addEventListener('pointerdown', (event) => {
    if (event.target.closest('[role="button"]') && event.pointerType !== 'touch') return;
    pointers.set(event.pointerId, new DOMPoint(event.clientX, event.clientY));
    if (event.target.closest('[role="button"]')) return;
    svg.setPointerCapture(event.pointerId);
  });
  svg.addEventListener('pointermove', (event) => {
    const previous = pointers.get(event.pointerId);
    if (!previous) return;
    const current = new DOMPoint(event.clientX, event.clientY);
    const second = [...pointers.entries()].find(([id]) => id !== event.pointerId)?.[1];
    pointers.set(event.pointerId, current);
    const matrix = svg.getScreenCTM().inverse();
    const from = previous.matrixTransform(matrix);
    const to = current.matrixTransform(matrix);
    const movement = second ? .5 : 1;
    viewport.x -= (to.x - from.x) * movement;
    viewport.y -= (to.y - from.y) * movement;
    updateViewport();
    if (second) {
      const before = Math.hypot(previous.x - second.x, previous.y - second.y);
      const after = Math.hypot(current.x - second.x, current.y - second.y);
      if (before > 0 && after > 0) zoom(after / before,
        new DOMPoint((current.x + second.x) / 2, (current.y + second.y) / 2));
    }
  });
  for (const name of ['pointerup','pointercancel','lostpointercapture']) {
    svg.addEventListener(name, (event) => { pointers.delete(event.pointerId); });
  }
  filter.addEventListener('change', () => { drawMarkers(); updateList(); });
  search.addEventListener('input', () => {
    selected = undefined;
    drawMarkers();
    updateList();
  });

  window.loadCaliforniaMap = (seasonId, loadEvents) => {
    if (!geometry) geometry = drawBase().catch(() => { geometry = undefined; });
    if (seasonId && season !== seasonId) {
      season = seasonId;
      failure = false;
      loadEvents(seasonId).then((rows) => {
        if (season !== seasonId) return;
        calendar = rows;
        events = rows.filter((event) => /^(united states(?: of america)?|usa|us)$/i.test(event.location?.country) && event.sku)
          .sort((a,b) => (a.start || '').localeCompare(b.start || ''));
        drawMarkers();
        updateList();
      }).catch(() => {
        if (season !== seasonId) return;
        season = undefined;
        failure = true;
        updateList();
      });
    }
    updateViewport();
    drawMarkers();
    updateList();
  };
})();
