"""ペキニーズの写真からSNS用ショート動画(約60秒・縦型1080x1920)を作成するスクリプト。

使い方:
  1. このスクリプトと同じディレクトリに `photos/` フォルダを作る
  2. 以下のファイル名で5枚の写真を配置する(順番が動画の流れになる):
       photos/01_park.jpg      … 公園の風景(導入の引きの絵)
       photos/02_dog_walk.jpg  … リードを付けて散歩中のワンちゃん
       photos/03_park.jpg      … 公園の風景(中盤の場面転換)
       photos/04_dog_play.jpg  … 元気に動いている瞬間
       photos/05_dog_rest.jpg  … お家でおやすみ(エンディング)
     ※拡張子は .jpg / .jpeg / .png どれでもOK(同名で揃えてください)
  3. 任意:同じディレクトリに `bgm.mp3` を置くとBGMが付きます(無くても動画は作れます)
  4. 仮想環境などで動画用ライブラリを入れる:
       pip install -r requirements-video.txt
  5. 実行:
       python make_pet_video.py
     → `pet_video.mp4` が同じディレクトリに出力されます

設計メモ:
  - SNSショート(TikTok / Reels / YouTube Shorts)の標準である 9:16 縦型で出力
  - 各カット約12秒 × 5カット =  約60秒、カット間は 0.5秒のクロスフェード
  - 各カットに Ken Burns 風のスローズーム/パンを適用して写真でも動きを出す
"""
from __future__ import annotations

from pathlib import Path

# Pillow 10 で削除された ANTIALIAS を参照する moviepy 1.0.3 のための互換シム。
# requirements-video.txt では Pillow<10 に固定しているが、別環境向けの保険。
from PIL import Image as _PILImage
if not hasattr(_PILImage, "ANTIALIAS"):
    _PILImage.ANTIALIAS = _PILImage.Resampling.LANCZOS  # type: ignore[attr-defined]

from moviepy.editor import (
    AudioFileClip,
    ColorClip,
    CompositeVideoClip,
    ImageClip,
    concatenate_videoclips,
)

OUTPUT_SIZE = (1080, 1920)  # 9:16
CLIP_DURATION = 12.0         # 1カット秒数
CROSSFADE = 0.5              # クロスフェード秒数
FPS = 30


def _fit_center_crop(clip: ImageClip, target: tuple[int, int]) -> ImageClip:
    """画像を target サイズに「はみ出した分は中央クロップ」でフィットさせる。"""
    tw, th = target
    cw, ch = clip.size
    if cw / ch > tw / th:
        # 元画像が相対的に横長 → 高さ合わせ → 横をクロップ
        clip = clip.resize(height=th)
        new_w = clip.size[0]
        x = (new_w - tw) / 2
        clip = clip.crop(x1=x, y1=0, x2=x + tw, y2=th)
    else:
        # 元画像が相対的に縦長 → 幅合わせ → 縦をクロップ
        clip = clip.resize(width=tw)
        new_h = clip.size[1]
        y = (new_h - th) / 2
        clip = clip.crop(x1=0, y1=y, x2=tw, y2=y + th)
    return clip


def make_clip(image_path: Path, duration: float, zoom: tuple[float, float]) -> CompositeVideoClip:
    """1枚の写真から、Ken Burns 風スローズームを適用したクリップを返す。"""
    base = ImageClip(str(image_path))
    base = _fit_center_crop(base, OUTPUT_SIZE).set_duration(duration)

    z0, z1 = zoom
    moving = base.resize(lambda t: z0 + (z1 - z0) * (t / duration)).set_position("center")

    # 黒背景に重ねて、ズームしてもフレームサイズが固定されるようにする
    bg = ColorClip(size=OUTPUT_SIZE, color=(0, 0, 0)).set_duration(duration)
    return CompositeVideoClip([bg, moving], size=OUTPUT_SIZE)


def _resolve_photo(photos_dir: Path, stem: str) -> Path:
    for ext in (".jpg", ".jpeg", ".png", ".JPG", ".JPEG", ".PNG"):
        p = photos_dir / f"{stem}{ext}"
        if p.exists():
            return p
    raise FileNotFoundError(
        f"写真が見つかりません: {photos_dir}/{stem}.(jpg|jpeg|png)"
    )


def main() -> None:
    here = Path(__file__).parent
    photos = here / "photos"
    if not photos.is_dir():
        raise FileNotFoundError(f"`photos/` フォルダがありません: {photos}")

    # (ファイル名のstem, (開始ズーム, 終了ズーム))
    storyboard: list[tuple[str, tuple[float, float]]] = [
        ("01_park",     (1.00, 1.15)),  # 公園 — ゆっくり寄る(導入)
        ("02_dog_walk", (1.00, 1.20)),  # ワンちゃん — 顔に寄る
        ("03_park",     (1.15, 1.00)),  # 公園 — 引いて場面転換
        ("04_dog_play", (1.05, 1.25)),  # 元気な瞬間にぐっと寄る
        ("05_dog_rest", (1.20, 1.00)),  # 引きながら余韻
    ]

    clips: list[CompositeVideoClip] = []
    for stem, zoom in storyboard:
        path = _resolve_photo(photos, stem)
        clips.append(make_clip(path, CLIP_DURATION, zoom))

    # カット間にクロスフェード(2枚目以降)
    for i in range(1, len(clips)):
        clips[i] = clips[i].crossfadein(CROSSFADE)

    # 全体の頭と尻にフェード
    clips[0] = clips[0].fadein(0.8)
    clips[-1] = clips[-1].fadeout(1.2)

    video = concatenate_videoclips(clips, method="compose", padding=-CROSSFADE)

    # BGM(任意)
    bgm_path = here / "bgm.mp3"
    if bgm_path.exists():
        bgm = AudioFileClip(str(bgm_path))
        if bgm.duration > video.duration:
            bgm = bgm.subclip(0, video.duration)
        bgm = bgm.audio_fadeout(2.0)
        video = video.set_audio(bgm)

    out = here / "pet_video.mp4"
    video.write_videofile(
        str(out),
        fps=FPS,
        codec="libx264",
        audio_codec="aac",
        bitrate="6000k",
        threads=4,
        preset="medium",
    )
    print(f"完成: {out}  ({video.duration:.1f}秒)")


if __name__ == "__main__":
    main()
