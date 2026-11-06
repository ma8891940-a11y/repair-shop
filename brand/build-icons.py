"""
بيولّد أيقونات التطبيق وأحجام اللوجو من brand/app-logo.png (لوجو صاحب المشروع).

اللوجو نفسه ما بيتعدّلش: لا شكل ولا ألوان ولا نسب. اللي بيحصل بس:
- بنشيل الهامش الشفاف الزيادة حوالين اللوجو (trim).
- بنصغّره بنفس النسبة (LANCZOS).
- بنحطه في نص مربع، بخلفية شفافة أو بلون خلفية التطبيق (للأيقونات اللي لازم ليها خلفية زي maskable).

التشغيل (محتاج Python و Pillow):  python brand/build-icons.py
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'brand' / 'app-logo.png'
DARK = (11, 15, 18, 255)    # --bg في الوضع الداكن (tokens.css)
LIGHT = (238, 243, 249, 255)  # --bg في الوضع الفاتح

logo = Image.open(SRC).convert('RGBA')
logo = logo.crop(logo.getchannel('A').getbbox())


def fit(size, inner, bg=(0, 0, 0, 0)):
    """مربع size×size، واللوجو جوه مساحة inner (من 0 لـ 1) في النص، بنفس نسبته"""
    canvas = Image.new('RGBA', (size, size), bg)
    box = max(1, round(size * inner))
    s = min(box / logo.width, box / logo.height)
    im = logo.resize((max(1, round(logo.width * s)), max(1, round(logo.height * s))), Image.LANCZOS)
    canvas.alpha_composite(im, ((size - im.width) // 2, (size - im.height) // 2))
    return canvas


def width(w):
    s = w / logo.width
    return logo.resize((w, round(logo.height * s)), Image.LANCZOS)


pub = ROOT / 'public'
assets = ROOT / 'src' / 'assets'
assets.mkdir(exist_ok=True)

# جوه التطبيق (الافتتاحية والدخول والشريط الجانبي والمعالج)
width(480).save(assets / 'app-logo.png', optimize=True)
width(160).save(assets / 'app-logo-sm.png', optimize=True)
# اللوجو الثابت اللي بيظهر من أول لحظة قبل ما الكود يحمّل (بيتحط جوه index.html كـ data URI).
# WebP بدون فقد (lossless) عشان الألوان تفضل زي الأصل بالظبط. ارتفاع 300 = ضعف ارتفاع الافتتاحية (150)
h = 300
logo.resize((round(logo.width * h / logo.height), h), Image.LANCZOS).save(assets / 'boot-logo.webp', lossless=True, method=6)

# favicon (خلفية شفافة، اللوجو مالي المربع)
fit(16, 1.0).save(pub / 'favicon-16.png', optimize=True)
fit(32, 1.0).save(pub / 'favicon-32.png', optimize=True)

# PWA: أيقونات عادية بخلفية شفافة
fit(192, 0.9).save(pub / 'icon-192.png', optimize=True)
fit(512, 0.9).save(pub / 'icon-512.png', optimize=True)
# PWA maskable: لازم خلفية كاملة، واللوجو جوه المنطقة الآمنة (دايرة 80%، فبنحطه في 62% عشان أطرافه ما تتقصّش)
fit(192, 0.62, DARK).save(pub / 'icon-maskable-192.png', optimize=True)
fit(512, 0.62, DARK).save(pub / 'icon-maskable-512.png', optimize=True)
# أيفون (ما بيدعمش الشفافية)
fit(180, 0.8, DARK).save(pub / 'apple-touch-icon.png', optimize=True)

# معاينة على الوضعين (نفس اللوجو بالظبط، الخلفية بس هي اللي بتتغير)
fit(1024, 0.86, DARK).save(ROOT / 'brand' / 'app-logo-on-dark.png', optimize=True)
fit(1024, 0.86, LIGHT).save(ROOT / 'brand' / 'app-logo-on-light.png', optimize=True)
print('done')
