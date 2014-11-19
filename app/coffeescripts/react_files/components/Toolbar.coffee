define [
  'underscore'
  'i18n!react_files'
  'react'
  'react-router'
  'compiled/react/shared/utils/withReactDOM'
  './UploadButton'
  '../utils/openMoveDialog'
  '../utils/downloadStuffAsAZip'
  '../utils/deleteStuff'
  '../modules/customPropTypes'
  './RestrictedDialogForm'
  'jquery'
  'compiled/jquery.rails_flash_notifications'
], (_, I18n, React, Router, withReactDOM, UploadButton, openMoveDialog, downloadStuffAsAZip, deleteStuff, customPropTypes, RestrictedDialogForm, $) ->

  Toolbar = React.createClass
    displayName: 'Toolbar'

    mixins: [Router.Navigation]

    propTypes:
      currentFolder: customPropTypes.folder # not required as we don't have it on the first render
      contextType: customPropTypes.contextType.isRequired
      contextId: customPropTypes.contextId.isRequired

    onSubmitSearch: (event) ->
      event.preventDefault()
      query = {search_term: @refs.searchTerm.getDOMNode().value}
      @transitionTo 'search', {}, query

    addFolder: (event) ->
      event.preventDefault()
      @props.currentFolder.folders.add({})

    downloadSelectedAsZip: ->
      downloadStuffAsAZip(@props.selectedItems, {
        contextType: @props.contextType,
        contextId: @props.contextId
      })

    componentDidUpdate: (prevProps) ->
      if prevProps.selectedItems.length isnt @props.selectedItems.length
        $.screenReaderFlashMessage(I18n.t('count_items_selected', '%{count} items selected', {
          count: @props.selectedItems.length
        }))

    getPreviewQuery: ->
      return unless @props.selectedItems.length
      retObj =
        preview: @props.selectedItems[0].id
      unless @props.selectedItems.length is 1
        retObj.only_preview = @props.selectedItems.map((item) -> item.id).join(',')
      if @props.query?.search_term
        retObj.search_term = @props.query.search_term
      retObj

    getPreviewRoute: ->
      if @props.query?.search_term
        'search'
      else if @props.currentFolder?.urlPath()
        'folder'
      else
        'rootFolder'



    # Function Summary
    # Create a blank dialog window via jQuery, then dump the RestrictedDialogForm into that
    # dialog window. This allows us to do react things inside of this already rendered
    # jQueryUI widget
    openRestrictedDialog: ->
      $dialog = $('<div>').dialog
        title: I18n.t("title.permissions", "Editing permissions for %{count} items", {count: @props.selectedItems.length})
        width: 400
        close: ->
          React.unmountComponentAtNode this
          $(this).remove()

      React.renderComponent(RestrictedDialogForm({
        models: @props.selectedItems
        closeDialog: -> $dialog.dialog('close')
      }), $dialog[0])

    render: withReactDOM ->
      showingButtons = @props.selectedItems.length
      downloadTitle = if @props.selectedItems.length is 1
        I18n.t('download', 'Download')
      else
        I18n.t('download_as_zip', 'Download as Zip')

      header {
        className:'ef-header grid-row between-xs'
        role: 'region'
        'aria-label': I18n.t('files_toolbar', 'Files Toolbar')
      },
        form {
          className: "col-lg-3 #{ if showingButtons
                                    'col-xs-4 col-sm-3 col-md-4'
                                  else
                                    'col-xs-7 col-sm-5 col-md-4'}"
          onSubmit: @onSubmitSearch
        },
          input
            placeholder:  I18n.t('search_for_files', 'Search for files')
            'aria-label': I18n.t('search_for_files', 'Search for files')
            type: 'search'
            ref: 'searchTerm'
            defaultValue: @props.query.search_term

        div className: "ui-buttonset col-xs #{'screenreader-only' unless showingButtons}",


          Router.Link  {
              to: @getPreviewRoute()
              query: @getPreviewQuery()
              splat: @props.currentFolder?.urlPath()
              className: 'ui-button btn-view'
              title: I18n.t('view', 'View')
              'data-tooltip': ''
            },
            i className: 'icon-search'

          if @props.userCanManageFilesForContext
            button {
              disabled: !showingButtons
              className: 'ui-button btn-restrict',
              onClick: @openRestrictedDialog
              title: I18n.t('restrict_access', 'Restrict Access')
              'aria-label': I18n.t('restrict_access', 'Restrict Access')
              'data-tooltip': ''
            },
              i className: 'icon-unpublished'

          button {
            disabled: !showingButtons
            className: 'ui-button btn-download'
            onClick: @downloadSelectedAsZip
            title: downloadTitle
            'aria-label': downloadTitle
            'data-tooltip': ''
          },
            i className: 'icon-download'

          if @props.userCanManageFilesForContext
            button {
              disabled: !showingButtons
              className: 'ui-button btn-move'
              onClick: (event) =>
                openMoveDialog(@props.selectedItems, {
                  contextType: @props.contextType
                  contextId: @props.contextId
                  returnFocusTo: event.target
                })
              title: I18n.t('move', 'Move')
              'aria-label': I18n.t('move', 'Move')
              'data-tooltip': ''
            },
              i className: 'icon-copy-course'

          if @props.userCanManageFilesForContext
            button {
              disabled: !showingButtons
              className: 'ui-button btn-delete'
              onClick: => deleteStuff(@props.selectedItems)
              title: I18n.t('delete', 'Delete')
              'aria-label': I18n.t('delete', 'Delete')
              'data-tooltip': ''
            },
              i className: 'icon-trash'

          span className: 'hidden-tablet hidden-phone', style: {paddingLeft: 13},
            I18n.t('count_items_selected', '%{count} items selected', {count: @props.selectedItems.length})

        if @props.userCanManageFilesForContext
          div className: 'text-right',
            span className: 'ui-buttonset',
              button {
                onClick: @addFolder
                className:'btn btn-add-folder'
                'aria-label': I18n.t('add_folder', 'Add Folder')
              },
                i(className:'icon-plus'),
                span className: ('hidden-phone' if showingButtons),
                  I18n.t('folder', 'Folder')

            span className: 'ui-buttonset',
              UploadButton
                currentFolder: @props.currentFolder
                showingButtons: showingButtons
                contextId: @props.contextId
                contextType: @props.contextType
