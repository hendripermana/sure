import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["count", "countContainer", "unit", "start", "next", "status", "trial"];
  static values = { serviceDefaults: Object };

  connect() {
    this.onServiceSelection = this.serviceSelected.bind(this);
    this.element.addEventListener("hw-combobox:selection", this.onServiceSelection);
    this.syncIntervalControls();
  }

  disconnect() {
    this.element.removeEventListener("hw-combobox:selection", this.onServiceSelection);
  }

  scheduleChanged() {
    this.syncIntervalControls();
    this.updateNextBillingDate();
  }

  serviceSelected(event) {
    const schedule = this.serviceDefaultsValue[event.detail.value];
    if (!schedule) return;

    this.countTarget.value = schedule.count;
    this.unitTarget.value = schedule.unit;
    this.scheduleChanged();
  }

  trialChanged() {
    if (this.trialTarget.value && this.statusTarget.value === "active") {
      this.statusTarget.value = "trial";
    }
  }

  syncIntervalControls() {
    const oneTime = this.unitTarget.value === "once";
    this.countContainerTarget.classList.toggle("hidden", oneTime);
    this.countTarget.disabled = oneTime;
    this.countTarget.required = !oneTime;
    if (oneTime) this.countTarget.value = 1;
  }

  updateNextBillingDate() {
    if (!this.startTarget.value || !this.unitTarget.value) return;

    const count = Number.parseInt(this.countTarget.value || "1", 10);
    if (!Number.isFinite(count) || count < 1) return;

    this.nextTarget.value = this.advance(this.startTarget.value, count, this.unitTarget.value);
  }

  advance(dateString, count, unit) {
    if (unit === "once") return dateString;

    const [year, month, day] = dateString.split("-").map(Number);
    const date = new Date(Date.UTC(year, month - 1, day));

    if (unit === "day") date.setUTCDate(date.getUTCDate() + count);
    if (unit === "week") date.setUTCDate(date.getUTCDate() + count * 7);
    if (unit === "month") return this.advanceCalendarDate(year, month - 1 + count, day);
    if (unit === "year") return this.advanceCalendarDate(year + count, month - 1, day);

    return date.toISOString().slice(0, 10);
  }

  advanceCalendarDate(year, monthIndex, day) {
    const targetYear = year + Math.floor(monthIndex / 12);
    const targetMonth = ((monthIndex % 12) + 12) % 12;
    const lastDay = new Date(Date.UTC(targetYear, targetMonth + 1, 0)).getUTCDate();
    const date = new Date(Date.UTC(targetYear, targetMonth, Math.min(day, lastDay)));

    return date.toISOString().slice(0, 10);
  }
}
