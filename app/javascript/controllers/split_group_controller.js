import { Controller } from "@hotwired/stimulus";

// Collapsible split-transaction group card.
// - Header acts as the toggle; children list expands/collapses.
// - Default state is expanded.
// - Remembers collapsed/expanded state per parent across reloads (localStorage).
// - Plays a subtle staggered reveal when expanding.
export default class extends Controller {
  static targets = ["header", "children", "chevron"];
  static values = { id: String };

  connect() {
    // Restore persisted state without animating.
    if (this.idValue && this._storedCollapsed()) {
      this._setCollapsed(true, { animate: false });
    }
  }

  toggle(event) {
    if (event && event.type === "keydown") {
      if (event.target !== this.headerTarget) {
        return;
      }
      event.preventDefault();
    }

    const willCollapse = !this.childrenTarget.classList.contains("is-collapsed");
    this._setCollapsed(willCollapse, { animate: true });
    this._persist(willCollapse);
  }

  // Prevents header toggle when interacting with the actions menu or account link.
  stop(event) {
    event.stopPropagation();
  }

  _setCollapsed(collapsed, { animate } = { animate: true }) {
    this.childrenTarget.classList.toggle("is-collapsed", collapsed);

    if (this.hasChevronTarget) {
      this.chevronTarget.classList.toggle("-rotate-90", collapsed);
    }
    if (this.hasHeaderTarget) {
      this.headerTarget.setAttribute("aria-expanded", String(!collapsed));
    }

    if (!collapsed && animate) {
      this._playStagger();
    }
  }

  _playStagger() {
    const list = this.childrenTarget;
    list.classList.remove("just-expanded");
    // Force reflow so the animation re-triggers on every expand.
    void list.offsetWidth;
    list.classList.add("just-expanded");
    if (this._staggerTimeout) clearTimeout(this._staggerTimeout);
    this._staggerTimeout = setTimeout(() => list.classList.remove("just-expanded"), 600);
  }

  _persist(collapsed) {
    if (!this.idValue) return;
    try {
      window.localStorage.setItem(this._storageKey(), collapsed ? "1" : "0");
    } catch (_e) {
      /* localStorage unavailable (private mode) — ignore */
    }
  }

  _storedCollapsed() {
    try {
      return window.localStorage.getItem(this._storageKey()) === "1";
    } catch (_e) {
      return false;
    }
  }

  _storageKey() {
    return `split-group-collapsed:${this.idValue}`;
  }

  disconnect() {
    if (this._staggerTimeout) clearTimeout(this._staggerTimeout);
  }
}
