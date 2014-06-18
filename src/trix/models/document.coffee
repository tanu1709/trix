#= require trix/models/block
#= require trix/models/block_list

class Trix.Document
  @fromJSONString: (string) ->
    @fromJSON JSON.parse(string)

  @fromJSON: (documentJSON) ->
    blocks = for blockJSON in documentJSON
      Trix.Block.fromJSON blockJSON
    new this blocks

  @fromHTML: (html) ->
    Trix.HTMLParser.parse(html).getDocument()

  constructor: (blocks = []) ->
    @blockList = new Trix.BlockList blocks
    @blockList.delegate = this

  getBlockAtIndex: (index) ->
    @blockList.getBlockAtIndex(index)

  getTextAtIndex: (index) ->
    @getBlockAtIndex(index)?.text

  eachBlock: (callback) ->
    callback(text, index) for text, index in @blockList.blocks

  eachBlockAtLocationRange: (range, callback) ->
    if range.isInSingleIndex()
      block = @getBlockAtIndex(range.index)
      textRange = [range.start.position, range.end.position]
      callback(block, textRange)
    else
      range.eachIndex (index) =>
        block = @getBlockAtIndex(index)

        textRange = switch index
          when range.start.index
            [range.start.position, block.text.getLength()]
          when range.end.index
            [0, range.end.position]
          else
            [0, block.text.getLength()]

        callback(block, textRange)

  insertTextAtLocationRange: (text, range) ->
    @removeTextAtLocationRange(range) unless range.isCollapsed()
    @getTextAtIndex(range.index).insertTextAtPosition(text, range.position)

  insertDocumentAtLocationRange: (document, range) ->
    @removeTextAtLocationRange(range) unless range.isCollapsed()
    @blockList.insertBlockListAtLocationRange(document.blockList, range)
    @delegate?.didEditDocument?(this)

  removeTextAtLocationRange: (range) ->
    textRuns = []
    @eachBlockAtLocationRange range, ({text}, textRange) ->
      textRuns.push({text, textRange})

    if textRuns.length is 1
      textRuns[0].text.removeTextAtRange(textRuns[0].textRange)
    else
      [first, ..., last] = textRuns

      last.text.removeTextAtRange([0, range.end.position])
      first.text.removeTextAtRange([range.start.position, first.text.getLength()])
      first.text.appendText(last.text)

      @blockList.removeText(text) for {text} in textRuns[1..]

    @delegate?.didEditDocument?(this)

  addAttributeAtLocationRange: (attribute, value, range) ->
    @eachBlockAtLocationRange range, (block, range) ->
      if Trix.attributes[attribute]?.block
        block.addAttribute(attribute, value)
      else
        unless range[0] is range[1]
          block.text.addAttributeAtRange(attribute, value, range)

  removeAttributeAtLocationRange: (attribute, range) ->
    @eachBlockAtLocationRange range, (block, textRange) ->
      if Trix.attributes[attribute]?.block
        block.removeAttribute(attribute)
      else
        unless textRange[0] is textRange[1]
          block.text.removeAttributeAtRange(attribute, textRange)

  replaceDocument: (document) ->
    @blockList.replaceBlockList(document.blockList)
    @delegate?.didEditDocument?(this)

  getCommonAttributesAtLocationRange: (range) ->
    if range.isCollapsed()
      @getCommonAttributesAtLocation(range.start)
    else
      textAttributes = []
      blockAttributes = []

      @eachBlockAtLocationRange range, (block, textRange) ->
        textAttributes.push(block.text.getCommonAttributesAtRange(textRange))
        blockAttributes.push(block.getAttributes())

      Trix.Hash.fromCommonAttributesOfObjects(textAttributes)
        .merge(Trix.Hash.fromCommonAttributesOfObjects(blockAttributes))
        .toObject()

  getCommonAttributesAtLocation: ({index, position}) ->
    block = @getBlockAtIndex(index)
    commonAttributes = block.getAttributes()

    attributes = block.text.getAttributesAtPosition(position)
    attributesLeft = block.text.getAttributesAtPosition(position - 1)
    inheritableAttributes = (key for key, value of Trix.attributes when value.inheritable)

    for key, value of attributesLeft
      if value is attributes[key] or key in inheritableAttributes
        commonAttributes[key] = value

    commonAttributes

  getAttachments: ->
    attachments = []
    for {text} in @blockList.blocks
      attachments = attachments.concat(text.getAttachments())
    attachments

  getTextAndRangeOfAttachment: (attachment) ->
    for {text} in @blockList.blocks
      if range = text.getRangeOfAttachment(attachment)
        return {text, range}

  getAttachmentById: (id) ->
    for {text} in @blockList.blocks
      if attachment = text.getAttachmentById(id)
        return attachment

  # BlockList delegate

  didEditBlockList: (blockList) ->
    @delegate?.didEditDocument?(this)

  toJSON: ->
    @blockList.toJSON()

  asJSON: ->
    JSON.stringify(this)
