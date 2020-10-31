
import flippy, flippy/paths, chroma, math, vmath, schema, print, typography

const
  white = rgba(255, 255, 255, 255)
  clear = rgba(0, 0, 0, 0)

var
  ctx: Image
  fillCtx: Image
  maskCtx: Image
  nodeStack: seq[Node]
  parentNode: Node
  at: Vec2

proc frameFills(node: Node) =
  if node.fills.len > 0:
    for fill in node.fills:
      ctx.fillRect(
        rect(
          node.absoluteBoundingBox.x + at.x,
          node.absoluteBoundingBox.y + at.y,
          node.absoluteBoundingBox.width,
          node.absoluteBoundingBox.height,
        ),
        fill.color.rgba
      )

proc drawNode*(node: Node)

proc drawChildren(node: Node) =
  parentNode = node
  nodeStack.add(node)
  for child in node.children:
    drawNode(child)
  discard nodeStack.pop()
  if nodeStack.len > 0:
    parentNode = nodeStack[^1]

proc applyPaint(fill: Paint, node: Node) =
  let pos = node.absoluteBoundingBox.xy + at

  fillCtx.fill(clear)

  if fill.`type` == "IMAGE":
    var image = loadImage("images/" & fill.imageRef)

    if fill.scaleMode == "FILL":
      let
        ratioW = image.width.float32 / node.absoluteBoundingBox.width
        ratioH = image.height.float32 / node.absoluteBoundingBox.height
        scale = min(ratioW, ratioH)
      image = image.resize(int(image.width.float32 / scale), int(image.height.float32 / scale))
      let center = node.absoluteBoundingBox.wh
      let topRight = pos + center/2 - vec2(image.width/2, image.height/2)
      fillCtx.blit(image, topRight)
    elif fill.scaleMode == "FIT":

      #fillCtx.fill(rgba(255, 255, 255, 255))

      let
        ratioW = image.width.float32 / node.absoluteBoundingBox.width
        ratioH = image.height.float32 / node.absoluteBoundingBox.height
        scale = max(ratioW, ratioH)
      image = image.resize(int(image.width.float32 / scale), int(image.height.float32 / scale))
      let center = node.absoluteBoundingBox.wh
      let topRight = pos + center/2 - vec2(image.width/2, image.height/2)
      fillCtx.blit(image, topRight)
    elif fill.scaleMode == "STRETCH":
      # Figma ui calls this crop.
      # TODO figure out the matrix:
      var mat: Mat4
      mat[ 0] = fill.imageTransform[0][0]
      mat[ 1] = fill.imageTransform[0][1]
      mat[ 2] = 0
      mat[ 3] = 0

      mat[ 4] = fill.imageTransform[1][0]
      mat[ 5] = fill.imageTransform[1][1]
      mat[ 6] = 0
      mat[ 7] = 0

      mat[ 8] = 0
      mat[ 9] = 0
      mat[10] = 1
      mat[11] = 0

      mat[12] = fill.imageTransform[0][2]
      mat[13] = fill.imageTransform[1][2]
      mat[14] = 0
      mat[15] = 1
      fillCtx.blitWithAlpha(image, mat)

    elif fill.scaleMode == "TILE":
      image = image.resize(
        int(image.width.float32 * fill.scalingFactor),
        int(image.height.float32 * fill.scalingFactor))
      var x = 0.0
      while x < node.absoluteBoundingBox.width:
        var y = 0.0
        while y < node.absoluteBoundingBox.height:
          fillCtx.blit(image, pos + vec2(x, y))
          y += image.height.float32
        x += image.width.float32

  elif fill.`type` == "SOLID":
    fillCtx.fill(fill.color.rgba)

  ctx.blitMasked(fillCtx, maskCtx)

proc drawNode*(node: Node) =
  case node.`type`
  of "DOCUMENT", "CANVAS", "GROUP":
    drawChildren(node)

  of "FRAME":
    if parentNode.`type` == "CANVAS":
      #if node.name != "image_tile": return
      ctx = newImage(
        node.absoluteBoundingBox.width.int,
        node.absoluteBoundingBox.height.int,
        4)
      fillCtx = newImage(ctx.width, ctx.height, 4)
      maskCtx = newImage(ctx.width, ctx.height, 4)
      at = vec2(
        -node.absoluteBoundingBox.x,
        -node.absoluteBoundingBox.y
      )
      frameFills(node)
      drawChildren(node)
      print "write frame", node.name
      ctx.save("frames/" & node.name & ".png")
    else:
      parentNode = node
      frameFills(node)
      drawChildren(node)

  of "RECTANGLE":

    maskCtx.fill(clear)

    if node.cornerRadius > 0:
      # Rectangle with common corners.
      let
        x = node.absoluteBoundingBox.x + at.x
        y = node.absoluteBoundingBox.y + at.y
        w = node.absoluteBoundingBox.width
        h = node.absoluteBoundingBox.height
        r = node.cornerRadius
      var path = newPath()
      path.moveTo(x+r, y)
      path.arcTo(x+w, y,   x+w, y+h, r)
      path.arcTo(x+w, y+h, x,   y+h, r)
      path.arcTo(x,   y+h, x,   y,   r)
      path.arcTo(x,   y,   x+w, y,   r)
      maskCtx.fillPolygon(
        path,
        white
      )
    elif node.rectangleCornerRadii.len == 4:
      # Rectangle with different corners.
      let
        x = node.absoluteBoundingBox.x + at.x
        y = node.absoluteBoundingBox.y + at.y
        w = node.absoluteBoundingBox.width
        h = node.absoluteBoundingBox.height
        nw = node.rectangleCornerRadii[0]
        ne = node.rectangleCornerRadii[1]
        se = node.rectangleCornerRadii[2]
        sw = node.rectangleCornerRadii[3]
      var path = newPath()
      path.moveTo(x+nw, y)
      path.arcTo(x+w, y,   x+w, y+h, ne)
      path.arcTo(x+w, y+h, x,   y+h, se)
      path.arcTo(x,   y+h, x,   y,   sw)
      path.arcTo(x,   y,   x+w, y,   nw)
      maskCtx.fillPolygon(
        path,
        white
      )
    else:
      # Basic rectangle.
      maskCtx.fillRect(
        rect(
          node.absoluteBoundingBox.x + at.x,
          node.absoluteBoundingBox.y + at.y,
          node.absoluteBoundingBox.width,
          node.absoluteBoundingBox.height,
        ),
        white
      )

    for fill in node.fills:
      applyPaint(fill, node)

  of "VECTOR":
    for fill in node.fills:
      if fill.`type` == "IMAGE":
        print "image fill", fill.imageRef
      elif fill.`type` == "SOLID":
        for geometry in node.fillGeometry:
          let pos = node.absoluteBoundingBox.xy + at
          ctx.fillPolygon(
            geometry.path,
            fill.color.rgba,
            pos
          )
    for stroke in node.strokes:
      if stroke.`type` == "IMAGE":
        print "image stroke", stroke.imageRef
      elif stroke.`type` == "SOLID":
        for geometry in node.strokeGeometry:
          let pos = node.absoluteBoundingBox.xy + at
          ctx.fillPolygon(
            geometry.path,
            stroke.color.rgba,
            pos
          )

  of "TEXT":

    func hAlignCase(s: string): HAlignMode =
      case s
      of "CENTER": return Center
      of "LEFT": return Left
      of "RIGHT": return Right
      else: return Left

    func vAlignCase(s: string): VAlignMode =
      case s
      of "CENTER": return Middle
      of "TOP": return Top
      of "BOTTOM": return Bottom
      else: Top

    let pos = node.absoluteBoundingBox.xy + at
    var font = readFontTtf("fonts/" & node.style.fontFamily & ".ttf")
    font.size = node.style.fontSize
    font.lineHeight = node.style.lineHeightPx

    let layout = font.typeset(
      text = node.characters,
      pos = pos,
      size = node.absoluteBoundingBox.wh,
      hAlign = hAlignCase(node.style.textAlignHorizontal),
      vAlign =vAlignCase(node.style.textAlignVertical)
    )

    maskCtx.fill(clear)
    maskCtx.drawText(layout)

    for fill in node.fills:
      applyPaint(fill, node)
