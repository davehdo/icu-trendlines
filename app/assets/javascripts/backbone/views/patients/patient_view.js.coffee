Trendline.Views.Patients ||= {}

class Trendline.Views.Patients.PatientView extends Backbone.View
  template: JST["backbone/templates/patients/patient"]

  events:
    "click .destroy" : "destroy"

  tagName: "tr"

  destroy: () ->
    if confirm "Are you sure you want to delete?"
      @model.destroy()
      this.remove()

    return false

  render: ->
    @$el.html(@template(@model.toJSON() ))
    return this
