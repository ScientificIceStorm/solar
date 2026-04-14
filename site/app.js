const DEFAULT_METHOD_NOTE =
  "Match-only rating weighted by opponent strength, elimination depth, and event importance.";

const seasonSelect = document.getElementById("seasonSelect");
const gradeSelect = document.getElementById("gradeSelect");
const regionSelect = document.getElementById("regionSelect");
const searchInput = document.getElementById("searchInput");
const methodologyNote = document.getElementById("methodologyNote");
const rowsContainer = document.getElementById("rows");
const loadingState = document.getElementById("loadingState");
const warningBanner = document.getElementById("warningBanner");
const errorBanner = document.getElementById("errorBanner");
const metricHeader = document.getElementById("metricHeader");
const resultsLabel = document.getElementById("resultsLabel");
const statusNote = document.getElementById("statusNote");

const pageState = {
  seasonId: null,
  gradeLevel: "High School",
  region: "All Regions",
  search: "",
  data: null,
  loadToken: 0,
};

async function bootstrap() {
  bindEvents();

  try {
    setLoading("Loading seasons...");
    const payload = await fetchJson("/api/seasons");

    renderSeasons(payload.seasons || []);
    renderGradeLevels(
      payload.gradeLevels || ["High School", "Middle School", "College"],
    );

    pageState.seasonId = seasonSelect.value;
    pageState.gradeLevel = gradeSelect.value;

    await loadRankings();
  } catch (error) {
    showError(error.message || String(error));
  }
}

function bindEvents() {
  seasonSelect.addEventListener("change", async () => {
    pageState.seasonId = seasonSelect.value;
    await loadRankings();
  });

  gradeSelect.addEventListener("change", async () => {
    pageState.gradeLevel = gradeSelect.value;
    await loadRankings();
  });

  regionSelect.addEventListener("change", () => {
    pageState.region = regionSelect.value;
    renderRows();
  });

  searchInput.addEventListener("input", () => {
    pageState.search = searchInput.value.trim().toLowerCase();
    renderRows();
  });
}

async function loadRankings() {
  if (!pageState.seasonId) {
    return;
  }

  const loadToken = ++pageState.loadToken;
  hideError();
  setLoading("Loading live rankings...");

  try {
    const params = new URLSearchParams({
      seasonId: pageState.seasonId,
      gradeLevel: pageState.gradeLevel,
    });
    const payload = await fetchJson(`/api/rankings?${params.toString()}`);

    if (loadToken !== pageState.loadToken) {
      return;
    }

    pageState.data = payload;
    syncRegions(payload.regions || ["All Regions"]);
    renderRows();
  } catch (error) {
    if (loadToken !== pageState.loadToken) {
      return;
    }

    showError(error.message || String(error));
  }
}

function renderSeasons(seasons) {
  seasonSelect.innerHTML = "";

  seasons.forEach((season) => {
    const option = document.createElement("option");
    option.value = String(season.id);
    option.textContent = season.name || `${season.programName} ${season.id}`;
    seasonSelect.appendChild(option);
  });
}

function renderGradeLevels(gradeLevels) {
  gradeSelect.innerHTML = "";

  gradeLevels.forEach((grade) => {
    const option = document.createElement("option");
    option.value = grade;
    option.textContent = grade;
    gradeSelect.appendChild(option);
  });
}

function syncRegions(regions) {
  const current = regions.includes(pageState.region)
    ? pageState.region
    : "All Regions";

  pageState.region = current;
  regionSelect.innerHTML = "";

  regions.forEach((region) => {
    const option = document.createElement("option");
    option.value = region;
    option.textContent = region;
    option.selected = region === current;
    regionSelect.appendChild(option);
  });
}

function renderRows() {
  const data = pageState.data;
  if (!data) {
    return;
  }

  warningBanner.textContent = data.warning || "";
  warningBanner.classList.toggle("hidden", !data.warning);

  methodologyNote.textContent =
    data.methodology?.summary || DEFAULT_METHOD_NOTE;
  metricHeader.textContent = "Match Rating";

  const filteredRows = (data.matchRows || []).filter(matchesFilters);
  const fragment = document.createDocumentFragment();

  rowsContainer.innerHTML = "";
  loadingState.classList.add("hidden");

  resultsLabel.textContent = `${filteredRows.length} teams loaded`;
  statusNote.textContent = buildStatusNote();

  if (filteredRows.length === 0) {
    loadingState.textContent = "No teams matched the current filters.";
    loadingState.classList.remove("hidden");
    return;
  }

  filteredRows.forEach((row) => {
    fragment.appendChild(buildRow(row));
  });

  rowsContainer.appendChild(fragment);
}

function matchesFilters(row) {
  const regionMatches =
    pageState.region === "All Regions" || row.regionLabel === pageState.region;

  if (!regionMatches) {
    return false;
  }

  if (!pageState.search) {
    return true;
  }

  const haystack = [
    row.teamNumber,
    row.teamName,
    row.organization,
    row.city,
    row.region,
    row.country,
    row.regionLabel,
  ]
    .filter(Boolean)
    .join(" ")
    .toLowerCase();

  return haystack.includes(pageState.search);
}

function buildRow(row) {
  const wrapper = document.createElement("article");
  wrapper.className = "row";

  const rank = document.createElement("div");
  rank.className = "rank-pill";
  rank.textContent = row.rank ?? "--";

  const team = document.createElement("div");
  team.className = "team-block";
  team.innerHTML = `
    <div class="team-line">
      <span class="team-number">${escapeHtml(row.teamNumber || "--")}</span>
      <span class="team-name">${escapeHtml(
        row.teamName || row.organization || "Team profile",
      )}</span>
    </div>
    <div class="team-subtitle">${escapeHtml(teamSubtitle(row))}</div>
  `;

  const metric = document.createElement("div");
  metric.className = "metric-block";
  metric.innerHTML = `
    <div class="metric-main">${escapeHtml(metricValue(row))}</div>
    <div class="metric-sub">${escapeHtml(metricSubtitle(row))}</div>
  `;

  wrapper.append(rank, team, metric);
  return wrapper;
}

function buildStatusNote() {
  return `${pageState.gradeLevel} | ${pageState.region} | season ${pageState.seasonId} | live localhost snapshot`;
}

function teamSubtitle(row) {
  const detail = row.organization || row.city || row.regionLabel || "Team profile";
  return `${detail}${row.regionLabel ? ` | ${row.regionLabel}` : ""}`;
}

function metricValue(row) {
  const rating = Number(row.matchRating ?? 0);
  return Number.isInteger(rating) ? String(rating) : rating.toFixed(1);
}

function metricSubtitle(row) {
  return row.meta || `${row.matchesPlayed || 0} matches`;
}

function setLoading(message) {
  rowsContainer.innerHTML = "";
  loadingState.textContent = message;
  loadingState.classList.remove("hidden");
  resultsLabel.textContent = message;
  statusNote.textContent = "Waiting for the local ranking API.";
  methodologyNote.textContent = DEFAULT_METHOD_NOTE;
}

function showError(message) {
  errorBanner.textContent = message;
  errorBanner.classList.remove("hidden");
  rowsContainer.innerHTML = "";
  loadingState.textContent = "The localhost rankings preview could not load.";
  loadingState.classList.remove("hidden");
  methodologyNote.textContent = DEFAULT_METHOD_NOTE;
}

function hideError() {
  errorBanner.textContent = "";
  errorBanner.classList.add("hidden");
}

async function fetchJson(url) {
  const response = await fetch(url, {
    cache: "no-store",
  });
  const payload = await response.json();

  if (!response.ok) {
    throw new Error(payload.error || `Request failed for ${url}`);
  }

  return payload;
}

function escapeHtml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

bootstrap().catch((error) => showError(error.message || String(error)));
