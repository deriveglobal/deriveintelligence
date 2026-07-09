import {
  renderScreenState,
  renderLoadingSkeleton,
  escapeHtml,
  statusClass
} from '../shared.js';

function groupRoadmapItemsByPhase(items = []) {
  const phases = ["Quick Wins", "Foundation", "Optimization", "Transformation"];
  return phases.map((phase) => ({
    phase,
    items: (items || []).filter((item) => (item.phase || item.roadmap_phase || "Foundation") === phase)
  }));
}

export function renderRoadmapComponent(
  roadmapItems = [],
  emptyStateHtml = "",
  { onItemClick } = {}
) {
  if (!roadmapItems?.length) {
    return emptyStateHtml || renderScreenState("roadmap", "empty");
  }
  return groupRoadmapItemsByPhase(roadmapItems).map((phase) => `
    <article class="roadmap-card">
      <span class="eyebrow">${escapeHtml(phase.phase)}</span>
      <h3>${escapeHtml(phase.phase)}</h3>
      <ul>${phase.items.map((item) => {
        const itemContent = escapeHtml(item.title);
        return onItemClick
          ? `<li><button class="text-button" data-component-roadmap-item="${escapeHtml(item.id || item.title)}" type="button">${itemContent}</button></li>`
          : `<li>${itemContent}</li>`;
      }).join("") || "<li>No items yet</li>"}</ul>
    </article>
  `).join("");
}
