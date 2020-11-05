import json, jsons, print, tables, chroma, vmath, flippy,
    httpclient2, json, strutils, os

type
  Component* = ref object
    key*: string
    name*: string
    description*: string

  Device* = ref object
    `type`*: string
    rotation*: string

  Box* = ref object
    x*, y*, width*, height*: float32

  Constraints* = ref object
    vertical*: string
    horizontal*: string

  GradientStops* = ref object
    color*: Color
    position*: float32

  Paint* = ref object
    blendMode*: string
    `type`*: string
    color*: Color
    scaleMode*: string
    imageRef*: string
    imageTransform*: seq[seq[float32]]
    scalingFactor*: float32
    gradientHandlePositions*: seq[Vec2]
    gradientStops*: seq[GradientStops]

  Effect* = ref object
    `type`*: string
    visible*: bool
    color*: Color
    blendMode*: string
    offset*: Vec2
    radius*: float32
    spread*: float32

  Grid* = ref object
    `type`*: string

  CharacterStyleOverrides* = ref object
    `type`*: string

  TextStyle* = ref object
    fontFamily*: string
    fontPostScriptName*: string
    fontWeight*: float32
    textAutoResize*: string
    fontSize*: float32
    textAlignHorizontal*: string
    textAlignVertical*: string
    letterSpacing*: float32
    lineHeightPx*: float32
    lineHeightPercent*: float32
    lineHeightUnit*: string

  Geometry* = ref object
    path*: string
    windingRule*: string

  Node* = ref object
    id*: string ## A string uniquely identifying this node within the document.
    name*: string ## The name given to the node by the user in the tool.
    visible*: bool ## default true, Whether or not the node is visible on the canvas.
    `type`*: string ## The type of the node, refer to table below for details.
    #pluginData: JsonNode ## Data written by plugins that is visible only to the plugin that wrote it. Requires the `pluginData` to include the ID of the plugin.
    #sharedPluginData: JsonNode ##  Data written by plugins that is visible to all plugins. Requires the `pluginData` parameter to include the string "shared".
    blendMode*: string
    children*: seq[Node]
    prototypeStartNodeID*: string
    prototypeDevice*: Device
    absoluteBoundingBox*: Box
    size: Vec2
    relativeTransform*: seq[seq[float32]]
    constraints*: Constraints
    layoutAlign*: string
    clipsContent*: bool
    background*: seq[Paint]
    fills*: seq[Paint]
    strokes*: seq[Paint]
    strokeWeight*: float32
    strokeAlign*: string
    backgroundColor*: Color
    layoutGrids*: seq[Grid]
    layoutMode*: string
    itemSpacing*: float32
    effects*: seq[Effect]
    isMask*: bool
    cornerRadius*: float32
    rectangleCornerRadii*: seq[float32]
    characters*: string
    style*: TextStyle
    #characterStyleOverrides: seq[CharacterStyleOverrides]
    #styleOverrideTable:
    fillGeometry*: seq[Geometry]
    strokeGeometry*: seq[Geometry]

    # Non figma parameters:
    dirty*: bool     ## Do the pixels need redrawing?
    pixels*: Image   ## Pixel image cache.
    pixelBox*: Rect ## Pixel position and size.
    editable*: bool  ## Can the user edit the text?


  FigmaFile* = ref object
    document*: Node
    components*: Table[string, Component]
    schemaVersion*: int
    name*: string
    lastModified*: string
    thumbnailUrl*: string
    version*: string
    role*: string

var
  figmaFile*: FigmaFile
  figmaFileKey*: string

func xy*(b: Box): Vec2 =
  vec2(b.x, b.y)

func wh*(b: Box): Vec2 =
  vec2(b.width, b.height)

proc downloadImageRef*(fileKey: string) =

  var client = newHttpClient()
  client.headers = newHttpHeaders({"Accept": "*/*"})
  client.headers["User-Agent"] = "curl/7.58.0"
  client.headers["X-FIGMA-TOKEN"] = readFile(getHomeDir() / ".figmakey")

  let data = client.getContent("https://api.figma.com/v1/files/" & fileKey & "/images")
  let json = parseJson(data)
  for imageRef, url in json["meta"]["images"].pairs:
    var client = newHttpClient()
    let data = client.getContent(url.getStr())
    writeFile("images/" & imageRef, data)

proc download(url, filePath: string) =

  var client = newHttpClient()
  client.headers = newHttpHeaders({"Accept": "*/*"})
  client.headers["User-Agent"] = "curl/7.58.0"
  client.headers["X-FIGMA-TOKEN"] = readFile(getHomeDir() / ".figmakey")

  #let url = "https://www.figma.com/file/TQOSRucXGFQpuOpyTkDYj1/Fidget-Mirror-Test?node-id=0%3A1&viewport=952%2C680%2C1"

  figmaFileKey = url.split("/")[4]
  let data = client.getContent("https://api.figma.com/v1/files/" & figmaFileKey & "?geometry=paths")
  let json = parseJson(data)
  writeFile(filePath, pretty(json))

  downloadImageRef(figmaFileKey)

proc parseFigma*(file: JsonNode): FigmaFile =
  if "schemaVersion" in file:
    doAssert file["schemaVersion"].getInt() == 0
  result = file.fromJson(FigmaFile)

  writeFile("generate.json", pretty(%result))


proc use*(url: string) =
  download(url, "import.json")
  figmaFile = parseFigma(parseJson(readFile("import.json")))
