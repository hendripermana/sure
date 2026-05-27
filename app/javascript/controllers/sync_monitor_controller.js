import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["tab", "tbody"];
  static values = {
    active: Boolean,
  };

  connect() {
    this.startPollingIfActive();
  }

  disconnect() {
    this.stopPolling();
  }

  activeValueChanged() {
    this.startPollingIfActive();
  }

  startPollingIfActive() {
    this.stopPolling();
    if (this.activeValue) {
      this.pollingTimer = setInterval(() => {
        const frame = document.getElementById("sync_monitor_frame");
        if (frame) {
          if (typeof frame.reload === "function") {
            frame.reload();
          } else {
            const currentSrc = frame.src;
            frame.src = currentSrc;
          }
        }
      }, 30000); // Poll every 30 seconds
    }
  }

  stopPolling() {
    if (this.pollingTimer) {
      clearInterval(this.pollingTimer);
      this.pollingTimer = null;
    }
  }

  filter(event) {
    const filter = event.currentTarget.dataset.filter;
    const activeClasses = ["bg-container", "text-primary", "shadow-xs"];
    const inactiveClasses = ["text-secondary", "hover:text-primary"];

    // Update active state of tabs
    this.tabTargets.forEach((tab) => {
      const isSelected = tab.dataset.filter === filter;
      if (isSelected) {
        tab.classList.add(...activeClasses);
        tab.classList.remove(...inactiveClasses);
      } else {
        tab.classList.remove(...activeClasses);
        tab.classList.add(...inactiveClasses);
      }
    });

    // Filter table rows
    if (this.hasTbodyTarget) {
      const rows = this.tbodyTarget.querySelectorAll("tr");
      rows.forEach((row) => {
        const status = row.dataset.status;
        if (filter === "all" || status === filter) {
          row.classList.remove("hidden");
        } else {
          row.classList.add("hidden");
        }
      });
    }
  }
}
