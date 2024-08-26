import { Controller } from "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js"

export default class extends Controller {
  static targets = ["item", "total", "newItemName", "newItemValue"]
  static values = { total: Number }

  addItemToTable(itemName, itemValue) {
    var tb = this.element.tBodies[0]
    var newRow = tb.insertRow(-1)
    var newCell = newRow.insertCell(0)
    newCell.textContent = itemName
    newCell = newRow.insertCell(1)
    newCell.textContent = itemValue
    newCell.setAttribute("data-totalisr-target", "item")
    newCell = newRow.insertCell(2)
    newCell.innerHTML = "<button data-action='click->totalisr#removeItem'>Remove</button> <button data-action='click->totalisr#editItem'>Edit</button>"
    this.calculate()
  }

  addNewItem(event) {
    var itemName = this.newItemNameTarget.value
    var itemValue = this.newItemValueTarget.value

    this.newItemNameTarget.value = ""
    this.newItemValueTarget.value = ""

    this.addItemToTable(itemName, itemValue)
  }

  test_data() {
    this.addItemToTable("Budget", 1000)
    this.addItemToTable("Flights", -250)
    this.addItemToTable("Accomodation", -500)
  }

  calculate() {
    this.totalValue = 0
    this.itemTargets.forEach((item, index) => {
      this.totalValue += Number(item.textContent)
    })
    this.totalTarget.textContent = `${this.totalValue}`
  }

  removeItem(event) {
    event.srcElement.parentElement.parentElement.remove()
    this.calculate()
  }

  editItem(event) {
    var row = event.srcElement.parentElement.parentElement

    this.newItemNameTarget.value = row.cells[0].textContent
    this.newItemValueTarget.value = row.cells[1].textContent

    row.remove()
    this.newItemNameTarget.focus()

    this.calculate()
  }
}