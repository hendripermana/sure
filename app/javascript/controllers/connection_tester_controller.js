import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["status", "button"]
  static values = {
    providerKey: String
  }

  async test() {
    this.statusTarget.innerHTML = `
      <div class="flex items-center gap-2 text-secondary text-sm">
        <svg class="animate-spin h-4 w-4 text-primary" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>
        <span>Testing connection...</span>
      </div>
    `
    this.buttonTarget.disabled = true

    try {
      const response = await fetch("/settings/providers/test_connection", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').getAttribute("content")
        },
        body: JSON.stringify({ provider_key: this.providerKeyValue })
      })

      const data = await response.json()

      if (data.success) {
        this.statusTarget.innerHTML = `
          <div class="flex items-start gap-2 p-3 rounded-lg bg-green-500/10 border border-green-500/20 text-green-700 dark:text-green-400 text-sm">
            <svg class="w-4 h-4 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
            <div>
              <p class="font-medium">Connection Valid</p>
              <p class="text-xs opacity-90 mt-0.5">${data.message}</p>
            </div>
          </div>
        `
      } else {
        this.statusTarget.innerHTML = `
          <div class="flex items-start gap-2 p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-700 dark:text-red-400 text-sm">
            <svg class="w-4 h-4 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
            <div>
              <p class="font-medium">Connection Failed</p>
              <p class="text-xs opacity-90 mt-0.5">${data.message}</p>
            </div>
          </div>
        `
      }
    } catch (error) {
      this.statusTarget.innerHTML = `
        <div class="flex items-start gap-2 p-3 rounded-lg bg-red-500/10 border border-red-500/20 text-red-700 dark:text-red-400 text-sm">
          <svg class="w-4 h-4 mt-0.5 flex-shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" /></svg>
          <div>
            <p class="font-medium">Error</p>
            <p class="text-xs opacity-90 mt-0.5">Failed to contact the test endpoint.</p>
          </div>
        </div>
      `
    } finally {
      this.buttonTarget.disabled = false
    }
  }
}
