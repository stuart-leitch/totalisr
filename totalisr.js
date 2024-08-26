import { Application, Controller } from "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js"
import TotalisrController from "./totalisr_controller.js"

window.Stimulus = Application.start()

Stimulus.register("totalisr", TotalisrController)