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
    if (isNaN(itemValue)) {
      newCell.style.color = "red"
    }
    newCell = newRow.insertCell(2)
    newCell.insertAdjacentHTML("beforeend", "<button data-action='click->totalisr#editItem'>✍️</button>")
    newCell.insertAdjacentHTML("beforeend", "<button data-action='click->totalisr#moveItemUp'>⬆️</button>")
    newCell.insertAdjacentHTML("beforeend", "<button data-action='click->totalisr#moveItemDown'>⬇️</button>")
    newCell.insertAdjacentHTML("beforeend", "<button data-action='click->totalisr#removeItem'>🗑️</button>")

    this.calculate()
  }

  addNewItem(event) {
    var itemName = this.newItemNameTarget.value
    var itemValue = this.newItemValueTarget.value
    if (isNaN(itemValue)) {
      this.newItemValueTarget.style.color = "red"
    } else {

      this.newItemNameTarget.value = ""
      this.newItemValueTarget.value = ""

      this.addItemToTable(itemName, itemValue)
    }
  }

  test_data() {
    this.addItemToTable("Budget", 1000)
    this.addItemToTable("Flights", -250)
    this.addItemToTable("Accomodation", -500)
  }

  calculate() {
    this.totalValue = 0
    this.itemTargets.forEach((item, index) => {
      if (!isNaN(item.textContent)) {
        this.totalValue += Number(item.textContent)
      }
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

  moveItemUp(event) {
    var row = event.srcElement.parentElement.parentElement
    var previousRow = row.previousElementSibling
    if (previousRow) {
      row.parentNode.insertBefore(row, previousRow)
    }
    this.calculate()
  }

  moveItemDown(event) {
    var row = event.srcElement.parentElement.parentElement
    var nextRow = row.nextElementSibling
    if (nextRow) {
      row.parentNode.insertBefore(nextRow, row)
    }
    this.calculate()
  }

}