import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "checkbox", // Checkbox toggle to split
    "fields", // Container for split inputs
    "parentCategory", // Main category dropdown container or input
    "rowsContainer", // Container where rows are appended
    "row", // Individual split row
    "amountInput", // Amount input in split row
    "remaining", // Text display for remaining amount
    "remainingContainer", // Remaining card wrapper
    "error", // Error message wrapper
    "submitButton", // Form submit button
  ];

  connect() {
    this.toggle();

    // Listen to input on parent amount field
    const parentAmountField = document.getElementById("entry_amount");
    if (parentAmountField) {
      parentAmountField.addEventListener("input", this.onParentAmountInput.bind(this));
    }
  }

  disconnect() {
    const parentAmountField = document.getElementById("entry_amount");
    if (parentAmountField) {
      parentAmountField.removeEventListener("input", this.onParentAmountInput.bind(this));
    }
  }

  // Toggle display of split fields and disable main category field with animation
  toggle() {
    const isSplit = this.checkboxTarget.checked;

    // Toggle parentCategory container with animation
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

    // Toggle container visibility with height collapse animation
    if (isSplit) {
      this.fieldsTarget.classList.remove("hidden");
      // Use requestAnimationFrame to trigger transition after unhiding
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
      }, 400); // match transition-all duration-400
    }

    // Toggle required and disabled state of all actual inputs inside split rows
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
      // Ensure we have at least 2 rows
      if (this.rowCount === 0) {
        this.addRow();
        this.addRow();
      } else if (this.rowCount === 1) {
        this.addRow();
      }
      this.updateRemaining();
    } else {
      // If split is not checked, enable form submit
      if (this.hasSubmitButtonTarget) {
        this.submitButtonTarget.disabled = false;
      }
    }
  }

  get rowCount() {
    return this.rowTargets.length;
  }

  // Get parent transaction amount
  getParentAmount() {
    const parentAmountField = document.getElementById("entry_amount");
    if (parentAmountField) {
      return Math.abs(Number.parseFloat(parentAmountField.value)) || 0;
    }
    return 0;
  }

  // Triggered when parent amount changes
  onParentAmountInput() {
    if (this.checkboxTarget.checked) {
      this.updateRemaining();
    }
  }

  addRow() {
    const index = this.rowCount;
    const container = this.rowsContainerTarget;

    const row = document.createElement("div");
    row.classList.add(
      "p-4",
      "rounded-xl",
      "border",
      "border-secondary",
      "bg-container",
      "shadow-xs"
    );
    row.dataset.newTransactionSplitTarget = "row";

    // Clone category select from the template/first row
    const existingCategorySelect = container.querySelector(".category-select-container");
    let categorySelectHTML = "";
    if (existingCategorySelect) {
      const cloned = existingCategorySelect.cloneNode(true);
      const select = cloned.querySelector("select");
      if (select) {
        select.name = `entry[splits][${index}][category_id]`;
        select.value = "";
        select.disabled = !this.checkboxTarget.checked;
        select.removeAttribute("required");
        select.className = "wise-split-row-input";
      }
      const hiddenInput = cloned.querySelector("input[type='hidden']");
      if (hiddenInput) {
        hiddenInput.name = `entry[splits][${index}][category_id]`;
        hiddenInput.value = "";
        hiddenInput.disabled = !this.checkboxTarget.checked;
        hiddenInput.removeAttribute("required");
      }
      const triggerContent = cloned.querySelector("[data-custom-select-target='triggerContent']");
      if (triggerContent) {
        triggerContent.innerHTML = `<span class="text-secondary text-sm font-medium">Select category</span>`;
      }
      categorySelectHTML = cloned.outerHTML;
    }

    row.innerHTML = `
      <div class="flex flex-wrap md:flex-nowrap items-end gap-3">
        <div class="w-full md:flex-1 md:w-auto min-w-0">
          <label class="text-xs font-semibold text-secondary uppercase tracking-wider block mb-1.5">Name</label>
          <input type="text"
                 name="entry[splits][${index}][name]"
                 placeholder="Split name"
                 class="wise-split-row-input"
                 required
                 autocomplete="off"
                 data-new-transaction-split-target="nameInput">
        </div>
        <div class="flex-1 md:flex-none md:w-28">
          <label class="text-xs font-semibold text-secondary uppercase tracking-wider block mb-1.5">Amount</label>
          <input type="number"
                 name="entry[splits][${index}][amount]"
                 placeholder="0.00"
                 step="0.01"
                 class="wise-split-row-input"
                 required
                 autocomplete="off"
                 data-new-transaction-split-target="amountInput"
                 data-action="input->new-transaction-split#updateRemaining">
        </div>
        ${categorySelectHTML}
        <button type="button"
                class="w-8 h-8 shrink-0 flex items-center justify-center rounded-md text-secondary hover:text-primary hover:bg-surface-hover transition-colors"
                data-action="click->new-transaction-split#removeRow">
          <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
        </button>
      </div>
    `;

    container.appendChild(row);
    this.updateRemaining();
  }

  removeRow(event) {
    event.stopPropagation();
    const row = event.target.closest("[data-new-transaction-split-target='row']");
    if (row && this.rowCount > 2) {
      // Keep at least 2 rows
      row.remove();
      this.reindexRows();
      this.updateRemaining();
    }
  }

  reindexRows() {
    this.rowTargets.forEach((row, index) => {
      row.querySelectorAll("[name]").forEach((input) => {
        input.name = input.name.replace(/splits\[\d+\]/, `splits[${index}]`);
      });
    });
  }

  updateRemaining() {
    const total = this.getParentAmount();
    const sum = this.rowTargets.reduce((acc, row) => {
      const input = row.querySelector("input[type='number']");
      return acc + (Number.parseFloat(input.value) || 0);
    }, 0);

    const remaining = total - sum;
    const absRemaining = Math.abs(remaining);
    const balanced = absRemaining < 0.005;

    this.remainingTarget.textContent = balanced ? "0.00" : remaining.toFixed(2);

    const container = this.remainingContainerTarget;

    if (balanced) {
      container.classList.remove("remaining-box--unbalanced");
      container.classList.add("remaining-box--balanced");
    } else {
      container.classList.remove("remaining-box--balanced");
      container.classList.add("remaining-box--unbalanced");
    }

    this.errorTarget.classList.toggle("hidden", balanced);

    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = !balanced;
    }
  }
}
