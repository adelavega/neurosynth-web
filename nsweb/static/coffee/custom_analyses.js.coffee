{div, br, ul, li, a, p, h1, h2, h4, h5, span, form, input, button, hr, table, thead, tr, th, td, label} = React.DOM
ce = React.createElement

SELECTED = 'info' # CSS class to apply to selected rows

# Local Storage Helper Functions
getSelectedStudies = ->
  selection = JSON.parse(window.localStorage.getItem('ns-selection') or "{}")

saveSelection = (selection) ->
  window.localStorage.setItem('ns-selection', JSON.stringify(selection))
#  window.localStorage.setItem('ns-uuid', null)

saveToLocalStorage = (key, value) ->
  window.localStorage.setItem(key, JSON.stringify(value))

getFromLocalStorage = (key) ->
  val = window.localStorage.getItem(key)
  if val is null then val else JSON.parse(val)
#  JSON.parse(window.localStorage.getItem(key))

getPMID = (tr) ->
  # Given tr DOM element parse the PMID
  # Assumes the first column has a link of the form ..../<pmid>
  href = $(tr).find('a').first().attr('href')
  return null if not href?
  return parseInt(/(\d+)/.exec(href)[0])

arrayToObject = (array) ->
  obj = {}
  for item in array
    obj[item] = 1
  return obj

app =
  props:
    fetchAllAnalysesURL: '/api/custom/all/'
    fetchAllStudiesURL: '/api/studies/all/'
    saveURL: '/api/custom/save/'
    deleteURL: '/api/custom/'
    studiesTableURL: '/api/analyses/' # /api/analyses/<analysis id>/ (to be consumed by DataTable)
    getFullAnalysisURL: '/api/analyses/full/' # /api/analyses/full/ 

  state: # All mutable app state must be contained here
    analyses: []
    allStudies: []
    activeAnalysis:
      studies: {}
#      studyList: => Object.keys(@studies)

  setActiveAnalysis: (uuid) ->
    @state.activeAnalysis = $.extend {}, @state.analyses.filter((a) -> a.uuid is uuid)[0]
    @state.activeAnalysis.studies = arrayToObject(@state.activeAnalysis.studies)
    @state.activeAnalysis.saved = true
    saveSelection(@state.activeAnalysis.studies)
    @render()

  activeStudies: ->
    return Object.keys(@state.activeAnalysis.studies).map (pmid) => @state.studyDetails[pmid]

  removeStudy: (pmid) ->
    console.log "In app.removeStudy"
    delete @state.activeAnalysis.studies[pmid]
    @state.activeAnalysis.saved = false
    saveSelection(@state.activeAnalysis.studies)
    @render()

  addStudy: (pmid) ->
    console.log "In app.addStudy"
    @state.activeAnalysis.studies[pmid] = 1
    @state.activeAnalysis.saved = false
    saveSelection(@state.activeAnalysis.studies)
    @render()

  cloneActiveAnalysis: ->
    selection = {}
    @state.activeAnalysis.studies.forEach (study) ->
      selection[study] = 1
    saveSelection(selection)
    @state.activeAnalysis.uuid = null
    @state.activeAnalysis.id = null
    @render()

  discardSelection: ->
    saveSelection({})
    @state.activeAnalysis = {}
    @render()

  setActiveAnalysisName: (name) ->
    @state.activeAnalysis.name = name
    @state.activeAnalysis.saved = false
    @render()

  deleteAnalysis: (uuid) ->
    $.ajax
      dataType: 'json'
      type: 'DELETE'
      url: @props.deleteURL + uuid.toString() + '/'
      success: (response) =>
        @state.activeAnalysis = {}
        @init()
#        @fetchAllAnalyses()

  saveActiveAnalysis: (name) ->
    @state.activeAnalysis.name = name
    data =
      studies: Object.keys(@state.activeAnalysis.studies)
      name: name
      uuid: @state.activeAnalysis.uuid
    $.ajax
      dataType: 'json'
      type: 'POST'
      data:
        data: JSON.stringify(data)
      url: @props.saveURL
      success: (data) =>
        @state.activeAnalysis.uuid = data.uuid
        @state.activeAnalysis.id = data.id
        @state.activeAnalysis.saved = true
        saveToLocalStorage('ns-uuid', data.uuid)
        @fetchAllAnalyses()

  fetchAllAnalyses: ->
    $.ajax
      dataType: 'json'
      type: 'GET'
      url: @props.fetchAllAnalysesURL
      success: (data) =>
        @state.analyses = data.analyses
        @render()
      error: (xhr, status, err) =>
        console.error @props.url, status, err.toString()

  fetchAllStudies: ->
    $.ajax
      dataType: 'json'
      type: 'GET'
      url: @props.fetchAllStudiesURL
      success: (data) =>
        @state.allStudies = data.studies
        @state.studyDetails = {}
        for study in data.studies
          @state.studyDetails[study.pmid] = study
        @fetchAllAnalyses()
#        @render()
      error: (xhr, status, err) =>
        console.error @props.url, status, err.toString()

  init: ->
    ###
    See if there are any selected studies in localStorage.
    If so, create a new analysis
    ###
#    studies = getFromLocalStorage('ns-selection')
    uuid = getFromLocalStorage('ns-uuid')
#    if studies
#      studies = Object.keys(studies)
#    else
#      studies = []
#
#    @state.activeAnalysis = {}
    if uuid is null
      @state.activeAnalysis.studies = getFromLocalStorage('ns-selection') or []
      @state.activeAnalysis.uuid = uuid

    @fetchAllStudies()
#    @fetchAllAnalyses(@fetchAllStudies(@render))

  render: ->
    if not document.getElementById('custom-list-container')?
      return
    React.render ce(AnalysisList, {analyses:@state.analyses, selected_uuid:@state.activeAnalysis.uuid}),
      document.getElementById('custom-list-container')
    React.render(ce(ActiveAnalysis, {analysis: @state.activeAnalysis}), document.getElementById('active-analysis-container'))

AnalysisListItem = React.createClass
  loadHandler: ->
    app.setActiveAnalysis(@props.uuid)

  render: ->
    div {className: "row bs-callout panel #{ if @props.selected then 'bs-callout-info' else ''}"},
      div {className: "col-md-8"},
        ul {className:'list-unstyled'},
          li {}, "Name: #{ @props.name }"
          li {}, "uuid: #{ @props.uuid }"
      div {className: "col-md-4"},
        button {className:"btn btn-primary btn-sm #{ if @props.selected then 'disabled' else ''}", onClick: @loadHandler}, 'Load'

AnalysisList = React.createClass
  render: ->
    div {className:'custom-analysis-list panel'},
      h4 {}, "Your saved custom analyses (#{ @props.analyses.length })"
      hr {}, ''
      @props.analyses.map (analysis) =>
        selected = if @props.selected_uuid is analysis.uuid then true else false
        ce AnalysisListItem, {key: analysis.uuid, uuid: analysis.uuid, name:analysis.name, selected: selected}


ActiveAnalysis = React.createClass
  save: ->
    app.saveActiveAnalysis @refs.name.getDOMNode().value

  deleteHandler: ->
    app.deleteAnalysis(@props.analysis.uuid)

  cloneHandler: ->
    app.cloneActiveAnalysis()

  discardHandler: ->
    app.discardSelection()

  nameChangeHandler: ->
    app.setActiveAnalysisName @refs.name.getDOMNode().value

  render: ->
#    if Object.keys(@props.analysis).length is 0
#      return div {}, 'No analyis loaded.'
    uuid = @props.analysis.uuid
    studies = Object.keys(@props.analysis.studies)
    saved = @props.analysis.saved

#    saveButton = button {className:"btn btn-primary #{ if saved then }", onClick: @save}, 'Save selection as new custom analysis'

    if uuid # previously saved analysis
      header = div {},
        div {className:'row'},
          div {className: 'col-md-6'},
            label {}, 'Analysis name:',
              input {type: 'text', className: 'form-control', ref: 'name', value: @props.analysis.name, onChange: @nameChangeHandler}
#            h4 {}, @props.analysis.name
            p {}, "uuid: #{ uuid }"
          div {className: 'col-md-6'},
            p {}, "#{ studies.length } studies in this analysis"
            button {className: 'btn btn-info btn-sm', onClick: @cloneHandler}, 'Clone Analysis'
            span {}, ' '
            button {className:'btn btn-primary', disabled: "#{ if saved then 'disabled' else ''}", onClick: @save}, 'Save'
            span {}, ' '
            button {className: 'btn btn-danger btn-sm', onClick: @deleteHandler}, 'Delete Analysis'
        div {className:'row'},
          div {className: 'col-md-12'},
            hr {}, ''
#      studiesSection = ce StudiesTable, {analysis: @props.analysis}
#      studiesSection = ce SelectedStudiesTable, {}
    else # headless (without uuid) analysis only present in browser's local storage
      header = div {},
        div {className: 'row'},
          div {className: 'col-md-8'},
            input {type: 'text', className: 'form-control', placeholder: 'Enter a name for this analysis', ref: 'name'}
            br {}, ''
            button {className:'btn btn-primary', disabled: "#{ if saved then 'disabled' else ''}", onClick: @save}, 'Save selection as new custom analysis'
            span {}, ' '
            button {className:'btn btn-danger', onClick: @discardHandler}, 'Discard current selection'
          div {className: 'col-md-4'},
            p {}, "#{ studies.length } studies selected"
        div {className:'row'},
          div {className: 'col-md-12'},
            hr {}, ''
#      studiesSection = div {},
#        p {}, 'Below are the PMIDs of the studies you have selected but not yet saved. Save this analysis to see the study details. You can always delete or clone it.'
#        @props.analysis.studies.map (x) ->
#          p {}, x.toString()

    return div {},
      header,
      div {className:'row'},
        div {className: 'col-md-12'},
          div {role: 'tabpanel'},
            ul {className: 'nav nav-tabs', role:'tablist'},
              li {role:'presentation', className: 'active'},
                a {href:'#selected-studies-tab', role:'tab', 'data-toggle':'tab'}, "Selected Studies (#{ studies.length })"
              li {role:'presentation'},
                a {href:'#all-studies-tab', role:'tab', 'data-toggle':'tab'}, "All studies (#{ app.state.allStudies.length })"
            div {className: 'tab-content'},
              div {className: 'tab-pane active', role:'tab-panel', id:'selected-studies-tab'},
                ce SelectedStudiesTable, {}
#                studiesSection
              div {className: 'tab-pane', role:'tab-panel', id:'all-studies-tab'},
                br {},
                p {}, "Add or remove studies to your analysis by clicking on the study. Studies that are already added are highlighted in blue."
                ce AllStudiestable
#          ce StudiesTable, {analysis: @props.analysis}

StudiesTable = React.createClass
  componentDidMount: ->
    $('#custom-studies-table').dataTable
      pageLength: 10
      serverSide: true
      ajax: app.props.studiesTableURL + @props.analysis.id + '/'
      order: [[1, 'desc']]

  componentDidUpdate: ->
    if not @props.analysis.id
      return
    url = app.props.studiesTableURL + @props.analysis.id + '/'
    studyTable = $('#custom-studies-table').DataTable()
    studyTable.ajax.url(url)
    studyTable.ajax.reload()

  render: ->
    table {className:'table table-hover', id: 'custom-studies-table'},
      thead {},
        tr {},
          th {}, 'Title '
          th {}, 'Authors'
          th {}, 'Journal'
          th {}, 'Year'
          th {}, 'PMID'

SelectedStudiesTable = React.createClass
  tableData: ->
    app.activeStudies().map (item) ->
      $.extend({'remove': '<button class="btn btn-sm">remove</button>'}, item)

  setupRemoveButton: ->
    $('#selected-studies-table').find('tr').on 'click', 'button', ->
      pmid = getPMID($(this).closest('tr'))
      app.removeStudy(pmid)

  componentDidMount: ->
    $('#selected-studies-table').DataTable
      data: @tableData()
      columns: [
        {data: 'title'}
        {data: 'authors'}
        {data: 'journal'}
        {data: 'year'}
        {data: 'pmid'}
        {data: 'remove'}
      ]
    @setupRemoveButton()

  componentDidUpdate: ->
    t = $('#selected-studies-table').DataTable()
    t.clear()
    t.rows.add @tableData()
    t.draw()
    @setupRemoveButton()

  render: ->
    table {className:'table table-hover', id: 'selected-studies-table'},
      thead {},
        tr {},
          th {}, 'Title '
          th {}, 'Authors'
          th {}, 'Journal'
          th {}, 'Year'
          th {}, 'PMID'
          th {}, 'Action'


AllStudiestable = React.createClass
  componentDidMount: ->
    $('#all-studies-table').DataTable
      data: app.state.allStudies
      columns: [
        {data: 'title'}
        {data: 'authors'}
        {data: 'journal'}
        {data: 'year'}
        {data: 'pmid'}
      ]
    setupSelectableTable()

  componentDidUpdate: ->
    redrawTableSelection()

  render: ->
    table {className: 'table selectable-table', id: 'all-studies-table'},
      thead {},
        tr {},
          th {}, 'Title '
          th {}, 'Authors'
          th {}, 'Journal'
          th {}, 'Year'
          th {}, 'PMID'

redrawTableSelection = ->
  selection = getSelectedStudies()
  $('.selectable-table').find('tbody').find('tr').each ->
    pmid = getPMID(this)
    if pmid of selection
      $(this).addClass(SELECTED)
    else
      $(this).removeClass(SELECTED)

setupSelectableTable = ->
  $('.selectable-table').on 'click', 'tr', ->
    console.log 'row clicked'
    pmid = getPMID(this)
    if not pmid?
      return
    selection = getSelectedStudies()
    if pmid of selection
      app.removeStudy(pmid)
#      delete selection[pmid]
    else
      app.addStudy(pmid)
    redrawTableSelection()
#      selection[pmid] = 1
#    saveSelection(selection)
#    $(this).toggleClass(SELECTED)

  $('.selectable-table').on 'draw.dt', ->
    redrawTableSelection()

  $('#select-all-btn').click ->
    selection = getSelectedStudies()
    $('tbody').find('tr').each ->
      pmid = getPMID(this)
      selection[pmid] = 1
    saveSelection(selection)
    redrawTableSelection()

  $('#deselect-all-btn').click ->
    selection = getSelectedStudies()
    $('tbody').find('tr').each ->
      pmid = getPMID(this)
      delete selection[pmid]
    saveSelection(selection)
    redrawTableSelection()

  redrawTableSelection()

$(document).ready ->
  setupSelectableTable()
  app.init()

