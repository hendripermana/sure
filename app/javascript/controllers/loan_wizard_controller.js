import { Controller } from "@hotwired/stimulus";

const CARD_SELECTED_CLASSES = [
  "border-primary",
  "bg-primary/5",
  "ring-2",
  "ring-primary/15",
  "shadow-sm",
];

const CARD_UNSELECTED_CLASSES = ["border-secondary", "bg-container"];

const ICON_SELECTED_CLASSES = ["bg-primary/10"];

const ICON_UNSELECTED_CLASSES = ["bg-surface"];

const ICON_SVG_SELECTED_CLASSES = ["text-primary"];

const ICON_SVG_UNSELECTED_CLASSES = ["text-secondary"];

const INDICATOR_SELECTED_CLASSES = ["flex", "border-primary", "bg-primary/10", "text-primary"];

const INDICATOR_UNSELECTED_CLASSES = ["hidden", "border-secondary", "text-secondary"];

export default class extends Controller {
  static targets = [
    "content",
    "counterpartyName",
    "principalAmount",
    "interestRate",
    "termMonths",
    "monthlyPayment",
    "totalInterest",
    "totalAmount",
    "interestFields",
    "loanTypeCard",
    "loanTypeRadio",
    "stepIndicator",
    "stepCircle",
    "progressBar",
    "personalFields",
    "institutionalFields",
    "backButton",
  ];
  static values = {
    currentStep: String,
    totalSteps: Number,
    loanType: String,
  };

  connect() {
    this.ensureLoanTypeValue();
    this.calculatePayment();
    this.updateStepVisibility();
    this.markSelectedCard(this.loanTypeValue);
  }

  selectLoanType(event) {
    const selectedType = event.currentTarget.dataset.loanType;

    const radioButton = event.currentTarget.querySelector('input[type="radio"]');
    if (radioButton) {
      radioButton.checked = true;
      radioButton.dispatchEvent(new Event("change", { bubbles: true }));
    }

    this.loanTypeValue = selectedType;
    this.updateFieldsVisibility(selectedType);
  }

  ensureLoanTypeValue() {
    if (this.loanTypeValue && this.loanTypeValue.length > 0) return;

    if (this.hasLoanTypeRadioTarget) {
      const checked = this.loanTypeRadioTargets.find((radio) => radio.checked);
      if (checked) {
        this.loanTypeValue = checked.value;
        return;
      }
    }

    const fallback = this.element.querySelector(
      'input[type="radio"][name="loan[debt_kind]"]:checked'
    );
    this.loanTypeValue = fallback ? fallback.value : "personal";
  }

  updateFieldsVisibility(loanType) {
    const type = loanType || this.loanTypeValue || "personal";

    if (this.hasPersonalFieldsTarget) {
      this.toggleFieldSection(this.personalFieldsTarget, type === "personal");
    }

    if (this.hasInstitutionalFieldsTarget) {
      this.toggleFieldSection(this.institutionalFieldsTarget, type === "institutional");
    }

    // Update any additional containers that rely on data attributes
    this.element
      .querySelectorAll('[data-loan-wizard-target="personalFields"]')
      .forEach((container) => {
        this.toggleFieldSection(container, type === "personal");
      });

    this.element
      .querySelectorAll('[data-loan-wizard-target="institutionalFields"]')
      .forEach((container) => {
        this.toggleFieldSection(container, type === "institutional");
      });

    this.markSelectedCard(type);
  }

  toggleFieldSection(element, shouldShow) {
    if (!element) return;

    element.classList.toggle("hidden", !shouldShow);
    element.style.display = shouldShow ? "block" : "none";
  }

  markSelectedCard(selectedType) {
    if (!this.hasLoanTypeCardTarget) return;

    const activeType = selectedType || this.loanTypeValue || "personal";

    this.loanTypeCardTargets.forEach((card) => {
      const isSelected = card.dataset.loanType === activeType;

      CARD_SELECTED_CLASSES.forEach((klass) => {
        card.classList.toggle(klass, isSelected);
      });
      CARD_UNSELECTED_CLASSES.forEach((klass) => {
        card.classList.toggle(klass, !isSelected);
      });

      const iconContainer = card.querySelector('[data-loan-type-role="icon"]');
      if (iconContainer) {
        ICON_SELECTED_CLASSES.forEach((klass) => {
          iconContainer.classList.toggle(klass, isSelected);
        });
        ICON_UNSELECTED_CLASSES.forEach((klass) => {
          iconContainer.classList.toggle(klass, !isSelected);
        });
      }

      const iconSvg = iconContainer?.querySelector("svg");
      if (iconSvg) {
        ICON_SVG_SELECTED_CLASSES.forEach((klass) => {
          iconSvg.classList.toggle(klass, isSelected);
        });
        ICON_SVG_UNSELECTED_CLASSES.forEach((klass) => {
          iconSvg.classList.toggle(klass, !isSelected);
        });
      }

      const indicator = card.querySelector('[data-loan-type-role="indicator"]');
      if (indicator) {
        INDICATOR_SELECTED_CLASSES.forEach((klass) => {
          indicator.classList.toggle(klass, isSelected);
        });
        INDICATOR_UNSELECTED_CLASSES.forEach((klass) => {
          indicator.classList.toggle(klass, !isSelected);
        });
      }
    });
  }

  updateStepVisibility() {
    const currentStep = this.currentStepValue || "type";

    // Use correct selector - data-step-content becomes data-step-content in HTML
    const stepContents = this.element.querySelectorAll("[data-step-content]");

    stepContents.forEach((content) => {
      const stepName = content.dataset.stepContent;
      const isVisible = stepName === currentStep;

      content.style.display = isVisible ? "block" : "none";

      // Add fade animation
      if (isVisible) {
        content.style.opacity = "0";
        content.style.transform = "translateY(10px)";
        setTimeout(() => {
          content.style.transition = "opacity 0.3s ease, transform 0.3s ease";
          content.style.opacity = "1";
          content.style.transform = "translateY(0)";
        }, 50);
      }
    });

    // Update step indicators
    this.updateStepIndicators();

    // Update progress bar
    this.updateProgressBar();

    // Update fields visibility based on loan type
    this.updateFieldsVisibility(this.loanTypeValue || "personal");

    // Update back button visibility
    this.updateBackButtonVisibility();
  }

  updateStepIndicators() {
    const steps = ["type", "basic", "terms", "review"];
    const currentIndex = steps.indexOf(this.currentStepValue || "type");

    this.stepIndicatorTargets.forEach((indicator, index) => {
      const circle = indicator.querySelector('[data-loan-wizard-target="stepCircle"]');
      const isActive = index === currentIndex;
      const isCompleted = index < currentIndex;

      // Update circle classes
      if (circle) {
        circle.className = this.getStepCircleClasses(isActive, isCompleted);
      }

      // Update indicator animation with enhanced feedback
      if (isActive) {
        indicator.style.transform = "scale(1.05)";
        indicator.style.transition = "transform 0.3s ease-in-out";

        // Add subtle glow effect for active step
        indicator.style.filter = "drop-shadow(0 0 8px rgba(16, 168, 97, 0.3))";
      } else {
        indicator.style.transform = "scale(1)";
        indicator.style.filter = "none";
      }
    });
  }

  getStepCircleClasses(isActive, isCompleted) {
    const base =
      "w-8 h-8 rounded-full flex items-center justify-center transition-all duration-300 transform";

    if (isCompleted) {
      return `${base} bg-success text-white shadow-md scale-110 ring-2 ring-success/20`;
    } else if (isActive) {
      return `${base} bg-success text-white shadow-lg scale-110 ring-4 ring-success/30 animate-pulse`;
    } else {
      return `${base} bg-container border-2 border-secondary text-secondary hover:border-success/40 hover:bg-container-hover hover:text-primary`;
    }
  }

  nextStep() {
    if (!this.validateCurrentStep()) {
      return;
    }

    const steps = ["type", "basic", "terms", "review"];
    const currentIndex = steps.indexOf(this.currentStepValue || "type");

    if (currentIndex < steps.length - 1) {
      const nextStepValue = steps[currentIndex + 1];

      // Add step completion animation
      this.animateStepCompletion(currentIndex);

      setTimeout(() => {
        this.currentStepValue = nextStepValue;
        this.updateStepVisibility();
        this.animateStepTransition("forward");
      }, 200);
    } else {
    }
  }

  previousStep() {
    const steps = ["type", "basic", "terms", "review"];
    const currentIndex = steps.indexOf(this.currentStepValue || "type");

    if (currentIndex > 0) {
      const previousStepValue = steps[currentIndex - 1];
      this.currentStepValue = previousStepValue;
      this.updateStepVisibility();
      this.animateStepTransition("backward");
    } else {
    }
  }

  animateStepTransition(direction) {
    const container = this.element.querySelector(".wizard-content");
    if (container) {
      container.style.transform =
        direction === "forward" ? "translateX(20px)" : "translateX(-20px)";
      container.style.opacity = "0.7";

      setTimeout(() => {
        container.style.transition = "transform 0.3s ease, opacity 0.3s ease";
        container.style.transform = "translateX(0)";
        container.style.opacity = "1";
      }, 100);
    }
  }

  animateStepCompletion(stepIndex) {
    const indicators = this.stepIndicatorTargets;
    if (indicators[stepIndex]) {
      const circle = indicators[stepIndex].querySelector('[data-loan-wizard-target="stepCircle"]');
      if (circle) {
        // Add completion animation
        circle.style.transform = "scale(1.2)";
        circle.style.transition = "transform 0.2s ease-out";

        setTimeout(() => {
          circle.style.transform = "scale(1.1)";
        }, 200);
      }
    }
  }

  updateProgressBar() {
    const steps = ["type", "basic", "terms", "review"];
    const currentIndex = steps.indexOf(this.currentStepValue || "type");
    const progressRatio = currentIndex === 0 ? 0 : currentIndex / 3;

    this.progressBarTargets.forEach((bar) => {
      bar.style.transform = `scaleX(${progressRatio})`;
      bar.style.transformOrigin = "left";

      // Add pulsing effect for active progress
      if (currentIndex > 0) {
        bar.style.animation = "progress-pulse 2s ease-in-out infinite";
      } else {
        bar.style.animation = "none";
      }
    });

    // Also update glow effects
    const glowElements = this.element.querySelectorAll(
      '.progress-bar-glow, [class*="bg-success/"]'
    );
    glowElements.forEach((glow) => {
      if (glow.style.transform !== undefined) {
        glow.style.transform = `scaleX(${progressRatio})`;
        glow.style.transformOrigin = "left";
        glow.style.opacity = progressRatio > 0 ? "1" : "0";
      }
    });
  }

  validateCurrentStep() {
    const currentStep = this.currentStepValue || "type";

    switch (currentStep) {
      case "type": {
        // Ensure a loan type has been selected
        const debtKindRadio = this.element.querySelector(
          'input[type="radio"][name="loan[debt_kind]"]:checked'
        );
        if (!debtKindRadio) {
          this.showError("Please select a loan type");
          return false;
        }

        // Validate account details (account name and current balance)
        // Account fields are outside the wizard component, so we need to look in the parent form
        const parentForm = this.element.closest("form");
        const accountName = parentForm?.querySelector('input[name="account[name]"]');
        const currentBalance = parentForm?.querySelector('input[name="account[balance]"]');

        if (!accountName?.value?.trim()) {
          this.showError("Please enter an account name");
          this.highlightField(accountName);
          return false;
        }

        if (!currentBalance?.value || parseFloat(currentBalance.value) === 0) {
          this.showError("Please enter the current balance");
          this.highlightField(currentBalance);
          return false;
        }

        return true;
      }
      case "basic": {
        // Try multiple selectors for counterparty name field
        let counterpartyName = this.element.querySelector('input[name="loan[counterparty_name]"]');
        if (!counterpartyName) {
          // Try alternative selectors
          counterpartyName = this.element.querySelector('input[id*="counterparty_name"]');
        }
        if (!counterpartyName) {
          // Try by placeholder text
          counterpartyName = this.element.querySelector('input[placeholder*="Ana, Bank Mandiri"]');
        }

        if (!counterpartyName) {
          this.showError("Lender name field not found");
          return false;
        }

        if (!counterpartyName.value?.trim()) {
          this.showError("Please enter the lender name");
          this.highlightField(counterpartyName);
          return false;
        }

        // Get loan type from radio button selection (more reliable)
        const selectedRadio = this.element.querySelector('input[name="loan[debt_kind]"]:checked');
        const selectedLoanType = selectedRadio ? selectedRadio.value : "personal";

        if (selectedLoanType === "personal") {
          // For personal loans, just lender name is enough
          return true;
        } else {
          // For institutional loans, check if institution name is filled
          const institutionName = this.element.querySelector(
            'input[name="loan[institution_name]"]'
          );
          if (!institutionName?.value.trim()) {
            this.showError("Please enter the institution name");
            return false;
          }
          return true;
        }
      }
      case "terms": {
        const principalAmount = this.element.querySelector('input[name="loan[principal_amount]"]');
        const termMonths = this.element.querySelector('input[name="loan[term_months]"]');

        if (!principalAmount?.value || parseFloat(principalAmount.value) <= 0) {
          this.showError("Please enter a valid loan amount");
          return false;
        }
        if (!termMonths?.value || parseInt(termMonths.value, 10) <= 0) {
          this.showError("Please enter the loan term");
          return false;
        }

        const interestFree = this.element.querySelector(
          'input[name="loan[interest_free]"]'
        )?.checked;
        const interestRate = this.element.querySelector('input[name="loan[interest_rate]"]');
        if (!interestFree && (!interestRate?.value || parseFloat(interestRate.value) < 0)) {
          this.showError("Please enter a valid interest rate");
          return false;
        }
        return true;
      }
      default:
        return true;
    }
  }

  showError(message) {
    // Remove existing error notifications
    const existingErrors = document.querySelectorAll(".loan-wizard-error");
    existingErrors.forEach((error) => {
      error.remove();
    });

    const notification = document.createElement("div");
    notification.className =
      "loan-wizard-error fixed top-4 right-4 bg-red-500 text-white px-4 py-3 rounded-lg shadow-lg z-50 border border-red-600 animate-pulse";
    notification.innerHTML = `
      <div class="flex items-center gap-2">
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd"></path>
        </svg>
        <span>${message}</span>
      </div>
    `;
    document.body.appendChild(notification);

    // Auto remove after 4 seconds with animation
    setTimeout(() => {
      notification.style.opacity = "0";
      notification.style.transform = "translateX(100%)";
      notification.style.transition = "all 0.3s ease-out";
      setTimeout(() => notification.remove(), 300);
    }, 4000);
  }

  applyQuickSetup(event) {
    event.preventDefault();

    // Set loan as personal type
    const personalRadio = this.element.querySelector(
      '[data-loan-type="personal"] input[type="radio"]'
    );
    if (personalRadio) {
      personalRadio.checked = true;
      personalRadio.dispatchEvent(new Event("change", { bubbles: true }));
      this.loanTypeValue = "personal";
      this.updateFieldsVisibility("personal");
    }

    // Show success message
    this.showSuccess("Quick setup applied! This loan is set as interest-free personal loan.");
  }

  showSuccess(message) {
    const notification = document.createElement("div");
    notification.className =
      "fixed top-4 right-4 bg-success text-white px-4 py-3 rounded-lg shadow-lg z-50 border border-green-600";
    notification.innerHTML = `
      <div class="flex items-center gap-2">
        <svg class="w-5 h-5" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"></path>
        </svg>
        <span>${message}</span>
      </div>
    `;
    document.body.appendChild(notification);
    setTimeout(() => notification.remove(), 3000);
  }

  highlightField(field) {
    if (!field) return;

    // Remove existing error styling
    field.classList.remove("border-red-500", "ring-2", "ring-red-500/20");

    // Add error styling
    field.classList.add("border-red-500", "ring-2", "ring-red-500/20");

    // Focus the field
    field.focus();

    // Remove error styling after 3 seconds
    setTimeout(() => {
      field.classList.remove("border-red-500", "ring-2", "ring-red-500/20");
    }, 3000);
  }

  updateBackButtonVisibility() {
    if (this.hasBackButtonTarget) {
      const steps = ["type", "basic", "terms", "review"];
      const currentIndex = steps.indexOf(this.currentStepValue || "type");

      if (currentIndex === 0) {
        // Hide back button on first step
        this.backButtonTarget.style.display = "none";
      } else {
        // Show back button on other steps
        this.backButtonTarget.style.display = "flex";
      }
    }
  }

  toggleInterestRate(event) {
    const isInterestFree = event.target.checked;
    const interestRateSection = this.element.querySelector(
      '[data-loan-wizard-target="interestRateSection"]'
    );

    if (interestRateSection) {
      if (isInterestFree) {
        interestRateSection.style.display = "none";
        // Set interest rate to 0
        const interestRateInput = interestRateSection.querySelector(
          'input[name="loan[interest_rate]"]'
        );
        if (interestRateInput) {
          interestRateInput.value = "0";
        }
      } else {
        interestRateSection.style.display = "block";
      }
    }
  }

  goToStep1(event) {
    event.preventDefault();
    this.currentStepValue = "type";
    this.updateStepVisibility();
    this.animateStepTransition("backward");
  }

  updateWizardDisplay() {
    this.element.dispatchEvent(
      new CustomEvent("wizard:step-changed", {
        detail: { step: this.currentStepValue },
      })
    );
  }

  setQuickAmount(event) {
    const amount = event.currentTarget.dataset.amount;
    if (this.hasPrincipalAmountTarget) {
      this.principalAmountTarget.value = amount;
      this.calculatePayment();
    }
  }

  setTermMonths(event) {
    const months = event.currentTarget.dataset.months;
    if (this.hasTermMonthsTarget) {
      this.termMonthsTarget.value = months;
      this.calculatePayment();
    }
  }

  calculatePayment() {
    // Check if required targets exist before calculating
    if (!this.hasPrincipalAmountTarget || !this.hasTermMonthsTarget) return;

    const principal = parseFloat(this.principalAmountTarget?.value || 0);
    const rate = parseFloat(this.interestRateTarget?.value || 0);
    const months = parseInt(this.termMonthsTarget?.value || 0, 10);

    if (principal <= 0 || months <= 0) {
      this.updatePaymentDisplay(0, 0, 0);
      return;
    }

    if (rate === 0) {
      const monthlyPayment = principal / months;
      this.updatePaymentDisplay(monthlyPayment, 0, principal);
    } else {
      const monthlyRate = rate / 100 / 12;
      const monthlyPayment =
        (principal * (monthlyRate * (1 + monthlyRate) ** months)) /
        ((1 + monthlyRate) ** months - 1);
      const totalAmount = monthlyPayment * months;
      const totalInterest = totalAmount - principal;
      this.updatePaymentDisplay(monthlyPayment, totalInterest, totalAmount);
    }
  }

  updatePaymentDisplay(monthly, interest, total) {
    const formatter = new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: "USD",
    });
    if (this.hasMonthlyPaymentTarget)
      this.monthlyPaymentTarget.textContent = formatter.format(monthly);
    if (this.hasTotalInterestTarget)
      this.totalInterestTarget.textContent = formatter.format(interest);
    if (this.hasTotalAmountTarget) this.totalAmountTarget.textContent = formatter.format(total);
  }

  toggleInterestFree(event) {
    const isInterestFree = event.target.checked;
    if (this.hasInterestRateTarget) {
      this.interestRateTarget.disabled = isInterestFree;
      if (isInterestFree) this.interestRateTarget.value = 0;
    }
    this.calculatePayment();
  }
}
