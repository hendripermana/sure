import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["input"];
  static values = { timezone: String };

  connect() {
    this.refresh();
  }

  refresh() {
    const today = this.todayInTimezone();
    this.inputTargets.forEach((input) => {
      input.max = today;
    });
  }

  todayInTimezone() {
    const formatter = new Intl.DateTimeFormat("en-CA", {
      timeZone: this.timezoneValue || "UTC",
      year: "numeric",
      month: "2-digit",
      day: "2-digit",
    });
    const parts = Object.fromEntries(
      formatter.formatToParts(new Date()).map(({ type, value }) => [type, value])
    );

    return `${parts.year}-${parts.month}-${parts.day}`;
  }
}
