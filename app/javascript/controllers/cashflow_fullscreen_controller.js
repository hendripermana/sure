import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="cashflow-fullscreen"
export default class extends Controller {
  static values = {
    sankeyData: Object,
    currencySymbol: String,
    period: String,
  };

  static targets = ["fullscreenModal"];

  connect() {
    // Bind escape key handler
    this.escapeHandler = this.handleEscape.bind(this);
    this.currentRequest = null;
    this.watchdogTimer = null;
    this.isUnmounted = false;

    // Ensure we have required data
    if (!this.sankeyDataValue?.nodes || !this.sankeyDataValue.links) {
      console.warn("Cashflow fullscreen: Missing required sankey data");
      this.element.style.display = "none";
    }
  }

  disconnect() {
    this.isUnmounted = true;
    this.cleanup();
  }

  toggleFullscreen() {
    if (this.isFullscreenOpen()) {
      this.exitFullscreen();
    } else {
      this.enterFullscreen();
    }
  }

  enterFullscreen() {
    // Create comprehensive fullscreen modal with theme consistency
    this.createFullscreenModal();

    // Add to DOM and show
    document.body.appendChild(this.fullscreenModal);
    document.body.style.overflow = "hidden"; // Prevent background scrolling

    // Add event listeners
    document.addEventListener("keydown", this.escapeHandler);

    // Animate entrance
    requestAnimationFrame(() => {
      this.fullscreenModal.classList.add("opacity-100");
      this.fullscreenModal.classList.remove("opacity-0");

      // Initialize the sankey chart after modal is visible
      setTimeout(() => {
        this.initializeFullscreenChart();
        // Force additional resize after initialization to ensure proper layout
        setTimeout(() => {
          this.forceFullscreenResize();
        }, 200);
      }, 100);
    });
  }

  exitFullscreen() {
    if (!this.fullscreenModal) return;

    // Animate exit
    this.fullscreenModal.classList.add("opacity-0");
    this.fullscreenModal.classList.remove("opacity-100");

    // Remove after animation
    setTimeout(() => {
      this.cleanup();
    }, 300);
  }

  createFullscreenModal() {
    // Create modal with proper theme inheritance - comprehensive theme detection
    this.fullscreenModal = document.createElement("div");

    // Detect current theme from multiple sources for comprehensive coverage
    const isDarkMode = this.detectDarkTheme();

    // Apply base classes with proper theme awareness
    const baseClasses = [
      "fixed",
      "inset-0",
      "z-50",
      "flex",
      "flex-col",
      "opacity-0",
      "transition-opacity",
      "duration-300",
      "ease-in-out",
    ];

    // Add theme-specific background classes
    if (isDarkMode) {
      baseClasses.push("bg-gray-900", "text-white", "dark");
    } else {
      baseClasses.push("bg-white", "text-gray-900");
    }

    this.fullscreenModal.className = baseClasses.join(" ");

    // Force theme inheritance to all child elements
    if (isDarkMode) {
      this.fullscreenModal.setAttribute("data-theme", "dark");
    } else {
      this.fullscreenModal.setAttribute("data-theme", "light");
    }

    this.fullscreenModal.innerHTML = `
      <div class="bg-container border-b border-secondary">
        <div class="flex items-center justify-between px-6 py-4">
          <!-- Header Section with consistent styling -->
          <div class="flex items-center gap-6">
            <h1 class="text-2xl font-semibold text-primary">Cashflow Analysis</h1>
            
            <!-- Period Filter with same styling as original -->
            <div class="flex items-center gap-3">
              <label class="text-sm font-medium text-secondary">Period:</label>
              <select 
                id="fullscreen-period-selector"
                class="bg-container border border-secondary font-medium rounded-lg px-3 py-2 text-sm pr-7 cursor-pointer text-primary focus:outline-hidden focus:ring-2 focus:ring-blue-500 focus:border-transparent">
                ${this.getPeriodOptions()}
              </select>
            </div>
          </div>
          
          <!-- Action Buttons -->
          <div class="flex items-center gap-3">
            <!-- Export Button -->
            <button
              id="fullscreen-export-btn"
              class="flex items-center gap-2 px-4 py-2 text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 border border-blue-600 rounded-lg transition-colors duration-200"
              title="Export Cashflow Chart">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
              </svg>
              Export
            </button>
            
            <!-- Close Button -->
            <button
              id="fullscreen-close-btn"
              class="flex items-center justify-center w-10 h-10 rounded-lg border border-secondary bg-container hover:bg-red-50 dark:hover:bg-red-900 text-gray-600 dark:text-gray-300 hover:text-red-600 dark:hover:text-red-400 transition-colors duration-200 group"
              title="Exit Fullscreen">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"/>
              </svg>
            </button>
          </div>
        </div>
      </div>
      
      <!-- Main Chart Container with proper spacing to prevent cutoffs -->
      <div class="flex-1 bg-gray-50 dark:bg-gray-800 min-h-0 p-6">
        <div class="h-full bg-container rounded-xl shadow-sm border border-secondary overflow-hidden">
          <div 
            id="fullscreen-sankey-container"
            class="w-full h-full p-4"
            data-controller="sankey-autosizer"
            data-sankey-autosizer-min-width-value="600"
            data-sankey-autosizer-min-height-value="400"
            data-sankey-autosizer-debounce-ms-value="100"
            style="min-height: 400px;">
            <div
              data-controller="sankey-chart"
              data-sankey-autosizer-target="chart"
              data-sankey-chart-data-value='${JSON.stringify(this.sankeyDataValue)}'
              data-sankey-chart-currency-symbol-value="${this.currencySymbolValue}"
              class="w-full h-full">
            </div>
          </div>
        </div>
      </div>
      
      <!-- Footer with Stats (Optional Enhancement) -->
      <div class="bg-container border-t border-secondary px-6 py-3">
        <div class="flex items-center justify-between text-sm text-secondary">
          <div class="flex items-center gap-6">
            <span>Total Income: <strong class="text-primary">${this.formatCurrency(this.getTotalIncome())}</strong></span>
            <span>Total Expenses: <strong class="text-primary">${this.formatCurrency(this.getTotalExpenses())}</strong></span>
            <span>Net Flow: <strong class="text-primary ${this.getNetFlow() >= 0 ? "text-green-600" : "text-red-600"}">${this.formatCurrency(this.getNetFlow())}</strong></span>
          </div>
          <div class="text-xs text-secondary">
            Last updated: ${new Date().toLocaleDateString()}
          </div>
        </div>
      </div>
    `;

    // Add event listeners to modal elements
    this.addModalEventListeners();
  }

  initializeFullscreenChart() {
    // Force re-initialization of Stimulus controllers for the fullscreen chart
    const autosizerContainer = this.fullscreenModal.querySelector("#fullscreen-sankey-container");
    const chartContainer = this.fullscreenModal.querySelector('[data-controller="sankey-chart"]');

    if (autosizerContainer && chartContainer && window.Stimulus) {
      // Trigger Stimulus controller connection for both autosizer and chart
      window.Stimulus.connect(autosizerContainer);
      window.Stimulus.connect(chartContainer);

      // Force resize after a brief delay to ensure proper initialization
      setTimeout(() => {
        this.forceFullscreenResize();
      }, 100);
    }
  }

  forceFullscreenResize() {
    // Force the autosizer to recalculate dimensions in fullscreen
    const autosizerContainer = this.fullscreenModal?.querySelector("#fullscreen-sankey-container");
    if (autosizerContainer) {
      const autosizerController = this.application?.getControllerForElementAndIdentifier(
        autosizerContainer,
        "sankey-autosizer"
      );

      if (autosizerController && typeof autosizerController.forceResize === "function") {
        autosizerController.forceResize();
      }

      // Also dispatch a resize event to trigger any listeners
      window.dispatchEvent(new Event("resize"));
    }
  }

  addModalEventListeners() {
    // Close button
    const closeBtn = this.fullscreenModal.querySelector("#fullscreen-close-btn");
    if (closeBtn) {
      closeBtn.addEventListener("click", () => this.exitFullscreen());
    }

    // Period selector
    const periodSelector = this.fullscreenModal.querySelector("#fullscreen-period-selector");
    if (periodSelector) {
      periodSelector.value = this.periodValue;
      periodSelector.addEventListener("change", (event) => {
        this.handlePeriodChange(event.target.value);
      });
    }

    // Export button functionality
    const exportBtn = this.fullscreenModal.querySelector("#fullscreen-export-btn");
    if (exportBtn) {
      exportBtn.addEventListener("click", () => {
        this.handleExport();
      });
    }

    // Click outside to close (optional)
    this.fullscreenModal.addEventListener("click", (event) => {
      if (event.target === this.fullscreenModal) {
        this.exitFullscreen();
      }
    });
  }

  handleEscape(event) {
    if (event.key === "Escape" && this.isFullscreenOpen()) {
      event.preventDefault();
      this.exitFullscreen();
    }
  }

  async handlePeriodChange(newPeriod) {
    // Store fullscreen state before making request
    const wasFullscreen = this.isFullscreenOpen();

    // Show loading indicator with stale-while-revalidate UX
    if (wasFullscreen) {
      this.showLoadingIndicatorWithStaleData();
    }

    // Use AbortController for request cancellation
    if (this.currentRequest) {
      this.currentRequest.abort();
    }
    this.currentRequest = new AbortController();

    // Start watchdog timer
    this.startWatchdogTimer();

    try {
      // Make AJAX request to get new data without full page reload
      const url = new URL(window.location);
      url.searchParams.set("cashflow_period", newPeriod);

      const response = await fetch(url.toString(), {
        method: "GET",
        headers: {
          Accept: "text/html",
          "X-Requested-With": "XMLHttpRequest",
          "Turbo-Frame": "cashflow-frame",
        },
        signal: this.currentRequest.signal,
      });

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }

      const html = await response.text();
      const parser = new DOMParser();
      const doc = parser.parseFromString(html, "text/html");

      // Extract the new sankey data from the response
      const newSankeyElement = doc.querySelector('[data-controller*="cashflow-fullscreen"]');
      if (newSankeyElement) {
        const newSankeyData = JSON.parse(
          newSankeyElement.getAttribute("data-cashflow-fullscreen-sankey-data-value")
        );
        const newCurrencySymbol = newSankeyElement.getAttribute(
          "data-cashflow-fullscreen-currency-symbol-value"
        );
        const newPeriod = newSankeyElement.getAttribute("data-cashflow-fullscreen-period-value");

        // Update current instance values
        this.sankeyDataValue = newSankeyData;
        this.currencySymbolValue = newCurrencySymbol;
        this.periodValue = newPeriod;

        // Update the original element's data attributes
        this.element.setAttribute(
          "data-cashflow-fullscreen-sankey-data-value",
          JSON.stringify(newSankeyData)
        );
        this.element.setAttribute(
          "data-cashflow-fullscreen-currency-symbol-value",
          newCurrencySymbol
        );
        this.element.setAttribute("data-cashflow-fullscreen-period-value", newPeriod);

        // If fullscreen is open, update the chart and stats
        if (wasFullscreen) {
          this.updateFullscreenContent();
        }

        // Update the main page sankey chart as well
        this.updateMainPageChart(html);

        // Update browser URL without reload
        window.history.pushState({}, "", url.toString());
      }
    } catch (error) {
      // Don't treat aborted requests as errors
      if (error.name === "AbortError") {
        return;
      }

      console.error("Failed to update cashflow data:", error);

      if (wasFullscreen) {
        this.showErrorState(error.message);
      }

      // Fallback to full page reload if AJAX fails (only for non-abort errors)
      if (window.Turbo) {
        window.Turbo.visit(url.toString());
      } else {
        window.location.href = url.toString();
      }
    } finally {
      // Clear watchdog timer
      this.clearWatchdogTimer();

      // Hide loading indicator
      if (wasFullscreen) {
        this.hideLoadingIndicator();
      }

      // Clear current request
      this.currentRequest = null;
    }
  }

  // Helper Methods
  getPeriodOptions() {
    const periods = [
      { key: "last_day", label: "Last Day" },
      { key: "current_week", label: "Current Week" },
      { key: "last_7_days", label: "Last 7 Days" },
      { key: "current_month", label: "Current Month" },
      { key: "last_30_days", label: "Last 30 Days" },
      { key: "last_90_days", label: "Last 90 Days" },
      { key: "current_year", label: "Current Year" },
      { key: "last_365_days", label: "Last 365 Days" },
      { key: "last_5_years", label: "Last 5 Years" },
    ];

    return periods
      .map(
        (period) =>
          `<option value="${period.key}" ${period.key === this.periodValue ? "selected" : ""}>${period.label}</option>`
      )
      .join("");
  }

  getTotalIncome() {
    if (!this.sankeyDataValue?.links) return 0;

    // Calculate total income from links that flow INTO the Cash Flow node
    const cashFlowNodeIndex = this.sankeyDataValue.nodes.findIndex(
      (node) => node.name === "Cash Flow"
    );
    if (cashFlowNodeIndex === -1) return 0;

    return this.sankeyDataValue.links
      .filter((link) => link.target === cashFlowNodeIndex)
      .reduce((sum, link) => sum + (Number.parseFloat(link.value) || 0), 0);
  }

  getTotalExpenses() {
    if (!this.sankeyDataValue?.links) return 0;

    // Calculate total expenses from links that flow OUT of the Cash Flow node (excluding Surplus)
    const cashFlowNodeIndex = this.sankeyDataValue.nodes.findIndex(
      (node) => node.name === "Cash Flow"
    );
    if (cashFlowNodeIndex === -1) return 0;

    return this.sankeyDataValue.links
      .filter((link) => link.source === cashFlowNodeIndex)
      .filter((link) => {
        const targetNode = this.sankeyDataValue.nodes[link.target];
        return targetNode && targetNode.name !== "Surplus";
      })
      .reduce((sum, link) => sum + (Number.parseFloat(link.value) || 0), 0);
  }

  getNetFlow() {
    return this.getTotalIncome() - this.getTotalExpenses();
  }

  formatCurrency(amount) {
    return (
      this.currencySymbolValue +
      Math.abs(amount).toLocaleString(undefined, {
        minimumFractionDigits: 0,
        maximumFractionDigits: 0,
      })
    );
  }

  isFullscreenOpen() {
    return this.fullscreenModal && document.body.contains(this.fullscreenModal);
  }

  // New comprehensive methods for enhanced functionality

  showLoadingIndicator() {
    const chartContainer = this.fullscreenModal?.querySelector("#fullscreen-sankey-container");
    if (chartContainer) {
      chartContainer.innerHTML = `
        <div class="flex items-center justify-center h-full">
          <div class="flex flex-col items-center gap-4">
            <div class="animate-spin rounded-full h-12 w-12 border-4 border-blue-500 border-t-transparent"></div>
            <p class="text-secondary">Updating cashflow data...</p>
          </div>
        </div>
      `;
    }
  }

  hideLoadingIndicator() {
    // The loading indicator will be replaced when chart is redrawn
  }

  updateFullscreenContent() {
    // Update the chart
    this.initializeFullscreenChart();

    // Update the period selector
    const periodSelector = this.fullscreenModal?.querySelector("#fullscreen-period-selector");
    if (periodSelector) {
      periodSelector.value = this.periodValue;
    }

    // Update footer statistics
    this.updateFooterStats();
  }

  updateFooterStats() {
    const footerStats = this.fullscreenModal?.querySelector(
      ".flex.items-center.justify-between.text-sm.text-secondary"
    );
    if (footerStats?.children[0]) {
      footerStats.children[0].innerHTML = `
        <span>Total Income: <strong class="text-primary">${this.formatCurrency(this.getTotalIncome())}</strong></span>
        <span>Total Expenses: <strong class="text-primary">${this.formatCurrency(this.getTotalExpenses())}</strong></span>
        <span>Net Flow: <strong class="text-primary ${this.getNetFlow() >= 0 ? "text-green-600" : "text-red-600"}">${this.formatCurrency(this.getNetFlow())}</strong></span>
      `;
    }
  }

  updateMainPageChart(responseHtml) {
    // Update the main page sankey chart container
    const parser = new DOMParser();
    const doc = parser.parseFromString(responseHtml, "text/html");
    const newSankeySection = doc.querySelector(
      '[data-controller*="sankey-chart"]:not([id="fullscreen-sankey-container"])'
    );
    const currentSankeySection = document.querySelector(
      '[data-controller*="sankey-chart"]:not([id="fullscreen-sankey-container"])'
    );

    if (newSankeySection && currentSankeySection) {
      // Update data attributes
      const newDataValue = newSankeySection.getAttribute("data-sankey-chart-data-value");
      const newCurrencyValue = newSankeySection.getAttribute(
        "data-sankey-chart-currency-symbol-value"
      );

      currentSankeySection.setAttribute("data-sankey-chart-data-value", newDataValue);
      currentSankeySection.setAttribute(
        "data-sankey-chart-currency-symbol-value",
        newCurrencyValue
      );

      // Trigger chart redraw
      if (window.Stimulus) {
        const controller = window.Stimulus.controllers.find(
          (c) => c.element === currentSankeySection && c.identifier === "sankey-chart"
        );
        if (controller && typeof controller.dataValueChanged === "function") {
          controller.dataValueChanged();
        } else if (controller && typeof controller.connect === "function") {
          controller.disconnect();
          controller.connect();
        }
      }
    }
  }

  async handleExport() {
    try {
      const chartContainer = this.fullscreenModal?.querySelector(
        "#fullscreen-sankey-container svg"
      );
      if (!chartContainer) {
        throw new Error("Chart not found");
      }

      // Show loading state
      const exportBtn = this.fullscreenModal?.querySelector("#fullscreen-export-btn");
      const _originalContent = exportBtn?.innerHTML;
      if (exportBtn) {
        exportBtn.disabled = true;
        exportBtn.innerHTML = `
          <div class="animate-spin rounded-full h-4 w-4 border-2 border-white border-t-transparent"></div>
          Exporting...
        `;
      }

      // Get SVG element and prepare for export
      const svgElement = chartContainer.cloneNode(true);
      const svgRect = chartContainer.getBoundingClientRect();

      // Set proper dimensions
      svgElement.setAttribute("width", svgRect.width);
      svgElement.setAttribute("height", svgRect.height);
      svgElement.setAttribute("viewBox", `0 0 ${svgRect.width} ${svgRect.height}`);

      // Add background
      const backgroundRect = document.createElementNS("http://www.w3.org/2000/svg", "rect");
      backgroundRect.setAttribute("width", "100%");
      backgroundRect.setAttribute("height", "100%");
      backgroundRect.setAttribute(
        "fill",
        getComputedStyle(document.documentElement).getPropertyValue("--color-background") ||
          "#ffffff"
      );
      svgElement.insertBefore(backgroundRect, svgElement.firstChild);

      // Convert to data URL
      const svgData = new XMLSerializer().serializeToString(svgElement);
      const svgBlob = new Blob([svgData], {
        type: "image/svg+xml;charset=utf-8",
      });

      // Create download
      const url = URL.createObjectURL(svgBlob);
      const link = document.createElement("a");
      link.href = url;
      link.download = `cashflow-analysis-${this.periodValue}-${new Date().toISOString().split("T")[0]}.svg`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
      URL.revokeObjectURL(url);

      // Also offer PNG export
      setTimeout(() => this.exportAsPNG(svgElement, svgRect), 500);
    } catch (error) {
      console.error("Export failed:", error);
      alert("Export failed. Please try again.");
    } finally {
      // Restore button
      const exportBtn = this.fullscreenModal?.querySelector("#fullscreen-export-btn");
      const _originalContent = exportBtn?.innerHTML;
      if (exportBtn) {
        exportBtn.disabled = false;
        exportBtn.innerHTML = `
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"/>
          </svg>
          Export
        `;
      }
    }
  }

  async exportAsPNG(svgElement, svgRect) {
    try {
      // Create canvas for PNG conversion
      const canvas = document.createElement("canvas");
      const ctx = canvas.getContext("2d");
      const scale = 2; // High DPI

      canvas.width = svgRect.width * scale;
      canvas.height = svgRect.height * scale;
      ctx.scale(scale, scale);

      // Convert SVG to image
      const svgData = new XMLSerializer().serializeToString(svgElement);
      const img = new Image();

      img.onload = () => {
        ctx.fillStyle =
          getComputedStyle(document.documentElement).getPropertyValue("--color-background") ||
          "#ffffff";
        ctx.fillRect(0, 0, svgRect.width, svgRect.height);
        ctx.drawImage(img, 0, 0);

        canvas.toBlob((blob) => {
          const url = URL.createObjectURL(blob);
          const link = document.createElement("a");
          link.href = url;
          link.download = `cashflow-analysis-${this.periodValue}-${new Date().toISOString().split("T")[0]}.png`;
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link);
          URL.revokeObjectURL(url);
        }, "image/png");
      };

      const svgUrl = `data:image/svg+xml;base64,${btoa(unescape(encodeURIComponent(svgData)))}`;
      img.src = svgUrl;
    } catch (error) {
      console.error("PNG export failed:", error);
    }
  }

  cleanup() {
    // Clear timers and requests
    this.clearWatchdogTimer();
    if (this.currentRequest) {
      this.currentRequest.abort();
      this.currentRequest = null;
    }

    // Remove event listeners
    document.removeEventListener("keydown", this.escapeHandler);

    // Restore body scroll
    document.body.style.overflow = "";

    // Remove modal from DOM
    if (this.fullscreenModal && document.body.contains(this.fullscreenModal)) {
      document.body.removeChild(this.fullscreenModal);
    }

    this.fullscreenModal = null;
  }

  // Comprehensive theme detection method
  detectDarkTheme() {
    // Check multiple sources for dark theme detection
    const htmlElement = document.documentElement;
    const bodyElement = document.body;

    // Method 1: Check for 'dark' class on html or body
    if (htmlElement.classList.contains("dark") || bodyElement.classList.contains("dark")) {
      return true;
    }

    // Method 2: Check data attributes
    if (
      htmlElement.getAttribute("data-theme") === "dark" ||
      bodyElement.getAttribute("data-theme") === "dark"
    ) {
      return true;
    }

    // Method 3: Check CSS custom properties
    const computedStyle = getComputedStyle(htmlElement);
    const colorScheme = computedStyle.getPropertyValue("color-scheme");
    if (colorScheme?.includes("dark")) {
      return true;
    }

    // Method 4: Check media query preference as fallback
    if (window.matchMedia?.("(prefers-color-scheme: dark)").matches) {
      // Only use this if no explicit theme is set
      const hasLightClass =
        htmlElement.classList.contains("light") || bodyElement.classList.contains("light");
      if (!hasLightClass) {
        return true;
      }
    }

    // Method 5: Check for dark background color as indicator
    const backgroundColor = computedStyle.getPropertyValue("background-color");
    if (backgroundColor) {
      // Convert to RGB and check if it's dark
      const rgb = backgroundColor.match(/\d+/g);
      if (rgb && rgb.length >= 3) {
        const r = Number.parseInt(rgb[0], 10);
        const g = Number.parseInt(rgb[1], 10);
        const b = Number.parseInt(rgb[2], 10);
        const brightness = (r * 299 + g * 587 + b * 114) / 1000;
        if (brightness < 128) {
          return true;
        }
      }
    }

    return false;
  }

  // Loading indicator for period changes
  showLoadingIndicatorWithStaleData() {
    if (!this.fullscreenModal) return;

    const chartContainer = this.fullscreenModal.querySelector("#fullscreen-sankey-container");
    const periodSelector = this.fullscreenModal.querySelector("#fullscreen-period-selector");

    if (chartContainer) {
      const isDark = this.detectDarkTheme();
      chartContainer.innerHTML = `
        <div class="flex items-center justify-center h-full ${isDark ? "text-gray-300" : "text-gray-600"}">
          <div class="flex flex-col items-center gap-3">
            <div class="animate-spin rounded-full h-8 w-8 border-b-2 ${isDark ? "border-gray-300" : "border-gray-600"}"></div>
            <span class="text-sm font-medium">Updating cashflow data...</span>
          </div>
        </div>
      `;
    }

    if (periodSelector) {
      periodSelector.disabled = true;
    }
  }

  showErrorState(errorMessage) {
    if (!this.fullscreenModal) return;

    const chartContainer = this.fullscreenModal.querySelector("#fullscreen-sankey-container");
    if (chartContainer) {
      const isDark = this.detectDarkTheme();
      chartContainer.innerHTML = `
        <div class="flex items-center justify-center h-full ${isDark ? "text-red-300" : "text-red-600"}">
          <div class="flex flex-col items-center gap-3">
            <svg class="w-12 h-12" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-2.5L13.732 4c-.77-.833-1.964-.833-2.732 0L3.732 16.5c-.77.833.192 2.5 1.732 2.5z"/>
            </svg>
            <span class="text-sm font-medium">Error loading data: ${errorMessage}</span>
            <button class="px-4 py-2 text-sm bg-blue-600 text-white rounded-lg hover:bg-blue-700" onclick="location.reload()">Retry</button>
          </div>
        </div>
      `;
    }
  }

  startWatchdogTimer() {
    this.clearWatchdogTimer();
    this.watchdogTimer = setTimeout(() => {
      if (this.currentRequest) {
        this.currentRequest.abort();
        this.showErrorState("Request timeout");
      }
    }, 30000); // 30 second timeout
  }

  clearWatchdogTimer() {
    if (this.watchdogTimer) {
      clearTimeout(this.watchdogTimer);
      this.watchdogTimer = null;
    }
  }
}
