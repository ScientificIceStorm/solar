(() => {
  const library = 'https://api.mapbox.com/mapbox-gl-js/v3.36.0/mapbox-gl';
  const center = [-98, 38];
  const duration = 1100;
  // A season has well over a thousand events; building every row makes typing lag.
  const pageSize = 100;
  const markerLayers = ['event-clusters', 'event-points'];
  const reducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
  const get = (id) => document.getElementById(id);
  const container = get('eventMap');
  const message = get('mapMessage');
  const list = get('mapEvents');
  const filter = get('mapFilter');
  const search = get('mapSearch');
  let calendar, season, failure, selected;
  let events = [];
  const assets = new Map();
  let starting, map, hovered, searchTimer;
  let shown = pageSize;

  function visibleEvents() {
    const now = Date.now();
    const query = search.value.trim().toLowerCase();
    return events.filter((event) => {
      if (query && ![event.name,event.location?.city,event.location?.country,event.sku].join(' ').toLowerCase().includes(query)) return false;
      const end = Date.parse(event.end || event.start) + 86400000;
      return filter.value === 'all' || (filter.value === 'upcoming' ? end > now : end <= now);
    });
  }

  function eventLink(event) {
    const link = document.createElement('a');
    link.className = 'map-event';
    link.href = '/event/' + encodeURIComponent(event.sku);
    const title = document.createElement('strong');
    title.textContent = event.name;
    const details = document.createElement('small');
    const date = Date.parse(event.start);
    details.textContent = [event.location?.city, event.location?.country, Number.isFinite(date) ?
      new Intl.DateTimeFormat(undefined,{month:'short',day:'numeric',timeZone:'UTC'}).format(date) : ''].filter(Boolean).join(' · ');
    link.append(title, details);
    return link;
  }

  function listButton(className, text, callback) {
    const button = document.createElement('button');
    button.type = 'button';
    button.className = className;
    button.textContent = text;
    button.addEventListener('click', callback);
    return button;
  }

  // Adds the rows from `from` up to the current limit, then a button for the rest.
  function appendRows(rows, from) {
    const links = rows.slice(from, shown).map(eventLink);
    list.append(...links);
    if (rows.length > shown) {
      const more = listButton('map-more', 'Show more (' + (rows.length - shown) + ' left)', () => {
        const next = shown;
        shown += pageSize;
        more.remove();
        // Keeps the scroll position and moves keyboard focus to the first new event.
        appendRows(rows, next)[0]?.focus({preventScroll: true});
      });
      list.append(more);
    }
    return links;
  }

  function displayList(title, rows) {
    const heading = document.createElement('h2');
    heading.textContent = title;
    list.replaceChildren(heading);
    if (selected) {
      // Returns to the full list without moving the map.
      list.prepend(listButton('map-clear', '← Show all events', () => {
        selected = undefined;
        shown = pageSize;
        updateList();
        list.scrollTop = 0;
      }));
    }
    const caption = document.createElement('p');
    caption.className = 'map-note';
    caption.textContent = failure ? 'The season calendar is temporarily unavailable.' :
      !calendar && !rows.length ? 'Loading events…' :
      rows.length ? rows.length + (rows.length === 1 ? ' event' : ' events') : 'No events match this filter.';
    list.append(caption);
    appendRows(rows, 0);
  }

  function updateList() {
    const visible = visibleEvents();
    if (selected) {
      displayList('Events at this location', visible.filter((event) => selected.has(event.sku)));
    } else {
      const titles = {all: 'All events', upcoming: 'Upcoming & ongoing', past: 'Past events'};
      displayList(titles[filter.value], visible);
    }
  }

  // Events without usable coordinates stay in the list; (0, 0) means the venue is unknown.
  function hasLocation(event) {
    const {latitude, longitude} = event.location || {};
    return Number.isFinite(latitude) && Number.isFinite(longitude) &&
      Math.abs(latitude) <= 90 && Math.abs(longitude) <= 180 && Boolean(latitude || longitude);
  }

  function markerData() {
    return {type: 'FeatureCollection', features: visibleEvents().filter(hasLocation).map((event) => ({
      type: 'Feature',
      geometry: {type: 'Point', coordinates: [event.location.longitude, event.location.latitude]},
      properties: {sku: event.sku},
    }))};
  }

  function updateMarkers() {
    const source = map?.getSource('events');
    if (!source) return;
    hover();
    source.setData(markerData());
  }

  function update() {
    updateMarkers();
    updateList();
  }

  function showMessage(text) {
    message.textContent = text;
    message.hidden = !text;
  }

  // Adds a script or stylesheet once. A failed one is requested again next time.
  function loadAsset(tag, attributes) {
    const url = attributes.src || attributes.href;
    if (!assets.has(url)) {
      assets.set(url, new Promise((resolve, reject) => {
        const element = Object.assign(document.createElement(tag), attributes);
        const fail = () => {
          clearTimeout(timeout);
          element.remove();
          assets.delete(url);
          reject(new Error('The map library could not load.'));
        };
        const timeout = setTimeout(fail, 20000);
        element.onload = () => {
          clearTimeout(timeout);
          resolve();
        };
        element.onerror = fail;
        document.head.append(element);
      }));
    }
    return assets.get(url);
  }

  // Requested the first time the Map page opens.
  function loadLibrary() {
    return Promise.all([
      loadAsset('link', {rel: 'stylesheet', href: library + '.css'}),
      loadAsset('script', {src: library + '.js'}),
    ]);
  }

  async function loadToken() {
    const unavailable = 'The map could not load.';
    let response, body;
    try {
      response = await fetch('/api/map-config', {signal: AbortSignal.timeout(10000)});
      body = await response.json();
    } catch {
      throw new Error(unavailable);
    }
    if (!response.ok || !body.token) throw new Error(body.error || unavailable);
    return body.token;
  }

  // The zoom at which the whole globe fits inside the map area.
  function startZoom() {
    return Math.log2(Math.min(container.clientWidth, container.clientHeight) * .95 * Math.PI / 512);
  }

  function updateZoomButtons() {
    get('mapZoomIn').disabled = !map || map.getZoom() >= map.getMaxZoom();
    get('mapZoomOut').disabled = !map || map.getZoom() <= map.getMinZoom();
  }

  function moveTo(camera) {
    if (reducedMotion.matches) map.jumpTo(camera);
    else map.flyTo({...camera, duration, essential: true});
  }

  const tilt = (zoom) => zoom >= 8 ? 50 : 0;

  function select(skus) {
    selected = new Set(skus);
    shown = pageSize;
    updateList();
    list.scrollTop = 0;
  }

  function openPoint(feature) {
    const event = events.find((row) => row.sku === feature.properties.sku);
    if (!event) return;
    const {latitude, longitude} = event.location;
    // Events sharing a venue sit on top of each other, so list all of them.
    select(visibleEvents().filter((row) => row.location?.latitude === latitude &&
      row.location.longitude === longitude).map((row) => row.sku));
    const zoom = Math.max(map.getZoom(), 11);
    moveTo({center: [longitude, latitude], zoom, pitch: tilt(zoom)});
  }

  function openCluster(feature) {
    const {cluster_id: id, point_count: count} = feature.properties;
    const target = map;
    target.getSource('events').getClusterLeaves(id, count, 0, (error, leaves) => {
      // An error means the markers changed after the click.
      if (error || target !== map || !leaves?.length) return;
      select(leaves.map((leaf) => leaf.properties.sku));
      const bounds = new window.mapboxgl.LngLatBounds();
      for (const leaf of leaves) bounds.extend(leaf.geometry.coordinates);
      const padding = Math.min(60, container.clientHeight / 8);
      const fit = (pitch) => map.cameraForBounds(bounds, {padding, maxZoom: 13, pitch, bearing: 0});
      let camera = fit(0);
      if (camera && tilt(camera.zoom)) camera = fit(tilt(camera.zoom)) || camera;
      if (!camera) return;
      const zoom = Math.min(camera.zoom, 13);
      moveTo({center: camera.center, zoom, pitch: tilt(zoom), bearing: 0});
    });
  }

  function markerAt(point) {
    if (!map.getLayer('event-points')) return;
    return map.queryRenderedFeatures(point, {layers: markerLayers})[0];
  }

  function hover(id) {
    if (!map || hovered === id) return;
    if (hovered !== undefined) map.setFeatureState({source: 'events', id: hovered}, {hover: false});
    hovered = id;
    if (id !== undefined) map.setFeatureState({source: 'events', id}, {hover: true});
    map.getCanvas().style.cursor = id === undefined ? '' : 'pointer';
  }

  function addLayers(target) {
    target.setFog({color: '#cfe0f6', 'high-color': '#8fb4e6', 'horizon-blend': .008,
      'space-color': 'rgba(0,0,0,0)', 'star-intensity': 0});
    target.addSource('terrain', {type: 'raster-dem', url: 'mapbox://mapbox.mapbox-terrain-dem-v1',
      tileSize: 512, maxzoom: 14});
    target.setTerrain({source: 'terrain', exaggeration: 1.3});
    target.addSource('events', {type: 'geojson', data: markerData(), generateId: true, cluster: true,
      clusterRadius: 30, clusterMaxZoom: 15});
    // No slot: the markers draw above the basemap, including its place names.
    const circle = (id, clustered, radius) => target.addLayer({id, type: 'circle', source: 'events',
      filter: clustered ? ['has', 'point_count'] : ['!', ['has', 'point_count']],
      paint: {'circle-color': '#276390', 'circle-radius': radius, 'circle-stroke-width': 1.5,
        'circle-stroke-color': ['case', ['boolean', ['feature-state', 'hover'], false], '#142643', '#ffffff'],
        'circle-emissive-strength': 1}});
    circle('event-clusters', true, ['step', ['get', 'point_count'], 13, 10, 17, 50, 21, 150, 26]);
    circle('event-points', false, 6);
    target.addLayer({id: 'event-counts', type: 'symbol', source: 'events', filter: ['has', 'point_count'],
      layout: {'text-field': ['get', 'point_count_abbreviated'], 'text-size': 11,
        'text-font': ['DIN Pro Bold', 'Arial Unicode MS Bold'],
        'text-allow-overlap': true, 'text-ignore-placement': true},
      paint: {'text-color': '#ffffff', 'text-emissive-strength': 1}});
  }

  // Resolves once the style is ready; rejects, leaving no map behind, if it cannot load.
  function createMap(token) {
    return new Promise((resolve, reject) => {
      let target, timeout, ready = false;
      const fail = (cause) => {
        clearTimeout(timeout);
        target?.remove();
        container.replaceChildren();
        console.warn('The map could not load.', cause?.message || '');
        reject(new Error('The map could not load.'));
      };
      try {
        target = new window.mapboxgl.Map({
          accessToken: token, container, style: 'mapbox://styles/mapbox/standard', projection: 'globe',
          config: {basemap: {theme: 'faded', lightPreset: 'day', showPointOfInterestLabels: false,
            showTransitLabels: false, colorWater: '#bdd5ed', colorGreenspace: '#e0ebe2'}},
          center, zoom: startZoom(), minZoom: .5, maxZoom: 18, maxPitch: 70, attributionControl: false,
          // On touch screens one finger scrolls the page and two fingers move the map.
          cooperativeGestures: matchMedia('(pointer: coarse)').matches,
        });
        // Credits stay one tap away behind the (i) button at every width.
        target.addControl(new window.mapboxgl.AttributionControl({compact: true}));
      } catch (error) {
        fail(error);
        return;
      }
      timeout = setTimeout(() => fail(new Error('Timed out.')), 20000);
      // Before the style is ready an error is fatal; afterwards it is a tile or glyph that
      // the map can do without.
      target.on('error', (event) => {
        if (!ready) fail(event.error);
        else console.warn('Map:', event.error?.message);
      });
      target.once('style.load', () => {
        clearTimeout(timeout);
        ready = true;
        try {
          addLayers(target);
        } catch (error) {
          fail(error);
          return;
        }
        resolve(target);
      });
    });
  }

  async function startMap() {
    showMessage('');
    const [token] = await Promise.all([loadToken(), loadLibrary()]);
    // The visitor left the page while loading; create the map when they return.
    if (!container.clientWidth || !container.clientHeight) return false;
    map = await createMap(token);
    // The events may have changed while the style was loading.
    updateMarkers();
    map.on('click', (event) => {
      const feature = markerAt(event.point);
      if (!feature) return;
      if (feature.properties.cluster) openCluster(feature);
      else openPoint(feature);
    });
    map.on('mousemove', (event) => hover(markerAt(event.point)?.id));
    map.on('mouseout', () => hover());
    map.on('zoom', updateZoomButtons);
    updateZoomButtons();
    return true;
  }

  function openMap() {
    starting ||= startMap().then((created) => {
      if (!created) starting = undefined;
    }).catch((error) => {
      starting = undefined;
      showMessage(error.message);
    });
  }

  new ResizeObserver(() => {
    // A hidden page has no size; resizing then would discard the real one.
    if (container.clientWidth && container.clientHeight) map?.resize();
  }).observe(container);

  get('mapZoomIn').onclick = () => map?.zoomIn(reducedMotion.matches ? {duration: 0} : {});
  get('mapZoomOut').onclick = () => map?.zoomOut(reducedMotion.matches ? {duration: 0} : {});
  get('mapReset').onclick = () => {
    selected = undefined;
    shown = pageSize;
    updateList();
    if (map) moveTo({center, zoom: startZoom(), pitch: 0, bearing: 0});
  };
  filter.addEventListener('change', () => {
    shown = pageSize;
    update();
  });
  search.addEventListener('input', () => {
    selected = undefined;
    shown = pageSize;
    // Wait for a pause in typing before rebuilding the list and markers.
    clearTimeout(searchTimer);
    searchTimer = setTimeout(update, 200);
  });
  updateZoomButtons();

  window.loadCaliforniaMap = (seasonId, loadEvents) => {
    openMap();
    if (seasonId && season !== seasonId) {
      season = seasonId;
      failure = false;
      selected = undefined;
      shown = pageSize;
      loadEvents(seasonId).then((rows) => {
        if (season !== seasonId) return;
        calendar = rows;
        events = rows.filter((event) => event.sku)
          .sort((a,b) => (a.start || '').localeCompare(b.start || ''));
        update();
      }).catch(() => {
        if (season !== seasonId) return;
        season = undefined;
        failure = true;
        updateList();
      });
    }
    update();
  };
})();
