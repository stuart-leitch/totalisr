import { Controller } from "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js"

export default class extends Controller {
  static targets = ["item", "total"]
  static values = { total: Number }

  connect() {
    this.itemTargets.forEach((item, index) => {
      this.totalValue += Number(item.textContent)
    })
    this.totalTarget.textContent = `${this.totalValue}`
  }

}