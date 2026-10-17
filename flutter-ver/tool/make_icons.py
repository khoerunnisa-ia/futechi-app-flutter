from PIL import Image
import os

root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = Image.open(os.path.join(root, "assets", "images", "icon_chatbot.jpeg")).convert("RGBA")
master = src.resize((1024, 1024), Image.LANCZOS)
master.save(os.path.join(root, "assets", "images", "icon_master.png"))

sizes = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
for d, s in sizes.items():
    p = os.path.join(root, "android", "app", "src", "main", "res", f"mipmap-{d}", "ic_launcher.png")
    master.resize((s, s), Image.LANCZOS).save(p)

for s in (192, 512):
    master.resize((s, s), Image.LANCZOS).save(os.path.join(root, "web", "icons", f"Icon-{s}.png"))
    master.resize((s, s), Image.LANCZOS).save(os.path.join(root, "web", "icons", f"Icon-maskable-{s}.png"))
master.resize((64, 64), Image.LANCZOS).save(os.path.join(root, "web", "favicon.png"))

ico_sizes = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
master.save(os.path.join(root, "windows", "runner", "resources", "app_icon.ico"), sizes=ico_sizes)
print("done")
