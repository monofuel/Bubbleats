import tables, sdl2, sdl2/gfx, sdl2/image, sdl2/gamecontroller, sdl2/joystick, vmath, random, strformat

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

type Bubble = ref object of RootObj
  face: GraphicComponent
  blink: GraphicComponent
  img: GraphicComponent

  pos: Vec3
  vel: Vec3
  score: int
  speed: float64
  freeze: int
  eating: int
  blinking: int

# Game globals
var
  red: Bubble
  blue: Bubble
  nLevel = 0
  mode = GameMode.splash


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
  result.pos = vec3(0,0,0)
  result.vel = vec3(0,0,0)
  result.score = 0
  result.speed = 0.2
  result.freeze = 0


proc draw*(self: Bubble, render: RendererPtr) =
  let x = cint(self.pos.x - self.img.getWidth / 2)
  let y = cint(self.pos.y - self.img.getHeight / 2 - self.pos.z)
  let dst = rect(x,y,cint(self.img.getWidth),cint(self.img.getHeight))
  render.copy(self.img.tex, nil, unsafeAddr dst)

  var face = self.face
  if (rand(1.0) < 0.005):
    self.blinking = 10
  if (self.blinking > 0):
    self.blinking -= 1
    face = self.blink
  if (self.eating > 0):
    self.eating -= 1
    var eating = (self.eating.toFloat / (40.0 / 3.0)) mod 2
    face = getGraphicComponent("eating{eating}")

  render.copy(face.tex, nil, unsafeAddr dst)

  # TODO draw frozen alpha if frozen



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

  # TODO setup joysticks
  let joystickCount = numJoysticks();
  echo &"found {joystickCount} joysticks!"
  if joystickCount > 0:
    controller1 = gameControllerOpen(0);
  if joystickCount > 1:
    controller2 = gameControllerOpen(1);

  if controller1 == nil:
    echo "Player 1 controls: WASD to move, Q to jump"
  if controller2 == nil:
    echo "Player 2 controls: arrows to move, / to jump"

  echo "Space is Start (new game)"
  echo "Tab is Select (show rules)"
    

proc startMatch() =
  echo "Starting Match"
  mode = GameMode.play
  red = newBubble("red", "smile")
  blue = newBubble("blue", "frown")
  red.pos = vec3(100, WINDOW_RES.y / 2, 0)
  blue.pos = vec3(WINDOW_RES.x - 100, WINDOW_RES.y / 2, 0)
  nLevel += 1

proc handleInput(bubble: Bubble, controller: GameControllerPtr) =
  var xAxis = 0.0
  var yAxis = 0.0
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

    # TODO keyboard controls
  echo &"xAxis: {xAxis}, yAxis: {yAxis}"
  bubble.vel[0] += xAxis * bubble.speed
  bubble.vel[1] += yAxis * bubble.speed

  # TODO jumping
  # TODO blink button

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

  b.pos += b.vel * 2
  b.vel *= 0.9

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

    case mode:
      of GameMode.play:

        handleInput(blue, controller1)
        handleInput(red, controller2)

        handlePhysics(blue)
        handlePhysics(red)

        # TODO bubbles

        # game mode rendering
        render.copy(textureTable["level1"], nil, nil)

        blue.draw(render)
        red.draw(render)
      of GameMode.splash:
        render.copy(textureTable["splash"], nil, nil)
      of GameMode.rules:
        render.copy(textureTable["rules"], nil, nil)
      else: discard

    render.present
    fpsman.delay

  destroy render
  destroy window

init()
gameLoop()