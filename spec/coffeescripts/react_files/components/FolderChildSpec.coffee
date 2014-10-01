define [
  'react'
  'jquery'
  'compiled/react_files/components/FolderChild'
  'compiled/models/Folder'
  'compiled/react_files/routes'
], (React, $, FolderChild, Folder, routes) ->

  Simulate = React.addons.TestUtils.Simulate

  TEST_FOLDERS_COLLECTION_URL = '/courses/<course_id>/folders/<folder_id>/folders'

  module 'FolderChild',
    setup: ->
      React.addons.TestUtils.renderIntoDocument(routes)
      @currentFolder = new Folder()
      @currentFolder.folders.url = TEST_FOLDERS_COLLECTION_URL
      thisFolder = @currentFolder.folders.add({})

      sampleProps =
        model: thisFolder
        params:
          contextId: 'course_id'
          contextType: 'courses'

      @component = React.renderComponent(FolderChild(sampleProps), $('<div>').appendTo('body')[0])

    teardown: ->
      React.unmountComponentAtNode(@component.getDOMNode().parentNode)


  test 'allows creating a new folder', ->
    input = @component.refs.newName.getDOMNode()
    equal input, document.activeElement, 'input is focused automatically'

    input.value = 'testing 123'
    sinon.stub($, 'ajax')
    # Simulate.keyDown(input, {key: "Enter"})
    Simulate.submit(input.form)
    ok $.ajax.calledWithMatch({
      url: TEST_FOLDERS_COLLECTION_URL
      type: 'POST'
      data: '{"name":"testing 123"}'
    }), 'sends POST to create folder'
    $.ajax.restore()
