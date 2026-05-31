import { autoUpdate, computePosition, flip, offset, shift } from "@floating-ui/dom";
import { Controller } from "@hotwired/stimulus";

/**
 * A "menu" can contain arbitrary content including non-clickable items, links, buttons, and forms.
 *
 * Key features:
 * - Uses floating-ui with flip middleware for smart positioning (avoids overflow)
 * - Moves content to body to avoid overflow:hidden clipping issues
 * - Dispatches custom event to close other open menus (prevents stacking)
 * - Stores direct element references since targets are lost when moved to body
 * - Rails 8.1: Properly handles Turbo morph refreshes by cleaning up orphaned content
 * - Re-entry guard on toggle() prevents double-fire from Stimulus reconnect cycles
 */
export default class extends Controller {
  static targets = ["button", "content"];

  static values = {
    show: Boolean,
    placement: { type: String, default: "bottom-end" },
    offset: { type: Number, default: 6 },
  };

  connect() {
    // Generate unique ID for this menu instance to track its content
    this._menuId = `ds-menu-${Date.now()}-${Math.random().toString(36).slice(2, 11)}`;

    // Defensive cleanup: remove any stale listeners from a previous connect()
    // that may not have been properly disconnected (e.g., Turbo morph reconnect)
    this.removeEventListeners();
    this.stopAutoUpdate();

    // Store direct references before moving to body (targets won't work after move)
    this._buttonEl = this.hasButtonTarget ? this.buttonTarget : null;
    this._contentEl = this.hasContentTarget ? this.contentTarget : null;

    if (!this._buttonEl || !this._contentEl) {
      return;
    }

    // Mark content with unique ID for cleanup tracking
    this._contentEl.setAttribute("data-ds-menu-id", this._menuId);

    this.show = this.showValue;
    this.boundUpdate = this.update.bind(this);
    this.addEventListeners();

    // Move content to body to avoid overflow:hidden clipping
    this.moveContentToBody();
    this.startAutoUpdate();
  }

  disconnect() {
    this.removeEventListeners();
    this.stopAutoUpdate();
    this.close();

    // Remove content from body when disconnecting
    this.removeContentFromBody();

    // Clear references
    this._buttonEl = null;
    this._contentEl = null;
  }

  // Move the dropdown content to body to escape overflow:hidden containers
  moveContentToBody() {
    if (this._contentEl && this._contentEl.parentElement !== document.body) {
      this._originalParent = this._contentEl.parentElement;
      this._originalNextSibling = this._contentEl.nextSibling;
      document.body.appendChild(this._contentEl);
    }
  }

  // Restore content to original position when cleaning up
  // Rails 8.1: With Turbo morph refreshes, the original parent may be morphed/replaced,
  // so we need to remove orphaned content from body to prevent accumulation
  removeContentFromBody() {
    if (this._contentEl && document.body.contains(this._contentEl)) {
      try {
        // Try to restore to original position first
        // Use isConnected with optional chaining for cleaner DOM existence check
        if (this._originalParent?.isConnected) {
          if (
            this._originalNextSibling &&
            this._originalParent.contains(this._originalNextSibling)
          ) {
            this._originalParent.insertBefore(this._contentEl, this._originalNextSibling);
          } else {
            this._originalParent.appendChild(this._contentEl);
          }
        } else {
          // Original parent no longer in DOM (Turbo morph replaced it)
          // Remove the orphaned content element to prevent accumulation
          this._contentEl.remove();
        }
      } catch {
        // Failsafe: remove content if any error occurs during restoration
        // Element.remove() is safe and won't throw even if already removed
        this._contentEl.remove();
      }
    }
    this._originalParent = null;
    this._originalNextSibling = null;
  }

  addEventListeners() {
    if (!this._buttonEl) return;

    // Create bound handlers and store them so we can remove them later.
    // IMPORTANT: Each call creates new bound functions, so we must remove
    // any stale handlers BEFORE calling this method.
    this.toggleHandler = this.toggle.bind(this);
    this.keydownHandler = this.handleKeydown.bind(this);
    this.outsideClickHandler = this.handleOutsideClick.bind(this);
    this.turboLoadHandler = this.handleTurboLoad.bind(this);
    this.turboBeforeVisitHandler = this.handleTurboBeforeVisit.bind(this);
    this.turboBeforeRenderHandler = this.handleTurboBeforeRender.bind(this);
    this.closeOtherMenusHandler = this.handleCloseOtherMenus.bind(this);

    this._buttonEl.addEventListener("click", this.toggleHandler);
    this.element.addEventListener("keydown", this.keydownHandler);
    document.addEventListener("click", this.outsideClickHandler);
    document.addEventListener("turbo:load", this.turboLoadHandler);
    document.addEventListener("turbo:before-visit", this.turboBeforeVisitHandler);
    document.addEventListener("turbo:before-render", this.turboBeforeRenderHandler);
    document.addEventListener("ds:menu:close-others", this.closeOtherMenusHandler);
  }

  removeEventListeners() {
    if (this.toggleHandler && this._buttonEl) {
      this._buttonEl.removeEventListener("click", this.toggleHandler);
    }
    if (this.keydownHandler) {
      this.element.removeEventListener("keydown", this.keydownHandler);
    }
    if (this.outsideClickHandler) {
      document.removeEventListener("click", this.outsideClickHandler);
    }
    if (this.turboLoadHandler) {
      document.removeEventListener("turbo:load", this.turboLoadHandler);
    }
    if (this.turboBeforeVisitHandler) {
      document.removeEventListener("turbo:before-visit", this.turboBeforeVisitHandler);
    }
    if (this.turboBeforeRenderHandler) {
      document.removeEventListener("turbo:before-render", this.turboBeforeRenderHandler);
    }
    if (this.closeOtherMenusHandler) {
      document.removeEventListener("ds:menu:close-others", this.closeOtherMenusHandler);
    }

    // Null out handler references so removeEventListeners is idempotent
    this.toggleHandler = null;
    this.keydownHandler = null;
    this.outsideClickHandler = null;
    this.turboLoadHandler = null;
    this.turboBeforeVisitHandler = null;
    this.turboBeforeRenderHandler = null;
    this.closeOtherMenusHandler = null;
  }

  handleTurboLoad() {
    this.close();
  }

  handleTurboBeforeVisit() {
    this.close();
  }

  // Rails 8.1: Handle Turbo morph refreshes - cleanup content before render
  handleTurboBeforeRender() {
    this.close();
    // Proactively remove content from body before Turbo morphs the page
    // This prevents orphaned content accumulation with morph refreshes
    this.removeContentFromBody();
  }

  handleCloseOtherMenus(event) {
    if (event.detail.sourceElement !== this.element && this.show) {
      this.close();
    }
  }

  handleOutsideClick(event) {
    if (!this._contentEl) return;

    if (
      this.show &&
      !this.element.contains(event.target) &&
      !this._contentEl.contains(event.target)
    ) {
      this.close();
    }
  }

  closeOnItemClick(_event) {
    this.close();
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close();
      if (this._buttonEl) this._buttonEl.focus();
    }
  }

  toggle(event) {
    if (!this._contentEl) return;

    // Re-entry guard: prevent double-fire within the same frame.
    // This can happen when Stimulus reconnects the controller during
    // Turbo morph cycles, causing addEventListener to bind twice before
    // the old handler is cleaned up.
    if (this._toggling) return;
    this._toggling = true;
    requestAnimationFrame(() => {
      this._toggling = false;
    });

    if (event) {
      event.preventDefault();
      event.stopPropagation();
    }

    this.show = !this.show;
    this._contentEl.classList.toggle("hidden", !this.show);

    if (this.show) {
      document.dispatchEvent(
        new CustomEvent("ds:menu:close-others", {
          detail: { sourceElement: this.element },
        })
      );

      this.update();
      this.focusFirstElement();
    }
  }

  close() {
    if (!this._contentEl) return;

    this.show = false;
    this._contentEl.classList.add("hidden");
  }

  focusFirstElement() {
    if (!this._contentEl) return;

    const focusableElements =
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])';
    const firstFocusableElement = this._contentEl.querySelectorAll(focusableElements)[0];
    if (firstFocusableElement) {
      firstFocusableElement.focus();
    }
  }

  startAutoUpdate() {
    if (!this._cleanup && this._buttonEl && this._contentEl) {
      this._cleanup = autoUpdate(this._buttonEl, this._contentEl, this.boundUpdate);
    }
  }

  stopAutoUpdate() {
    if (this._cleanup) {
      this._cleanup();
      this._cleanup = null;
    }
  }

  update() {
    if (!this._buttonEl || !this._contentEl) return;

    const isSmallScreen = !window.matchMedia("(min-width: 768px)").matches;

    computePosition(this._buttonEl, this._contentEl, {
      placement: isSmallScreen ? "bottom" : this.placementValue,
      middleware: [
        offset(this.offsetValue),
        flip({ fallbackPlacements: ["top-end", "top-start", "bottom-start"] }),
        shift({ padding: 8 }),
      ],
      strategy: "fixed",
    }).then(({ x, y }) => {
      if (!this._contentEl) return;

      if (isSmallScreen) {
        Object.assign(this._contentEl.style, {
          position: "fixed",
          left: "0px",
          width: "100vw",
          top: `${y}px`,
        });
      } else {
        Object.assign(this._contentEl.style, {
          position: "fixed",
          left: `${x}px`,
          top: `${y}px`,
          width: "",
        });
      }
    });
  }
}
