fullScreen = True

import os, sys
import random
import pygame
from pygame.math import Vector2, Vector3
from pygame.locals import *
import time

WIN_BY = 10

mode = "splash"

pygame.init()

pygame.mixer.music.load('Ace of Clubs.ogg')
pygame.mixer.music.play(5)
pygame.mixer.music.set_volume(.5)

eat_sound = pygame.mixer.Sound("eat.wav")
pillfall_sound = pygame.mixer.Sound("falling.wav")

pygame.display.set_caption("Bubble Eats")
flags = HWSURFACE or DOUBLEBUF

WIDTH = 480 * 2
HEIGHT = 320 * 2

if fullScreen:
    flags = FULLSCREEN
    infoObject = pygame.display.Info()
    real_screen = pygame.display.set_mode((infoObject.current_w, infoObject.current_h), flags)
    screen = pygame.Surface((WIDTH, HEIGHT)).convert()
else:
    flags = RESIZABLE
    real_screen = pygame.display.set_mode((WIDTH, HEIGHT), flags)
    screen = pygame.Surface((WIDTH, HEIGHT)).convert()

splash = pygame.image.load("splash.png")
bluewin = pygame.image.load("bluewin.png")
redwin = pygame.image.load("redwin.png")
rules = pygame.image.load("rules.png")


smile = pygame.image.load("smile.png")
frown = pygame.image.load("frown.png")
eating = [
    pygame.image.load("eating1.png"),
    pygame.image.load("eating2.png"),
    pygame.image.load("eating3.png")
]

class Bubble:
    def __init__(self, image, face):
        self.face = pygame.image.load(face+".png")
        self.blink = pygame.image.load(face+"blink.png")
        self.shadow = pygame.image.load("blobshadow.png")
        self.frozenbody = pygame.image.load("frozenbody.png")

        self.img = pygame.image.load(image)

        self.pos = Vector3(0,0,0)
        self.vel = Vector3(0,0,0)
        self.score = 0
        self.speed = 0.4
        self.freeze = 0
        self.eating = 0
        self.blinking = 0

    def draw(self):
        x = self.pos[0]-self.img.get_width()/2
        y = self.pos[1]-self.img.get_height() - self.pos[2]
        blit_flip(
            screen,
            self.img,
            (x, y),
            self.vel[0] < 0
        )
        face = self.face
        if random.random() < 0.005:
            self.blinking = 10
        if self.blinking > 0:
            self.blinking -= 1
            face = self.blink
        if self.eating > 0:
            self.eating -= 1
            face = eating[(self.eating/(40/3))%2]

        blit_flip(
            screen,
            face,
            (x, y),
            self.vel[0] < 0
        )

        if self.freeze > 0:
            blit_alpha(
                screen,
                self.frozenbody,
                (x, y),
                0.5
            )

class Pill:
    def __init__(self, image, speed=0, freeze=0):
        self.speed = speed
        self.freeze = freeze
        self.shadow = pygame.image.load("pillshadow.png")
        self.img = pygame.image.load(image)
        self.pos = Vector3(0,0,0)
        self.vel = Vector3(0,0,0)

    def draw(self):
        screen.blit(
            self.img,
            (
                self.pos[0]-self.img.get_width()/2,
                self.pos[1]-self.img.get_height() - self.pos[2]
            ),
        )


levels = []
for i in range(1,6):
    levels.append(pygame.image.load("level%i.png" % i).convert())
nlevel = 0
level = levels[0]

red = Bubble("red.png", "smile")
blue = Bubble("blue.png", "frown")

red.pos = Vector3(100,HEIGHT/2,0)
blue.pos = Vector3(WIDTH-100,HEIGHT/2,0)
red.vel = Vector3(0,0,0)
blue.vel = Vector3(0,0,0)

bubbles = [red, blue]
pills = []

font = pygame.font.Font("Apercu-Bold.otf", 40)
#font = pygame.font.SysFont("monospace", 20)

pygame.joystick.init()

joysticks = [pygame.joystick.Joystick(x) for x in range(pygame.joystick.get_count())]
for joystick in joysticks:
    joystick.init()


start_time = time.time()

blitcache = {}

def blit_alpha(target, source, location, opacity):
    now = time.time()

    key = ('a', source, opacity)
    x = location[0]
    y = location[1]
    tmp = pygame.Surface((source.get_width(), source.get_height())).convert()
    tmp.blit(target, (-x, -y))
    tmp.blit(source, (0, 0))
    tmp.set_alpha(opacity*255)
    target.blit(tmp, location)

    print "blit_alpha flip", (time.time() - now)*1000

def blit_flip(target, source, location, flip):
    now = time.time()

    key = ('f', source, flip)
    tmp = pygame.Surface((source.get_width(), source.get_height()), pygame.SRCALPHA, 32)
    tmp = tmp.convert_alpha()
    tmp.convert_alpha()
    tmp.blit(source, (0, 0))
    tmp = pygame.transform.flip(tmp, flip, False)
    target.blit(tmp, location)

    print "blit_flip flip", (time.time() - now)*1000


while True:

    now = time.time()

    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            sys.exit()
        elif event.type == KEYDOWN:
            if event.key == K_ESCAPE:
                pygame.quit()
                sys.exit()
        elif event.type == VIDEORESIZE:
            if not fullScreen:
                surface = pygame.display.set_mode(
                    (event.w, event.h),
                    pygame.RESIZABLE)

    start = False
    select = False
    for b, j in zip(bubbles, joysticks):
        b.vel[0] += j.get_axis(0) * b.speed
        b.vel[1] += j.get_axis(1) * b.speed
        if j.get_button(0) and b.pos[2] == 0:
            b.vel[2] = 10
        if j.get_button(1):
            b.blinking = 2
        if j.get_button(9):
            start = True
        if j.get_button(8):
            select = True

    keys = pygame.key.get_pressed()

    if (keys[K_SPACE] or start) and mode != "play":
        red.pos = Vector3(100,HEIGHT/2,0)
        blue.pos = Vector3(WIDTH-100,HEIGHT/2,0)
        red.vel = Vector3(0,0,0)
        blue.vel = Vector3(0,0,0)
        pills = []
        red.score = 0
        blue.score = 0
        red.speed = 0.2
        blue.speed = 0.2
        red.freeze = 0
        blue.freeze = 0
        if mode != "splash":
            nlevel += 1
        level = levels[nlevel%len(levels)]
        mode = "play"
        print "play!"
        pygame.mixer.music.load('Ace of Clubs.ogg')
        pygame.mixer.music.play(5)

    if keys[K_LEFT]:
        blue.vel[0] -= blue.speed
    if keys[K_RIGHT]:
        blue.vel[0] += blue.speed
    if keys[K_UP]:
        blue.vel[1] -= blue.speed
    if keys[K_DOWN]:
        blue.vel[1] += blue.speed
    if keys[K_SLASH] and blue.pos[2] == 0:
        blue.vel[2] = 10

    if keys[K_a]:
        red.vel[0] -= red.speed
    if keys[K_d]:
        red.vel[0] += red.speed
    if keys[K_w]:
        red.vel[1] -= red.speed
    if keys[K_s]:
        red.vel[1] += red.speed
    if keys[K_q] and red.pos[2] == 0:
        red.vel[2] = 10

    nowf = time.time()
    screen.blit(level, (0,0))
    print "frame blit", (time.time() - nowf)*1000

    for b in bubbles:
        if b.freeze:
            b.vel *= 0
            b.freeze -= 1
        else:
            b.pos += b.vel

        if b.speed < .05:
            b.speed = .05

        pos = b.pos
        if pos[0] < 50:
            pos[0] = 50
        if pos[0] > WIDTH - 50:
            pos[0] = WIDTH - 50
        if pos[1] < 100:
            pos[1] = 100
        if pos[1] > HEIGHT - 40:
            pos[1] = HEIGHT - 40

        for p in list(pills):
            if (p.pos - b.pos).length() < 30:
                b.score += 1
                b.speed += p.speed
                b.freeze += p.freeze
                b.eating = 40
                pills.remove(p)
                eat_sound.play()

    if random.random() < .01 and len(pills) < 3 and mode == "play":
        p = random.choice([
            Pill("redpill.png", speed=0.03),
            Pill("bluepill.png", freeze=60),
            Pill("yellowpill.png"),
            Pill("greenpill.png", speed=-0.03)
        ])

        if p:
            p.pos[0] = random.randint(50, WIDTH-50)
            p.pos[1] = random.randint(100, HEIGHT-40)
            p.pos[2] = 500
            pillfall_sound.play()
            pills.append(p)

    things = pills + bubbles
    things.sort(key=lambda (b): b.pos[1])

    if mode == "play":
        for p in things:
            blit_alpha(
                screen,
                p.shadow,
                (
                    p.pos[0]-p.shadow.get_width()/2,
                    p.pos[1]-p.shadow.get_height()+2
                ),
                1 - p.pos[2]/300
            )
        for p in things:
            p.draw()
            if p.pos[2] > 0:
                p.vel[2] -= .4
            if p.pos[2] < 0:
                p.pos[2] = 0
                p.vel[2] = 0
            p.pos += p.vel
            p.vel *= 0.9

    diff = red.pos - blue.pos
    if diff.length() < 100:
        if diff.length() < 60:
            overlap = 60 - diff.length()
            push = diff / diff.length() * overlap
            if red.vel.length() > .1 and blue.vel.length() < .1:
                blue.pos -= push
            elif red.vel.length() < .1 and blue.vel.length() > .1:
                red.pos += push
            else:
                red.pos += push / 2
                blue.pos -= push / 2

        red.vel[0] = red.vel[0]*.5 + blue.vel[0]*.5
        blue.vel[0] = blue.vel[0]*.5 + red.vel[0]*.5

        red.vel[1] = red.vel[1]*.5 + blue.vel[1]*.5
        blue.vel[1] = blue.vel[1]*.5 + red.vel[1]*.5

    if mode == "play":
        # render text
        label = font.render(str(red.score), 1, (255,255,255))
        screen.blit(label, (10, 0))

        label = font.render(str(blue.score), 1, (255,255,255))
        screen.blit(label, (WIDTH-10-label.get_width(), 0))

        label = font.render("Round %i"%(nlevel+1), 1, (255,255,255))
        screen.blit(label, (WIDTH/2-label.get_width()/2, 0))

        if red.score > blue.score + WIN_BY:
            mode = "redwin"
            pygame.mixer.music.load('win.wav')
            pygame.mixer.music.play()

        if blue.score > red.score + WIN_BY:
            mode = "bluewin"
            pygame.mixer.music.load('win.wav')
            pygame.mixer.music.play()

    if mode == "splash":
        screen.blit(splash, (0,0))

    if mode == "redwin":
        screen.blit(redwin, (0,0))

    if mode == "bluewin":
        screen.blit(bluewin, (0,0))

    if select and mode == "splash":
        mode = "rules"

    if mode == "rules":
        if start:
            mode = "splash"
        screen.blit(rules, (0,0))

    if real_screen:
        a = float(WIDTH)/HEIGHT
        scaleFactorX = float(real_screen.get_width())/WIDTH
        scaleFactorY = float(real_screen.get_height())/HEIGHT
        if scaleFactorX < scaleFactorY:
            x = WIDTH*scaleFactorX
            y = HEIGHT*scaleFactorX
            tmp = pygame.transform.scale(screen, (int(x), int(y)))
            real_screen.blit(tmp, (0, real_screen.get_height()/2 - int(y)/2))
            #real_screen.blit(tmp, (0, 0))
        else:
            x = WIDTH*scaleFactorY
            y = HEIGHT*scaleFactorY
            tmp = pygame.transform.scale(screen, (int(x), int(y)))
            real_screen.blit(tmp, (real_screen.get_width()/2 - int(x)/2, 0))
            #real_screen.blit(tmp, (0, 0))

    print "frame stuff", (time.time() - now)*1000

    now = time.time()
    pygame.display.flip()
    print "frame flip", (time.time() - now)*1000
