import { Controller } from "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js"

export default class extends Controller {
  static targets = ["item", "total"]
  static values = { total: Number }

  connect() {
    this.addItemI("Budget", 1000)
    this.addItemI("Flights", -250)
    this.addItemI("Accomodation", -500)
    this.calculate()
  }

  addItemI(itemName, itemValue) {
    var tb = this.element.tBodies[0]
    var newRow = tb.insertRow(-1)
    var newCell = newRow.insertCell(0)
    newCell.textContent = itemName
    newCell = newRow.insertCell(1)
    newCell.textContent = itemValue
    newCell.setAttribute("data-totalisr-target", "item")
  }

  addItem({ params: { itemName, itemValue } }) {
    console.log(itemName, itemValue)
    this.addItemI(itemName, itemValue)
  }

  calculate() {
    this.totalValue = 0
    this.itemTargets.forEach((item, index) => {
      this.totalValue += Number(item.textContent)
    })
    this.totalTarget.textContent = `${this.totalValue}`
  }
}