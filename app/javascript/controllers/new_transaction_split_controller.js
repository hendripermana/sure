import { Controller } from "@hotwired/stimulus";

// Controls the "Split Transaction" section of the new transaction form.
//
// Responsibilities:
//   - Toggle the split UI on/off (with collapse animation)
//   - Add / remove / reindex split rows
//   - Keep the "remaining" balance indicator in sync with the parent amount
//   - Disable the submit button until the splits balance
//
// All user-facing strings are injected from the server via the
// `i18n` Stimulus Object value so this controller stays free of
// hardcoded, untranslatable text.
export default class extends Controller {
  static targets = [
    "checkbox", // Checkbox toggle to split
    "fields", // Container for split inputs
    "parentCategory", // Main category dropdown container
    "rowsContainer", // Container where rows are appended
    "row", // Individual split row
    "amountInput", // Amount input in split row
    "remaining", // Text display for remaining amount
    "remainingIcon", // Icon inside the remaining card
    "remainingContainer", // Remaining card wrapper
    "error", // Error message wrapper
    "submitButton", // Form submit button
  ];

  static values = { i18n: Object };

  // Magic numbers extracted to named constants for clarity.
  static MINIMUM_SPLITS = 2;
  static COLLAPSE_ANIMATION_DURATION_MS = 400;
  static BALANCE_TOLERANCE = 0.005; // Floating-point comparison tolerance

  // Lucide "trash-2" icon, mirrors the server-side `icon("trash-2")` helper.
  static REMOVE_ICON_SVG = `
    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="w-4 h-4" aria-hidden="true">
      <path d="M3 6h18"/><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6"/><path d="M8 6V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"/><line x1="10" x2="10" y1="11" y2="17"/><line x1="14" x2="14" y1="11" y2="17"/>
    </svg>`;

  static BALANCED_ICON_SVG = `
    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
      <path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd" />
    </svg>`;

  static UNBALANCED_ICON_SVG = `
    <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20" aria-hidden="true">
      <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
    </svg>`;

  connect() {
    // Bind handlers once so the same reference can be removed on disconnect.
    this._onParentAmountInput = this.onParentAmountInput.bind(this);
    this._onKeydown = this._handleKeydown.bind(this);

    this._parentAmountField = document.getElementById("entry_amount");
    if (this._parentAmountField) {
      this._parentAmountField.addEventListener("input", this._onParentAmountInput);
    }
    this.element.addEventListener("keydown", this._onKeydown);

    this.toggle();
  }

  disconnect() {
    if (this._parentAmountField && this._onParentAmountInput) {
      this._parentAmountField.removeEventListener("input", this._onParentAmountInput);
    }
    if (this._onKeydown) {
      this.element.removeEventListener("keydown", this._onKeydown);
    }
    if (this.hideTimeout) clearTimeout(this.hideTimeout);
  }

  // Translation lookup with a safe fallback when a key is missing.
  t(key, fallback = "") {
    const dict = this.hasI18nValue ? this.i18nValue : {};
    return dict[key] ?? fallback;
  }

  // Toggle display of split fields and disable the main category field.
  toggle() {
    const isSplit = this.checkboxTarget.checked;

    // Collapse / expand the parent category container.
    if (this.hasParentCategoryTarget) {
      const select = this.parentCategoryTarget.querySelector("select, input[type='hidden']");
      if (select) {
        select.disabled = isSplit;
        if (isSplit) {
          select.removeAttribute("required");
          this.parentCategoryTarget.classList.add("collapsible-hidden");
          this.parentCategoryTarget.classList.remove("collapsible-visible");
        } else {
          this.parentCategoryTarget.classList.remove("collapsible-hidden");
          this.parentCategoryTarget.classList.add("collapsible-visible");
        }
      }
    }

    // Collapse / expand the split fields container with an animation.
    if (isSplit) {
      this.fieldsTarget.classList.remove("hidden");
      requestAnimationFrame(() => {
        this.fieldsTarget.classList.remove("collapsible-hidden");
        this.fieldsTarget.classList.add("collapsible-visible");
      });
    } else {
      this.fieldsTarget.classList.add("collapsible-hidden");
      this.fieldsTarget.classList.remove("collapsible-visible");
      if (this.hideTimeout) clearTimeout(this.hideTimeout);
      this.hideTimeout = setTimeout(() => {
        if (!this.checkboxTarget.checked) {
          this.fieldsTarget.classList.add("hidden");
        }
      }, this.constructor.COLLAPSE_ANIMATION_DURATION_MS);
    }

    // Toggle required/disabled state of inputs inside split rows.
    this.rowTargets.forEach((row) => {
      row.querySelectorAll("input[name], select[name]").forEach((input) => {
        input.disabled = !isSplit;
        if (isSplit) {
          if (!input.name.includes("category_id")) {
            input.setAttribute("required", "required");
          }
        } else {
          input.removeAttribute("required");
        }
      });
    });

    if (isSplit) {
      // Always start with at least the minimum number of rows.
      while (this.rowCount < this.constructor.MINIMUM_SPLITS) {
        this.addRow();
      }
      this.updateRemaining();
    } else if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false;
    }
  }

  get rowCount() {
    return this.rowTargets.length;
  }

  getParentAmount() {
    if (this._parentAmountField) {
      return Math.abs(Number.parseFloat(this._parentAmountField.value)) || 0;
    }
    return 0;
  }

  onParentAmountInput() {
    if (this.checkboxTarget.checked) {
      this.updateRemaining();
    }
  }

  addRow() {
    const index = this.rowCount;
    const container = this.rowsContainerTarget;

    const row = document.createElement("div");
    row.classList.add("p-3", "md:p-4", "rounded-xl", "border", "border-secondary", "bg-container", "shadow-xs");
    row.dataset.newTransactionSplitTarget = "row";

    // Clone the category custom-select from the template/first row.
    const existingCategorySelect = container.querySelector(".category-select-container");
    let categorySelectHTML = "";
    if (existingCategorySelect) {
      const cloned = existingCategorySelect.cloneNode(true);
      cloned.classList.remove("flex-1", "min-w-0");
      cloned.classList.add("w-full", "md:flex-1", "md:min-w-0");
      const hiddenInput = cloned.querySelector("input[type='hidden']");
      if (hiddenInput) {
        hiddenInput.name = `entry[splits][${index}][category_id]`;
        hiddenInput.value = "";
        hiddenInput.dataset.fieldType = "category_id";
        hiddenInput.disabled = !this.checkboxTarget.checked;
        hiddenInput.removeAttribute("required");
      }
      const triggerContent = cloned.querySelector("[data-custom-select-target='triggerContent']");
      if (triggerContent) {
        triggerContent.innerHTML = `<span class="text-secondary text-sm font-medium">${this.t("category_prompt", "Select category")}</span>`;
      }
      categorySelectHTML = cloned.outerHTML;
    }

    row.innerHTML = `
      <div class="space-y-3 md:space-y-0 md:flex md:flex-nowrap md:items-end md:gap-3">
        <div class="w-full md:flex-1 md:min-w-0">
          <label class="text-xs font-semibold text-secondary uppercase tracking-wider block mb-1.5">${this.t("name_label", "Name")}</label>
          <input type="text"
                 name="entry[splits][${index}][name]"
                 placeholder="${this.t("name_placeholder", "Split name")}"
                 aria-label="${this.t("name_label", "Name")}"
                 class="wise-split-row-input"
                 required
                 autocomplete="off"
                 data-field-type="name"
                 data-new-transaction-split-target="nameInput"
                 data-action="input->new-transaction-split#validateRow">
        </div>
        <div class="w-full md:w-32 md:flex-shrink-0">
          <label class="text-xs font-semibold text-secondary uppercase tracking-wider block mb-1.5">${this.t("amount_label", "Amount")}</label>
          <input type="number"
                 name="entry[splits][${index}][amount]"
                 placeholder="${this.t("amount_placeholder", "0.00")}"
                 aria-label="${this.t("amount_label", "Amount")}"
                 step="0.01"
                 class="wise-split-row-input"
                 required
                 autocomplete="off"
                 data-field-type="amount"
                 data-new-transaction-split-target="amountInput"
                 data-action="input->new-transaction-split#updateRemaining input->new-transaction-split#validateRow">
        </div>
        ${categorySelectHTML}
        <div class="w-full md:w-auto md:flex-shrink-0 flex md:block">
          <button type="button"
                  class="split-remove-btn w-full md:w-auto"
                  data-action="click->new-transaction-split#removeRow"
                  title="${this.t("remove_label", "Remove split")}"
                  aria-label="${this.t("remove_label", "Remove split")}">
            ${this.constructor.REMOVE_ICON_SVG}
          </button>
        </div>
      </div>
    `;

    container.appendChild(row);
    this.updateRemaining();
  }

  removeRow(event) {
    event.stopPropagation();
    const row = event.target.closest("[data-new-transaction-split-target='row']");
    if (row && this.rowCount > this.constructor.MINIMUM_SPLITS) {
      row.remove();
      this.reindexRows();
      this.updateRemaining();
    }
  }

  reindexRows() {
    this.rowTargets.forEach((row, index) => {
      row.dataset.rowIndex = index;
      ["name", "amount", "category_id"].forEach((fieldType) => {
        const input = row.querySelector(`[data-field-type="${fieldType}"]`);
        if (input) {
          input.name = `entry[splits][${index}][${fieldType}]`;
        }
      });
    });
  }

  // Provides immediate visual feedback for empty required fields.
  validateRow(event) {
    const input = event.target;
    const isEmpty = input.value.trim() === "";
    input.classList.toggle("wise-split-row-input--error", isEmpty);
  }

  // Removes the focused row when the user presses Delete (keyboard a11y).
  _handleKeydown(event) {
    if (event.key !== "Delete") return;
    const target = event.target;
    // Don't hijack Delete while editing a text field.
    if (target && (target.tagName === "INPUT" || target.tagName === "TEXTAREA")) return;

    const row = target?.closest("[data-new-transaction-split-target='row']");
    if (row && this.rowCount > this.constructor.MINIMUM_SPLITS) {
      event.preventDefault();
      row.remove();
      this.reindexRows();
      this.updateRemaining();
    }
  }

  updateRemaining() {
    const total = this.getParentAmount();
    const sum = this.rowTargets.reduce((acc, row) => {
      const input = row.querySelector("input[type='number']");
      return acc + (Number.parseFloat(input?.value) || 0);
    }, 0);

    const remaining = total - sum;
    const balanced = Math.abs(remaining) < this.constructor.BALANCE_TOLERANCE;

    this.remainingTarget.textContent = balanced ? "0.00" : remaining.toFixed(2);

    const container = this.remainingContainerTarget;
    container.classList.toggle("remaining-box--balanced", balanced);
    container.classList.toggle("remaining-box--unbalanced", !balanced);

    if (this.hasRemainingIconTarget) {
      this.remainingIconTarget.innerHTML = balanced
        ? this.constructor.BALANCED_ICON_SVG
        : this.constructor.UNBALANCED_ICON_SVG;
    }

    if (this.hasErrorTarget) {
      this.errorTarget.classList.toggle("hidden", balanced);
    }

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !balanced;
    }
  }
}
