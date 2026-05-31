import { Controller } from "@hotwired/stimulus";

// Collapsible split-transaction group card.
// Header acts as the toggle; children list expands/collapses.
// Default state is expanded.
export default class extends Controller {
  static targets = ["header", "children", "chevron"];

  toggle(event) {
    // Ignore toggles that originate from interactive controls inside the header
    // (edit / unsplit actions handle their own clicks).
    if (event && event.type === "keydown") {
      event.preventDefault();
    }

    const collapsed = this.childrenTarget.classList.toggle("is-collapsed");
    if (this.hasChevronTarget) {
      this.chevronTarget.classList.toggle("-rotate-90", collapsed);
    }
    if (this.hasHeaderTarget) {
      this.headerTarget.setAttribute("aria-expanded", String(!collapsed));
    }
  }

  // Prevents header toggle when interacting with action buttons (edit/unsplit).
  stop(event) {
    event.stopPropagation();
  }
}
