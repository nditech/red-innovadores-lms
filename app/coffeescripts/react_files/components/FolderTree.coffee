define [
  'react'
  'react-router'
  'compiled/views/FileBrowserView'
  '../modules/customPropTypes'
], (React, Router, FileBrowserView, customPropTypes) ->

  FolderTree = React.createClass
    displayName: 'FolderTree'

    propTypes:
      rootFoldersToShow: React.PropTypes.arrayOf(customPropTypes.folder).isRequired
      rootTillCurrentFolder: React.PropTypes.arrayOf(customPropTypes.folder)

    mixins: [Router.Navigation]

    componentDidMount: ->
      new FileBrowserView({
        onlyShowFolders: true,
        rootFoldersToShow: @props.rootFoldersToShow
        onClick: @onClick
        dndOptions: @props.dndOptions
        href: @hrefFor
      }).render().$el.appendTo(@refs.FolderTreeHolder.getDOMNode())
      @expandTillCurrentFolder(@props)


    componentWillReceiveProps: (newProps) ->
      @expandTillCurrentFolder(newProps)


    onClick: (event, folder) ->
      event.preventDefault()
      @transitionTo (if folder.urlPath() then 'folder' else 'rootFolder'), splat: folder.urlPath()


    hrefFor: (folder) ->
      @makeHref (if folder.urlPath() then 'folder' else 'rootFolder'), splat: folder.urlPath()


    expandTillCurrentFolder: (props) ->
      expandFolder = (folderIndex) ->
        return unless folder = props.rootTillCurrentFolder?[folderIndex]
        folder.expand(false, {onlyShowFolders: true}).then ->
          expandFolder(folderIndex + 1)
      expandFolder(0)


    render: ->
      React.DOM.div( {className:"ef-folder-list", ref: 'FolderTreeHolder'})