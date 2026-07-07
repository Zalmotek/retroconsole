#!/usr/bin/env python3
"""RetroConsole system architecture diagram → article/architecture.png"""
from PIL import Image, ImageDraw, ImageFont

S = 2  # supersample scale
W, H = 1400, 785

TEAL = "#00878F"
TEAL_SOFT = "#7FB8BD"
FILL_LIGHT = "#EAF6F7"
FILL_CHIP = "#DFF0F1"
ORANGE = "#E47128"
ORANGE_FILL = "#FDF0E7"
TXT = "#12333A"
SUB = "#54696F"
ARROW = "#3A4A52"

img = Image.new("RGB", (W * S, H * S), "white")
d = ImageDraw.Draw(img)

FD = "/usr/share/fonts/truetype/dejavu/"
def font(sz, bold=False):
    return ImageFont.truetype(FD + ("DejaVuSans-Bold.ttf" if bold else "DejaVuSans.ttf"), sz * S)

F_TITLE = font(21, True)
F_BOX = font(15, True)
F_SUB = font(12)
F_LBL = font(12, True)
F_SMALL = font(11)

def rbox(x0, y0, x1, y1, fill, outline, w=2, r=10):
    d.rounded_rectangle([x0 * S, y0 * S, x1 * S, y1 * S], radius=r * S,
                        fill=fill, outline=outline, width=w * S)

def text_c(cx, y, s, f, color):
    """centered text, returns baseline-advance"""
    bb = d.textbbox((0, 0), s, font=f)
    d.text((cx * S - (bb[2] - bb[0]) / 2, y * S), s, font=f, fill=color)

def text_l(x, y, s, f, color):
    d.text((x * S, y * S), s, font=f, fill=color)

def arrow(pts, label=None, lbl_pos=None, color=ARROW, w=2, lbl_color=None, lbl_font=None):
    """polyline with arrowhead at the end. pts = [(x,y), ...]"""
    sp = [(x * S, y * S) for x, y in pts]
    d.line(sp, fill=color, width=w * S)
    # arrowhead
    (x1, y1), (x2, y2) = sp[-2], sp[-1]
    import math
    ang = math.atan2(y2 - y1, x2 - x1)
    L = 9 * S
    for a in (ang + 2.6, ang - 2.6):
        pass
    p1 = (x2 - L * math.cos(ang - 0.45), y2 - L * math.sin(ang - 0.45))
    p2 = (x2 - L * math.cos(ang + 0.45), y2 - L * math.sin(ang + 0.45))
    d.polygon([sp[-1], p1, p2], fill=color)
    if label:
        lx, ly = lbl_pos
        text_l(lx, ly, label, lbl_font or F_LBL, lbl_color or TEAL)

def dbl_arrow(x0, x1, y, w=2, color=ARROW):
    import math
    sp0, sp1 = (x0 * S, y * S), (x1 * S, y * S)
    d.line([sp0, sp1], fill=color, width=w * S)
    L = 9 * S
    for (tip, ang) in ((sp1, 0.0), (sp0, math.pi)):
        p1 = (tip[0] - L * math.cos(ang - 0.45), tip[1] - L * math.sin(ang - 0.45))
        p2 = (tip[0] - L * math.cos(ang + 0.45), tip[1] - L * math.sin(ang + 0.45))
        d.polygon([tip, p1, p2], fill=color)

# ---------- title ----------
text_l(40, 24, "RetroConsole — System Architecture", F_TITLE, TXT)

# ---------- battery ----------
rbox(40, 340, 250, 440, ORANGE_FILL, ORANGE)
text_c(145, 362, "Battery / UPS", F_BOX, TXT)
text_c(145, 388, "Waveshare UPS Module 3S", F_SMALL, SUB)
text_c(145, 408, "3\u00d7 18650 \u00b7 USB-C", F_SMALL, SUB)
arrow([(250, 390), (280, 390)], label="5 V", lbl_pos=(252, 362), lbl_color=ORANGE)

# ---------- UNO Q outer ----------
rbox(280, 70, 900, 560, FILL_LIGHT, TEAL, 3, 14)
text_l(304, 88, "ARDUINO UNO Q", F_BOX, TEAL)

# MCU
rbox(320, 260, 550, 520, "white", TEAL)
text_c(435, 286, "STM32U585", F_BOX, TXT)
text_c(435, 310, "microcontroller (MCU)", F_SUB, SUB)
text_c(435, 356, "Arduino sketch", F_SUB, TXT)
text_c(435, 380, "polls Modulinos", F_SUB, TXT)
text_c(435, 404, "60 Hz over I2C", F_SUB, TXT)

# MPU
rbox(640, 150, 870, 520, "white", TEAL)
text_c(755, 172, "QRB2210 (MPU)", F_BOX, TXT)
text_c(755, 196, "Debian Linux", F_SUB, SUB)
for (y0, y1, t1, t2) in ((240, 296, "gamepad_daemon.py", None),
                          (330, 386, "uinput", "virtual gamepad"),
                          (420, 476, "RetroArch", "emulator")):
    rbox(658, y0, 852, y1, FILL_CHIP, TEAL_SOFT)
    if t2:
        text_c(755, y0 + 8, t1, F_BOX, TXT)
        text_c(755, y0 + 32, t2, F_SMALL, SUB)
    else:
        text_c(755, y0 + 18, t1, F_BOX, TXT)
arrow([(755, 296), (755, 330)])
arrow([(755, 386), (755, 420)])

# Bridge between MCU and MPU
dbl_arrow(550, 640, 390)
text_c(595, 352, "Bridge", F_LBL, TEAL)
text_c(595, 408, "MsgPack", F_SMALL, SUB)
text_c(595, 426, "RPC", F_SMALL, SUB)

# ---------- Media Carrier ----------
rbox(960, 70, 1360, 200, "white", TEAL)
text_c(1160, 100, "UNO MEDIA CARRIER", F_BOX, TXT)
text_c(1160, 128, "DSI + 3.5 mm audio breakout", F_SUB, SUB)
text_c(1160, 152, "stacks on the UNO Q", F_SMALL, SUB)
# board-to-board connector
d.line([(900 * S, 135 * S), (960 * S, 135 * S)], fill=TEAL, width=5 * S)
text_c(930, 105, "JMEDIA", F_SMALL, TEAL)
text_c(930, 150, "JMISC", F_SMALL, TEAL)

# ---------- Display ----------
rbox(960, 255, 1240, 375, "white", TEAL)
text_c(1100, 283, "8″ DSI Touchscreen", F_BOX, TXT)
text_c(1100, 311, "Waveshare Touch A", F_SUB, SUB)
text_c(1100, 333, "800 × 1280 IPS", F_SUB, SUB)
arrow([(1060, 200), (1060, 255)], label="DSI (FPC)", lbl_pos=(1072, 218))

# ---------- Speakers ----------
rbox(960, 425, 1240, 515, "white", TEAL)
text_c(1100, 450, "Speakers /", F_BOX, TXT)
text_c(1100, 472, "Headphones", F_BOX, TXT)
arrow([(1300, 200), (1300, 470), (1240, 470)])
text_l(1310, 300, "3.5 mm", F_SMALL, TEAL)
text_l(1310, 318, "audio", F_SMALL, TEAL)

# ---------- Qwiic chain ----------
chain = [
    ("Modulino Joystick", "0x2C · D-pad + L1", 280),
    ("Modulino Buttons #1", "0x3E · A / B", 566),
    ("Modulino Buttons #2", "0x3F · X / Y", 852),
    ("Modulino Buttons #3", "0x40 · Start / Select", 1138),
]
CY0, CY1 = 640, 740
for i, (t, sub, x0) in enumerate(chain):
    rbox(x0, CY0, x0 + 250, CY1, "white", TEAL)
    text_c(x0 + 125, CY0 + 22, t, F_BOX, TXT)
    text_c(x0 + 125, CY0 + 52, sub, F_SUB, SUB)
    if i:
        arrow([(x0 - 36, 690), (x0, 690)])

# MCU → joystick drop line
arrow([(420, 520), (420, 640)], label="Qwiic (I2C)", lbl_pos=(432, 588))

img = img.resize((W, H), Image.LANCZOS)
import os
img.save(os.path.join(os.path.dirname(os.path.abspath(__file__)), "architecture.png"))
print("saved")
