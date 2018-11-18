import tables,
 sdl2, sdl2/ttf, algorithm,
 sdl2/gfx, sdl2/image, sdl2/audio, sdl2/mixer,
  sdl2/gamecontroller, sdl2/joystick, vmath, 
 random, strformat, sequtils

# Pigrrl 2 has a 2.8" touch TFT display
# Pigrrl zero has a 2.2" TFT display
const PIGRRL_RES = (x: 320, y: 240)
const RES_MULTIPLE = 2
const WINDOW_RES = (x: PIGRRL_RES.x * RES_MULTIPLE, y: PIGRRL_RES.y * RES_MULTIPLE)

const assets = [
  "splash",
  "bluewin",
  "redwin",
  "rules",
  "red",
  "blue",
  "smile",
  "frown",
  "level",
  "level1",
  "level2",
  "level3",
  "level4",
  "level5",
  "eating1",
  "eating2",
  "eating3",
  "redpill",
  "bluepill",
  "yellowpill",
  "greenpill",
  "pillshadow",
  "blobshadow",
  "frozenbody",
  "smile",
  "smileblink",
  "frown",
  "frownblink",
  "frozenbody"
]

type GameMode = enum play, splash, redwin, bluewin, rules

# SDL globals
var
  window: WindowPtr
  render: RendererPtr
  runGame = true
  fpsman: FpsManager
  scoreFont: FontPtr
  # controllers may be nil if not plugged in
  controller1: GameControllerPtr
  controller2: GameControllerPtr
  surfaceTable = initTable[string, SurfacePtr]()
  textureTable = initTable[string, TexturePtr]()

type GraphicComponent = ref object of RootObj
  name: string
  surf: SurfacePtr
  tex: TexturePtr

proc getWidth*(self: GraphicComponent): int =
  self.surf.w

proc getHeight*(self: GraphicComponent): int =
  self.surf.h

type Renderable = ref object of RootObj
  pos: Vec3

type Bubble = ref object of Renderable
  face: GraphicComponent
  blink: GraphicComponent
  img: GraphicComponent
  shadow: GraphicComponent
  frozenBody: GraphicComponent


  vel: Vec3
  score: int
  speed: float64
  freeze: int
  eating: int
  blinking: int

type Pill = ref object of Renderable
  img: GraphicComponent
  shadow: GraphicComponent

  speed: float64
  freeze: int
  vel: Vec3

# Game globals
var
  red: Bubble
  blue: Bubble
  nLevel = -1
  pills: seq[Pill]
  mode = GameMode.splash
  eating: ptr Chunk
  falling: ptr Chunk
  win: ptr Chunk

const WIN_BY = 5

proc getGraphicComponent(name: string): GraphicComponent =
  new(result)
  result.name = name
  result.surf = surfaceTable[name]
  result.tex = textureTable[name]

proc newBubble(image: string, face: string): Bubble =
  new(result)
  result.img = getGraphicComponent(image)
  result.face = getGraphicComponent(face)
  result.blink = getGraphicComponent(face & "blink")
  result.shadow = getGraphicComponent("blobshadow")
  result.frozenBody = getGraphicComponent("frozenbody")

  result.pos = vec3(0,0,0)
  result.vel = vec3(0,0,0)
  result.score = 0
  result.speed = 0.2
  result.freeze = 0

proc newPill(image: string, freeze: int, speed: float64): Pill =
  new(result)
  result.img = getGraphicComponent(image)
  result.shadow = getGraphicComponent("pillshadow")

  result.freeze = freeze
  result.speed = speed
  result.pos = vec3(0,0,0)
  result.vel = vec3(0,0,0)

proc drawShadow*(self: Bubble, render: RendererPtr) =
  let shadowDst = rect(
    cint(self.pos.x - self.shadow.getWidth / 2),
    cint(self.pos.y + (self.img.getHeight / 3)),
    cint(self.shadow.getWidth),
    cint(self.shadow.getHeight)
    )
  # setTextureAlphaMod(self.shadow.tex, uint8(1 - self.pos[2]/300))
  render.copy(self.shadow.tex, nil, unsafeAddr shadowDst)

proc drawShadow*(self: Pill, render: RendererPtr) =
  let shadowDst = rect(
    cint(self.pos.x - self.shadow.getWidth / 2),
    cint(self.pos.y + (self.img.getHeight / 3)),
    cint(self.shadow.getWidth),
    cint(self.shadow.getHeight)
    )
  # setTextureAlphaMod(self.shadow.tex, uint8(1 - self.pos[2]/300))
  render.copy(self.shadow.tex, nil, unsafeAddr shadowDst)

method draw*(self: Renderable, render: RendererPtr) {.base.} =
  discard

method draw*(self: Bubble, render: RendererPtr) =

  let x = cint(self.pos.x - self.img.getWidth / 2)
  let y = cint(self.pos.y - self.img.getHeight / 2 - self.pos.z)
  let dst = rect(x,y,cint(self.img.getWidth),cint(self.img.getHeight))
  render.copy(self.img.tex, nil, unsafeAddr dst)

  if self.freeze > 0:
    setTextureAlphaMod(self.frozenBody.tex, 200)
    render.copy(self.frozenBody.tex, nil, unsafeAddr dst)

  var face = self.face
  if (rand(1.0) < 0.005):
    self.blinking = 10
  if (self.blinking > 0):
    self.blinking -= 1
    face = self.blink
  if (self.eating > 0):
    self.eating -= 1
    var eating = int((self.eating.toFloat / (40.0 / 3.0)) mod 2) + 1
    face = getGraphicComponent(&"eating{eating}")

  render.copy(face.tex, nil, unsafeAddr dst)
  # TODO draw shadow
  # TODO draw frozen alpha if frozen

method draw*(self: Pill, render: RendererPtr) =
  let x = cint(self.pos.x - self.img.getWidth / 2)
  let y = cint(self.pos.y - self.img.getHeight / 2 - self.pos.z)
  let dst = rect(x,y,cint(self.img.getWidth),cint(self.img.getHeight))
  render.copy(self.img.tex, nil, unsafeAddr dst)

  # TODO draw shadow at correct location
  # render.copy(self.shadow.tex, nil, unsafeAddr dst)

proc loadSurface(name: string): SurfacePtr =
  let filename = &"./{name}.png"
  echo "loading " & filename
  result = load(filename)


proc loadTextures() =
  echo "loading textures"
  for asset in assets:
    let surf = loadSurface(asset)
    surfaceTable[asset] = surf
    textureTable[asset] = createTextureFromSurface(render, surf)

proc drawText(text: string, dst: Vec2, render: RendererPtr) =
  var scoreColor: Color
  scoreColor.r = 255
  scoreColor.g = 255
  scoreColor.b = 255
  scoreColor.a = 0

  var textSurf = renderTextSolid(scoreFont, text, scoreColor)
  var textTex = createTextureFromSurface(render, textSurf)

  let scoreDst = rect(
    cint(dst.x),
    cint(dst.y),
    cint(textSurf.w),
    cint(textSurf.h)
  )

  render.copy(textTex, nil, unsafeAddr scoreDst)
  freeSurface(textSurf)
  destroyTexture(textTex)

proc init() =
  echo "\n"
  # setup SDL
  discard sdl2.init(INIT_EVERYTHING)
  # let sdlFlags = SDL_WINDOW_SHOWN or SDL_WINDOW_RESIZABLE
  let sdlFlags = SDL_WINDOW_SHOWN
  window = createWindow("Bubbleats", 100, 100, cint(WINDOW_RES.x) ,cint(WINDOW_RES.y), sdlFlags)
  render = createRenderer(window, -1, Renderer_Accelerated or Renderer_PresentVsync or Renderer_TargetTexture)
  fpsman.init

  loadTextures()
  
  discard openAudio(48000, AUDIO_F32, 2, 4096)
  discard ttfInit()

  scoreFont = openFont("./Apercu-Bold.otf", 28)
  if scoreFont == nil:
    raise newException(Exception, "failed to load font")

  eating = loadWAV("./eat.wav")  
  falling = loadWAV("./falling.wav")
  win = loadWAV("./win.wav")

  let music = loadMUS("./Ace of Clubs.ogg")
  discard playMusic(music, 0)

  # TODO setup joysticks
  let joystickCount = numJoysticks();
  echo &"found {joystickCount} joysticks!"
  if joystickCount > 0:
    controller1 = gameControllerOpen(0);
  if joystickCount > 1:
    controller2 = gameControllerOpen(1);


  # TODO implement keyboard controls
  #if controller1 == nil:
  #  echo "Player 1 controls: WASD to move, Q to jump"
  #if controller2 == nil:
  #  echo "Player 2 controls: arrows to move, / to jump"

  echo "Space is Start (new game)"
  echo "Tab is Select (show rules)"
    

proc startMatch() =
  echo "Starting Match"
  mode = GameMode.play
  red = newBubble("red", "smile")
  blue = newBubble("blue", "frown")
  pills = @[]
  red.pos = vec3(100, WINDOW_RES.y / 2, 0)
  blue.pos = vec3(WINDOW_RES.x - 100, WINDOW_RES.y / 2, 0)
  nLevel += 1

proc handleInput(bubble: Bubble, controller: GameControllerPtr) =
  var xAxis = 0.0
  var yAxis = 0.0
  var jump = 0.0
  var blink = false
  if controller != nil:
    xAxis = getAxis(controller, SDL_CONTROLLER_AXIS_LEFTX) / 32767
    yAxis = getAxis(controller, SDL_CONTROLLER_AXIS_LEFTY) / 32767
    if getButton(controller, SDL_CONTROLLER_BUTTON_DPAD_LEFT) != 0:
      xAxis = -1
    if getButton(controller, SDL_CONTROLLER_BUTTON_DPAD_RIGHT) != 0:
      xAxis = 1
    if getButton(controller, SDL_CONTROLLER_BUTTON_DPAD_DOWN) != 0:
      yAxis = 1
    if getButton(controller, SDL_CONTROLLER_BUTTON_DPAD_UP) != 0:
      yAxis = -1

    if getButton(controller, SDL_CONTROLLER_BUTTON_A) != 0:
      jump = 7.0

    if getButton(controller, SDL_CONTROLLER_BUTTON_B) != 0:
      blink = true

    # TODO keyboard controls
  

  bubble.vel[0] += xAxis * bubble.speed
  bubble.vel[1] += yAxis * bubble.speed
  if bubble.pos[2] == 0:
    bubble.vel[2] *= 5
    bubble.vel[2] += jump

  if blink:
    bubble.blinking = 2

proc handlePhysics(b: Bubble) =
  if b.freeze > 0:
    b.vel *= 0
    b.freeze -= 1
  else:
    b.pos += b.vel
  if b.speed < 0.05:
    b.speed = 0.05

  if b.pos[0] < 50:
    b.pos[0] = 50
  if b.pos[0] > WINDOW_RES.x - 50:
    b.pos[0] = WINDOW_RES.x - 50

  if b.pos[1] < 50:
    b.pos[1] = 50
  if b.pos[1] > WINDOW_RES.y - 50:
    b.pos[1] = WINDOW_RES.y - 50

  if b.pos[2] > 0:
    b.vel[2] -= 0.4
  if b.pos[2] < 0:
    b.pos[2] = 0
    b.vel[2] = 0

  b.pos += b.vel * 3
  b.vel *= 0.9

  var toRemove: seq[Natural]
  for i in 0..<pills.len:
    let p = pills[i]
    if (p.pos - b.pos).length < 30:
      b.score += 1
      b.speed += p.speed
      b.freeze += p.freeze
      b.eating = 40
      toRemove.add(i)
      discard playChannelTimed(cint(-1), eating, 1, - 1)

  for i in toRemove:
    pills.del(i)

proc handlePhysics(p: Pill) =
  if p.pos[2] > 0:
    p.vel[2] -= 0.4
  if p.pos[2] < 0:
    p.pos[2] = 0
    p.vel[2] = 0

  p.pos += p.vel * 2
  p.vel *= 0.9

proc gameLoop() =
  var evt = sdl2.defaultEvent
  
  while runGame:
    while pollEvent(evt):
      case(evt.kind):
        of QuitEvent:
          runGame = false
        of KeyDown:
          if evt.key.keysym.sym == K_ESCAPE:
            runGame = false
        of WindowEvent:
          case evt.window.event:
            of WindowEvent_Resized:
              echo "resized"
              # TODO need to handle resizing gracefully
            else: discard
        else:
          discard
        

    let dt = fpsman.getFramerate() / 1000

    var start = false;
    var select = false;

    # handle input
    var keyCount = 0;
    let state = getKeyboardState(addr keyCount)

    if state[uint8(SDL_SCANCODE_SPACE)] == 1 or
      (controller1 != nil and getButton(controller1, SDL_CONTROLLER_BUTTON_START) != 0) or
      (controller2 != nil and getButton(controller2, SDL_CONTROLLER_BUTTON_START) != 0):
      start = true;
    if state[uint8(SDL_SCANCODE_TAB)] == 1 or
      (controller1 != nil and getButton(controller1, SDL_CONTROLLER_BUTTON_BACK) != 0) or
      (controller2 != nil and getButton(controller2, SDL_CONTROLLER_BUTTON_BACK) != 0):
      select = true;

    # handle game mode changes
    if start and mode != GameMode.play:
      startmatch()
    if select and mode != Gamemode.play:
      mode = GameMode.rules

    render.setDrawColor 0,0,0,255
    render.clear
    
    if red != nil and blue != nil:
      if red.score > blue.score + WIN_BY:
        mode = GameMode.redwin
        discard playChannelTimed(cint(-1), win, 1, - 1)
      if blue.score > red.score + WIN_BY:
        mode = GameMode.bluewin
        discard playChannelTimed(cint(-1), win, 1, - 1)

    case mode:
      of GameMode.play:

        handleInput(blue, controller1)
        handleInput(red, controller2)

        handlePhysics(blue)
        handlePhysics(red)
        for pill in pills:
          handlePhysics(pill)

        if rand(1.0) < 0.01 and pills.len < 3:
          let choice = rand(3)
          var pill: Pill
          case choice:
            of 0:
              pill = newPill("redpill", 0, 0.03)
            of 1:
              pill = newPill("bluepill", 60, 0.0)
            of 2:
              pill = newPill("yellowpill", 0, 0.0)
            of 3:
              pill = newPill("greenpill", 0, -0.03)
            else: discard
          if pill != nil:
            pill.pos[0] = 50 + rand(float(WINDOW_RES.x) - 100)
            pill.pos[1] = 100 + rand(float(WINDOW_RES.y) - 140)
            pill.pos[2] = 500
            discard playChannelTimed(cint(-1), falling, 1, - 1)
            pills.add(pill)

        let diff = red.pos - blue.pos
        if diff.length() < 100:
          if diff.length() < 60:
            let overlap = 60 - diff.length()
            let push = diff / diff.length() * overlap
            if red.vel.length() > -0.1 and blue.vel.length() < -0.1:
              blue.pos -= push
            elif red.vel.length() < 0.1 and blue.vel.length() > 0.1:
              red.pos += push
            else:
              red.pos += push / 2
              blue.pos -= push / 2

          red.vel[0] = red.vel[0]*0.5 + blue.vel[0]*0.5
          blue.vel[0] = blue.vel[0]*0.5 + red.vel[0]*0.5
  
          red.vel[1] = red.vel[1]*0.5 + blue.vel[1]*0.5
          blue.vel[1] = blue.vel[1]*0.5 + red.vel[1]*0.5


        # game mode rendering
        render.copy(textureTable[&"level{(nLevel mod 5) + 1}"], nil, nil)

        red.drawShadow(render)
        blue.drawShadow(render)

        for pill in pills:
          pill.drawShadow(render)

        let bubbles = @[blue, red]
        var things: seq[Renderable] = @[]
        things.add(blue)
        things.add(red)
        for pill in pills:
          things.add(pill)
        
        things.sort do (x, y: Renderable) -> int:
          result = int(x.pos.y - y.pos.y)
        
        for thing in things:
          thing.draw(render)

        # draw scores
        drawText( &"{red.score}", vec2(10,10), render)
        drawText( &"{blue.score}", vec2(WINDOW_RES.y - 10,10), render)


      of GameMode.splash:
        render.copy(textureTable["splash"], nil, nil)
      of GameMode.rules:
        render.copy(textureTable["rules"], nil, nil)
      of GameMode.redwin:
        render.copy(textureTable["redwin"], nil, nil)
      of GameMode.bluewin:
        render.copy(textureTable["bluewin"], nil, nil)
      else: discard

    render.present
    fpsman.delay

  destroy render
  destroy window

init()
gameLoop()