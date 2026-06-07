import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["icon"];
  static values = { userPreference: String };

  connect() {
    this.applyPreference(this.preferredTheme);
  }

  toggle() {
    const newTheme = this.currentTheme === "dark" ? "light" : "dark";
    this.applyPreference(newTheme);
  }

  updateTheme(event) {
    const preference = typeof event === "string" ? event : event.currentTarget?.value;
    if (!preference) return;

    this.applyPreference(preference);
  }

  applyPreference(preference) {
    const resolvedTheme = this.resolveTheme(preference);
    document.documentElement.setAttribute("data-theme", resolvedTheme);
    localStorage.setItem("themePreference", preference);
    localStorage.setItem("theme", resolvedTheme);

    window.dispatchEvent(
      new CustomEvent("theme:change", {
        detail: { theme: resolvedTheme, preference },
      })
    );
  }

  get currentTheme() {
    return document.documentElement.getAttribute("data-theme") || this.resolveTheme("system");
  }

  get preferredTheme() {
    if (this.hasUserPreferenceValue && this.userPreferenceValue) {
      return this.userPreferenceValue;
    }

    return localStorage.getItem("themePreference") || "system";
  }

  resolveTheme(preference) {
    if (preference === "dark" || preference === "light") return preference;

    return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
  }
}
