// Event data for the Map view. No DOM or MapLibre here, so it can be tested in Node.
// Coordinates come from the events API (RobotEvents venue locations); nothing is geocoded
// or invented, and events without coordinates stay in the list but get no marker.

const usNames = /^(united states(?: of america)?|usa|us)$/i;

export function usEvents(rows) {
  return rows.filter((event) => usNames.test(event.location?.country) && event.sku)
    .sort((a, b) => (a.start || '').localeCompare(b.start || ''));
}

/** [longitude, latitude], or null when the event has no usable location. */
export function coordinates(event) {
  const {latitude, longitude} = event.location || {};
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude)) return null;
  // (0, 0) is a placeholder for "unknown", never a U.S. venue.
  if (Math.abs(latitude) > 90 || Math.abs(longitude) > 180 || (!latitude && !longitude)) return null;
  return [longitude, latitude];
}

// An event counts as upcoming until the end of its last day.
export function isUpcoming(event, now = Date.now()) {
  return Date.parse(event.end || event.start) + 86400000 > now;
}

export function filterEvents(events, {query = '', when = 'all', now = Date.now()} = {}) {
  const needle = query.trim().toLowerCase();
  return events.filter((event) => {
    if (needle && ![event.name, event.location?.city, event.sku].join(' ').toLowerCase().includes(needle)) return false;
    if (when === 'all') return true;
    const end = Date.parse(event.end || event.start) + 86400000;
    return when === 'upcoming' ? end > now : end <= now;
  });
}

export function venueKey(event) {
  const point = coordinates(event);
  return point ? point[0].toFixed(5) + ',' + point[1].toFixed(5) : null;
}

/**
 * One entry per distinct location. Many venues host several events at identical
 * coordinates, which separate markers could never pull apart at any zoom.
 */
export function groupVenues(events) {
  const venues = new Map();
  for (const event of events) {
    const key = venueKey(event);
    if (!key) continue;
    if (!venues.has(key)) venues.set(key, {key, coordinates: coordinates(event), events: []});
    venues.get(key).events.push(event);
  }
  return venues;
}

export function venueFeatures(venues, now = Date.now()) {
  return {
    type: 'FeatureCollection',
    features: [...venues.values()].map(({key, coordinates: point, events}) => ({
      type: 'Feature',
      geometry: {type: 'Point', coordinates: point},
      properties: {
        key,
        count: events.length,
        upcoming: events.some((event) => isUpcoming(event, now)) ? 1 : 0,
      },
    })),
  };
}

/** [[west, south], [east, north]] around every located event, or null. */
export function eventBounds(events) {
  let bounds = null;
  for (const event of events) {
    const point = coordinates(event);
    if (!point) continue;
    if (!bounds) bounds = [[...point], [...point]];
    for (const axis of [0, 1]) {
      bounds[0][axis] = Math.min(bounds[0][axis], point[axis]);
      bounds[1][axis] = Math.max(bounds[1][axis], point[axis]);
    }
  }
  return bounds;
}

export function eventDates(event, locale) {
  const format = new Intl.DateTimeFormat(locale, {month: 'short', day: 'numeric', timeZone: 'UTC'});
  const [start, end] = [event.start, event.end].map((value) => Date.parse(value));
  if (!Number.isFinite(start)) return '';
  const first = format.format(start);
  const last = Number.isFinite(end) ? format.format(end) : first;
  return first === last ? first : first + ' – ' + last;
}
