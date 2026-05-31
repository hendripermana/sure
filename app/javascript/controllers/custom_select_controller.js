import { autoUpdate, computePosition, flip, offset, shift } from "@floating-ui/dom";
import { Controller } from "@hotwired/stimulus";

/**
 * Self-contained custom select controller for form dropdowns.
 *
 * This controller manages its own dropdown panel using floating-ui for
 * positioning, WITHOUT relying on DS::Menu (which moves content to
 * document.body, breaking Stimulus scope for data-action and targets).
 *
 * Architecture:
 * - The trigger button toggles a dropdown panel
 * - The dropdown panel stays in the DOM under this controller's element
 * - floating-ui positions the panel using position:fixed (escapes overflow:hidden)
 * - All targets and actions remain in scope — no cross-controller hacks needed
 */
export default class extends Controller {
  static targets = ["hiddenInput", "triggerContent", "trigger", "dropdown", "filterInput"];

  connect() {
    this._open = false;
    this._outsideClickHandler = this._handleOutsideClick.bind(this);
    this._keydownHandler = this._handleKeydown.bind(this);
  }

  disconnect() {
    this._closeDropdown();
    this._stopAutoUpdate();
  }

  // -- Actions (wired via data-action in the template) --

  toggle(event) {
    event.preventDefault();
    event.stopPropagation();

    if (this._open) {
      this._closeDropdown();
    } else {
      this._openDropdown();
    }
  }

  selectOption(event) {
    const button = event.currentTarget;
    const value = button.getAttribute("data-value");

    // Update hidden input
    this.hiddenInputTarget.value = value;
    this.hiddenInputTarget.dispatchEvent(new Event("change", { bubbles: true }));

    // Copy badge into the trigger display
    const badge = button.querySelector("[data-badge]");
    if (badge) {
      this.triggerContentTarget.innerHTML = "";
      this.triggerContentTarget.appendChild(badge.cloneNode(true));
    }

    this._closeDropdown();
  }

  filter(event) {
    const query = event.target.value.toLowerCase();
    const items = this.dropdownTarget.querySelectorAll("[data-filter-name]");
    let anyVisible = false;

    items.forEach((item) => {
      const name = item.getAttribute("data-filter-name").toLowerCase();
      const visible = name.includes(query);
      item.style.display = visible ? "" : "none";
      if (visible) anyVisible = true;
    });

    // Toggle empty message
    const emptyMsg = this.dropdownTarget.querySelector("[data-empty-message]");
    if (emptyMsg) {
      emptyMsg.classList.toggle("hidden", anyVisible);
    }
  }

  // -- Private --

  _openDropdown() {
    if (this._open) return;
    this._open = true;

    this.dropdownTarget.classList.remove("hidden");

    // Position with floating-ui using fixed strategy (escapes overflow:hidden)
    this._startAutoUpdate();

    // Focus search input if present
    if (this.hasFilterInputTarget) {
      // Small delay to let the dropdown render before focusing
      requestAnimationFrame(() => {
        this.filterInputTarget.focus();
      });
    }

    // Listen for outside clicks and escape key
    document.addEventListener("click", this._outsideClickHandler, true);
    document.addEventListener("keydown", this._keydownHandler);
  }

  _closeDropdown() {
    if (!this._open) return;
    this._open = false;

    if (this.hasDropdownTarget) {
      this.dropdownTarget.classList.add("hidden");
    }

    this._stopAutoUpdate();
    document.removeEventListener("click", this._outsideClickHandler, true);
    document.removeEventListener("keydown", this._keydownHandler);
  }

  _handleOutsideClick(event) {
    if (!this.element.contains(event.target) && !this.dropdownTarget.contains(event.target)) {
      this._closeDropdown();
    }
  }

  _handleKeydown(event) {
    if (event.key === "Escape") {
      this._closeDropdown();
      if (this.hasTriggerTarget) this.triggerTarget.focus();
    }
  }

  _startAutoUpdate() {
    if (this._cleanup || !this.hasTriggerTarget || !this.hasDropdownTarget) return;

    this._cleanup = autoUpdate(this.triggerTarget, this.dropdownTarget, () => {
      this._updatePosition();
    });
  }

  _stopAutoUpdate() {
    if (this._cleanup) {
      this._cleanup();
      this._cleanup = null;
    }
  }

  _updatePosition() {
    if (!this.hasTriggerTarget || !this.hasDropdownTarget) return;

    computePosition(this.triggerTarget, this.dropdownTarget, {
      placement: "bottom-start",
      middleware: [
        offset(4),
        flip({ fallbackPlacements: ["top-start", "top-end", "bottom-end"] }),
        shift({ padding: 8 }),
      ],
      strategy: "fixed",
    }).then(({ x, y }) => {
      if (!this.hasDropdownTarget) return;

      Object.assign(this.dropdownTarget.style, {
        position: "fixed",
        left: `${x}px`,
        top: `${y}px`,
      });
    });
  }
}
