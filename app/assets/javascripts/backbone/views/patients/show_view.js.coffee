Trendline.Views.Patients ||= {}

class Trendline.Views.Patients.ShowView extends Backbone.View
  template: JST["backbone/templates/patients/show"]

  initialize: =>
    @svg_annotations = undefined
    @hovering = false

  addAll: =>
    # these are the shared parameters for all the charts
    @margin = {top: 20, right: 20, bottom: 30, left: 50}
    @width = 960 - @margin.left - @margin.right
    @height = 160 - @margin.top - @margin.bottom

    # create the scales
    # i.e. x is a function that maps x to a pixel 
    @x = d3.time.scale().range([0, @width]).domain([Date.now() - 60*60*24*3000, Date.now()])

    # each chart has different domain so this will have to be set individually
    @y = d3.scale.linear().range([@height, 0])

    @parseDate = d3.time.format.iso.parse

    @chartContainer = @$el.find(".chart-container")[0]

    @addOne()

  addOne: =>
    # produces axis-generator, a function that when called will draw the axes
    xAxis = d3.svg.axis().scale(@x).orient("bottom")
    yAxis = d3.svg.axis().scale(@y).orient("left")

    # a line generator that looks for data w/ format ___
    line = d3.svg.line().x((d) => @x(d.date)).y((d) => @y(d.close))

    svg = d3.select(@chartContainer).append("svg")
      .attr("width", @width + @margin.left + @margin.right)
      .attr("height", @height + @margin.top + @margin.bottom)
      .append("g")
      .attr("transform", "translate(" + @margin.left + "," + @margin.top + ")")

    svg_y_axis = d3.select(@$el.find(".y-axis-container")[0]).append("svg")
      .attr("height", @height + @margin.top + @margin.bottom)
      .append("g")
      .attr("transform", "translate(" + @margin.left + "," + @margin.top + ")")
	
    $div_detail = $("<div></div>")
      .attr("style", "height: #{ @height + @margin.top + @margin.bottom }px")
      .html "<h4>Blood pressure</h4><h1>96<h1>"
    @$el.find(".detail-container").append $div_detail

    # retrieve and plot the data
    d3.json "/patients/#{ @model.get("id") }.json", (error, data) =>
      if (error)
        throw error

      data.forEach (d) =>
        d.date = @parseDate(d.date)
        d.close = +d.close

      # set the domains for the mappers, should the X up so they all share the same
      # @x.domain(d3.extent(data, (d) -> d.date ))
      @y.domain(d3.extent(data, (d) -> d.close ))

      svg.append("g").attr("class", "x axis").attr("transform", "translate(0," + @height + ")").call(xAxis)

      # draws the y-axis
      svg_y_axis.append("g").attr("class", "y axis").call(yAxis)

      # draws the trendline
      svg.append("path").attr("class", "line").attr("d", line(data))

    $(svg[0][0].parentElement).droppable
      accept: ".label",
      activeClass: "custom-state-active",
      over: (event, ui) => @hovering = true
      out: (event, ui) => @hovering = false
      drop: ( event, ui ) =>
        # options: ui.position.left, event.offsetX, event.pageX, event.screenX

        annotation = new @model.annotations.model
          category: "Event", 
          occurred_at: @x.invert( event.offsetX ).toISOString()
        @model.annotations.add annotation

        annotation.save {}, 
          success: (m) => console.log("Saved Annotation")
        @displayAnnotations() # refresh the annotations to display the new one

  displayAnnotations: =>
    # create the container for annotations
    if @svg_annotations == undefined
      @svg_annotations = d3.select(@chartContainer).append("svg").attr("class", "annotations")
        .attr("width", @width + @margin.left + @margin.right)
        .attr("height", 100)
        .append("g")
        .attr("transform", "translate(" + @margin.left + "," + @margin.top + ")")
    else # remove all the annotations for this refresh
      @svg_annotations.selectAll("g").remove()

    console.log "Rendering annotations"
    @model.annotations.map (annotation) =>
      g = @svg_annotations.append("g")
        .attr("transform", "translate(#{ @x( @parseDate( annotation.get "occurred_at")) },0)")
      g.append("line").attr("x1", 0).attr("y1", 0).attr("x2", 0).attr("y2", 10)
        .style("stroke-width", 2)
        .style("stroke", "blue")
        .style("fill", "none")
      g.append("text")
        .text( "asdf #{ annotation.get "comment"}" )
        .attr("x", 3).attr("y", 20)

      # when dragged, update position
      $(g[0]).draggable
        revert: "invalid"
        containment: "document"
        helper: "clone"
        cursor: "move"
        drag: (event, ui) =>
          annotation.set "occurred_at": @x.invert( event.offsetX ).toISOString()
          @displayAnnotations()
        stop: (event, ui) =>
          console.log "stop. should save the annotation here"

  render: ->
    @$el.html(@template(@model.toJSON() ))
    @addAll()
    @displayAnnotations()

    @$el.find("#draggable-markers-container .label").draggable
      revert: "invalid" # when not dropped, the item will revert back to its initial position
      containment: "document"
      helper: "clone"
      cursor: "move"
      drag: (event, ui) => 
        # remove prior cursor
        @svg_annotations.selectAll("g.cursor").remove()

        if @hovering
          # produces a cursor so user knows where the annotation will drop
          x = event.offsetX # when hovering over a droppable, offsetX tends to 
          # return the coordinates relative to the droppable

          g = @svg_annotations.append("g")
            .attr("class", "cursor")
            .attr("transform", "translate(#{x},0)")
          g.append("line").attr("x1", 0).attr("y1", 0).attr("x2", 0).attr("y2", 10)
            .style("stroke-width", 2)
            .style("stroke", "red")
            .style("fill", "none")

    return this
