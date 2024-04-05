# krita --new-image RGBA,U8,200,200
set -e

# CAPSULES
# header_capsule: 460x215, png
# small_capsule: 231x87, png
# main_capsule: 616x353, png
# vertical_capsule: 374x448, png
# library_capsule: 600x900, png

# library_header: 460x215, png, same as header capsule
# library_hero: 3840x1240, png, no text
# library_logo: 1280x720, png, only logo text, transparent background


# ICONS
# Community Icon: 184x184, jpg, 1
# Client Image: 16x16, tga, 1
# Client Icon Windows: 32x32, ico, 1
# Client Icon MacOS: 32x32, icns, 1
# Client Icon Linux: 16x16,24x24,32x32,64x64,96x96, zip, 1

# OTHER
# trailer: mp4, 1920x1080 60Hz, 5000+ Kbps
# screenshots: 5 images, 1920x1080, png

if [ "$#" -ne 2 ]; then
    echo Usage: $0 '<source-directory> <output-directory>'
    exit 1
fi

INPUT_DIR=$1
OUTPUT_DIR=$2

rm -rf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR

# capsule images
krita --export --export-filename $OUTPUT_DIR/header_capsule.png $INPUT_DIR/header_capsule.kra
krita --export --export-filename $OUTPUT_DIR/small_capsule.png $INPUT_DIR/small_capsule.kra
krita --export --export-filename $OUTPUT_DIR/main_capsule.png $INPUT_DIR/main_capsule.kra
krita --export --export-filename $OUTPUT_DIR/vertical_capsule.png $INPUT_DIR/vertical_capsule.kra
krita --export --export-filename $OUTPUT_DIR/library_capsule.png $INPUT_DIR/library_capsule.kra

# library images
krita --export --export-filename $OUTPUT_DIR/library_header.png $INPUT_DIR/library_header.kra
krita --export --export-filename $OUTPUT_DIR/library_hero.png $INPUT_DIR/library_hero.kra
krita --export --export-filename $OUTPUT_DIR/library_logo.png $INPUT_DIR/library_logo.kra

# community image
krita --export --export-filename $OUTPUT_DIR/community_icon.png $INPUT_DIR/icon.kra
convert $OUTPUT_DIR/community_icon.png $OUTPUT_DIR/community_icon.jpg

# client images
convert $OUTPUT_DIR/community_icon.png -resize 16x16 $OUTPUT_DIR/client_image.tga
convert $OUTPUT_DIR/community_icon.png -resize 32x32 $OUTPUT_DIR/client_icon_windows.ico
convert $OUTPUT_DIR/community_icon.png -resize 32x32 $OUTPUT_DIR/client_icon_macos.icns
convert $OUTPUT_DIR/community_icon.png -resize 16x16 $OUTPUT_DIR/client_icon_linux_16.png
convert $OUTPUT_DIR/community_icon.png -resize 24x24 $OUTPUT_DIR/client_icon_linux_24.png
convert $OUTPUT_DIR/community_icon.png -resize 32x32 $OUTPUT_DIR/client_icon_linux_32.png
convert $OUTPUT_DIR/community_icon.png -resize 64x64 $OUTPUT_DIR/client_icon_linux_64.png
convert $OUTPUT_DIR/community_icon.png -resize 96x96 $OUTPUT_DIR/client_icon_linux_96.png
zip $OUTPUT_DIR/client_icon_linux.zip $OUTPUT_DIR/client_icon_linux_*.png

# only used temporary
rm $OUTPUT_DIR/client_icon_linux_*.png
rm $OUTPUT_DIR/community_icon.png
