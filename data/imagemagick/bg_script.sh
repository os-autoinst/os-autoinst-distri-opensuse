#!/bin/bash

# This script contains all the executed commands as part of the
# ImageMagick test in openQA.

# Alias for a specific repeated sequence of commands.
# cme: (c)onvert (m)ogrify (e)og
function cme {
    convert "$1" -resize 200x200 "$2"
    mogrify -extent 200x200 -gravity Center -fill white "$2"
    eog "$2"
    rm "$2"
}

convert --version

wget --quiet "${1/bg_script.sh/test.png}"            -O test.png
cme test.png 1.png

wget --quiet "${1/bg_script.sh/shape.gif}"           -O shape.gif
cme shape.gif 2.gif

wget --quiet "${1/bg_script.sh/plasma_fractal2.jpg}" -O plasma_fractal2.jpg
cme plasma_fractal2.jpg 3.jpg

wget --quiet "${1/bg_script.sh/random.png}"          -O random.png
cme random.png 4.png

wget --quiet "${1/bg_script.sh/tile_weave.gif}"      -O tile_weave.gif
cme tile_weave.gif 5.gif

wget --quiet "${1/bg_script.sh/bg.gif}"              -O bg.gif
cme bg.gif 6.gif

wget --quiet "${1/bg_script.sh/tile_aqua.jpg}"       -O tile_aqua.jpg
cme tile_aqua.jpg 7.jpg

wget --quiet "${1/bg_script.sh/tile_water.jpg}"      -O tile_water.jpg
cme tile_water.jpg 8.jpg

wget --quiet "${1/bg_script.sh/tile_rings.jpg}"      -O tile_rings.jpg
cme tile_rings.jpg 9.jpg

wget --quiet "${1/bg_script.sh/tile_disks.jpg}"      -O tile_disks.jpg
cme tile_disks.jpg 10.jpg

wget --quiet "${1/bg_script.sh/tree.gif}"            -O tree.gif
cme tree.gif 11.gif

echo "canvas_khaki.gif"
convert -size 100x100 canvas:khaki  canvas_khaki.gif
cme canvas_khaki.gif 12.gif

echo "canvas_salmon.gif"
convert 'xc:Salmon[100x100!]'  canvas_salmon.gif
cme canvas_salmon.gif 13.gif

echo "canvas_wheat.gif"
convert -size 100x100 xc:wheat  canvas_wheat.gif
cme canvas_wheat.gif 14.gif

echo "color_sparse.gif"
convert test.png  -alpha Off  -sparse-color Voronoi '0,0 Peru' color_sparse.gif
cme color_sparse.gif 15.gif

echo "color_reset.gif"
convert test.png -fill Tan -draw 'color 0,0 reset' color_reset.gif
cme color_reset.gif 16.gif

echo "color_flatten.gif"
convert test.png   -background Wheat  -compose Dst   -flatten   color_flatten.gif
cme color_flatten.gif 17.gif

echo "color_extent.gif"
convert test.png   -background LemonChiffon  -compose Dst   -extent 100x100   color_extent.gif
cme color_extent.gif 18.gif

echo "color_border.gif"
convert test.png   -bordercolor Khaki  -compose Dst   -border 0   color_border.gif
cme color_border.gif 19.gif

echo "color_fx_constant.gif"
convert test.png -alpha off -fx Gold  color_fx_constant.gif
cme color_fx_constant.gif 20.gif

echo "color_semitrans.png"
convert test.png -alpha set -fill '#FF000040' -draw 'color 0,0 reset'  color_semitrans.png
cme color_semitrans.png 21.png

echo "color_pick_fx.png"
convert rose: -fx 'p{0,0}'  color_pick_fx.png
cme color_pick_fx.png 22.png

echo "color_pick_sparse.png"
convert rose: -sparse-color voronoi '0,0 %[pixel:p{40,30}]' color_pick_sparse.png
cme color_pick_sparse.png 23.png

echo "color_pick_draw.png"
convert rose: \( +clone -crop 1x1+64+22 -write MPR:pixel +delete \)  -fill mpr:pixel  -draw 'color 0,0 reset'  color_pick_draw.png
cme color_pick_draw.png 24.png

echo "color_pick_distort.png"
convert rose: -set option:distort:viewport '%wx%h+0+0'  -crop 1x1+10+25 +repage     -distort SRT 0  color_pick_distort.png
cme color_pick_distort.png 25.png

echo "black_threshold.png"
convert  test.png -threshold 100% -alpha off  black_threshold.png
cme black_threshold.png 26.png

echo "white_threshold.png"
convert  test.png  -threshold -1 -alpha off   white_threshold.png
cme white_threshold.png 27.png

echo "black_level.png"
convert  test.png -level 100%,100% -alpha off  black_level.png
cme black_level.png 28.png

echo "white_level.png"
convert  test.png -level -1,-1 -alpha off  white_level.png
cme white_level.png 29.png

echo "black_fx.png"
convert test.png  -fx 0 -alpha off   black_fx.png
cme black_fx.png 30.png

echo "white_fx.png"
convert test.png -fx 1.0 -alpha off  white_fx.png
cme white_fx.png 31.png

echo "black_evaluate.png"
convert  test.png  -evaluate set 0  -alpha off  black_evaluate.png
cme black_evaluate.png 32.png

echo "white_evaluate.png"
convert  test.png  -evaluate set 100%  -alpha off  white_evaluate.png
cme white_evaluate.png 33.png

echo "black_gamma.png"
convert  test.png  -gamma 0  -alpha off  black_gamma.png
cme black_gamma.png 34.png

echo "white_posterize.png"
convert  test.png -posterize 1 -alpha off -negate  white_posterize.png
cme white_posterize.png 35.png

echo "black_posterize.png"
convert  test.png  -posterize 1 -alpha off black_posterize.png
cme black_posterize.png 36.png

echo "white_alpha.png"
convert test.png  -alpha opaque -alpha extract  white_alpha.png
cme white_alpha.png 37.png

echo "black_alpha.png"
convert test.png  -alpha transparent -alpha extract  black_alpha.png
cme black_alpha.png 38.png

echo "trans_fx.png"
convert test.png -alpha set -channel A -fx 0 +channel  trans_fx.png
cme trans_fx.png 39.png

echo "trans_fx_alpha_off.jpg"
convert  trans_fx.png -alpha off  trans_fx_alpha_off.jpg
cme trans_fx_alpha_off.jpg 40.jpg

echo "trans_compose.png"
convert test.png  null: -alpha set -compose Clear -composite -compose Over  trans_compose.png
cme trans_compose.png 41.png

echo "yellow_gamma.png"
convert  test.png -channel red -gamma -1 -channel green -gamma -1 -channel blue -gamma 0 -alpha off yellow_gamma.png
cme yellow_gamma.png 42.png

echo "color_matte.png"
if grep -q 'VERSION=\"15' /etc/os-release ; then
    convert test.png -alpha set -fill none -draw 'alpha 0,0 reset' color_matte.png
else
    convert test.png -alpha set -fill none -draw 'matte 0,0 reset' color_matte.png
fi
cme color_matte.png 43.png

echo "grey_level.png"
convert  test.png  +level 40%,40%  -alpha off  grey_level.png
cme grey_level.png 44.png

echo "trans_alpha.png"
convert test.png  -alpha transparent trans_alpha.png
cme trans_alpha.png 45.png

echo "gradient.jpg"
convert  -size 100x100 gradient:  gradient.jpg
cme gradient.jpg 46.jpg

echo "trans_evaluate.png"
convert test.png  -alpha set -channel A -evaluate set 0 +channel  trans_evaluate.png
cme trans_evaluate.png 47.png

echo "gradient_range1.jpg"
convert -size 100x100  gradient:blue              gradient_range1.jpg
cme gradient_range1.jpg 48.jpg

echo "trans_threshold.png"
if grep -q 'VERSION=\"15' /etc/os-release ; then
    convert test.png -channel A -threshold 100% +channel trans_threshold.png
else
    convert test.png -channel A -threshold -1 +channel trans_threshold.png
fi
cme trans_threshold.png 49.png

echo "gradient_range2.jpg"
convert -size 100x100  gradient:yellow            gradient_range2.jpg
cme gradient_range2.jpg 50.jpg

echo "gradient_range3.jpg"
convert -size 100x100  gradient:green-yellow      gradient_range3.jpg
cme gradient_range3.jpg 51.jpg

echo "gradient_ice-sea.jpg"
convert -size 10x120  gradient:snow-navy          gradient_ice-sea.jpg
cme gradient_ice-sea.jpg 52.jpg

echo "gradient_range4.jpg"
convert -size 100x100  gradient:red-blue          gradient_range4.jpg
cme gradient_range4.jpg 53.jpg

echo "gradient_burnished.jpg"
convert -size 10x120  gradient:gold-firebrick     gradient_burnished.jpg
cme gradient_burnished.jpg 54.jpg

echo "gradient_range5.jpg"
convert -size 100x100  gradient:tomato-steelblue  gradient_range5.jpg
cme gradient_range5.jpg 55.jpg

echo "gradient_grassland.jpg"
convert -size 10x120  gradient:yellow-limegreen   gradient_grassland.jpg
cme gradient_grassland.jpg 56.jpg

echo "gradient_snow_scape.jpg"
convert -size 10x120  gradient:darkcyan-snow      gradient_snow_scape.jpg
cme gradient_snow_scape.jpg 57.jpg

echo "rgradient.jpg"
convert -size 100x100 radial-gradient:  rgradient.jpg
cme rgradient.jpg 58.jpg

echo "gradient_sunset.jpg"
convert -size 10x120  gradient:khaki-tomato       gradient_sunset.jpg
cme gradient_sunset.jpg 59.jpg

echo "rgradient_clip.jpg"
convert -size 100x60 radial-gradient:  rgradient_clip.jpg
cme rgradient_clip.jpg 60.jpg

echo "rgradient_crop.jpg"
convert -size 100x142 radial-gradient:  -gravity center -crop 100x100+0+0 rgradient_crop.jpg
cme rgradient_crop.jpg 61.jpg

echo "rgradient_range1.jpg"
convert -size 100x100  radial-gradient:blue              rgradient_range1.jpg
cme rgradient_range1.jpg 62.jpg

echo "rgradient_range2.jpg"
convert -size 100x100  radial-gradient:yellow            rgradient_range2.jpg
cme rgradient_range2.jpg 63.jpg

echo "rgradient_range3.jpg"
convert -size 100x100  radial-gradient:green-yellow      rgradient_range3.jpg
cme rgradient_range3.jpg 64.jpg

echo "rgradient_range4.jpg"
convert -size 100x100  radial-gradient:red-blue          rgradient_range4.jpg
cme rgradient_range4.jpg 65.jpg

echo "gradient_transparent.png"
convert -size 100x100 gradient:none-firebrick gradient_transparent.png
cme gradient_transparent.png 66.png

echo "gradient_sigmoidal.jpg"
convert -size 100x100 gradient: -sigmoidal-contrast 6,50%  gradient_sigmoidal.jpg
cme gradient_sigmoidal.jpg 67.jpg

echo "gradient_trans_colorize.png"
convert -size 100x100 gradient:none-black  -fill firebrick -colorize 100% gradient_trans_colorize.png
cme gradient_trans_colorize.png 68.png

echo "gradient_cosine.jpg"
convert -size 100x100 gradient: -evaluate cos 0.5 -negate  gradient_cosine.jpg
cme gradient_cosine.jpg 69.jpg

echo "gradient_peak.jpg"
convert -size 100x100 gradient: -function Polynomial -4,4,0  gradient_peak.jpg
cme gradient_peak.jpg 70.jpg

echo "gradient_bands.jpg"
convert -size 100x100 gradient: -function sinusoid 4,-90   gradient_bands.jpg
cme gradient_bands.jpg 71.jpg

echo "gradient_diagonal.jpg"
convert -size 142x142 gradient: -rotate -45  -gravity center -crop 100x100+0+0 +repage  gradient_diagonal.jpg
cme gradient_diagonal.jpg 72.jpg

echo "gradient_srt.jpg"
convert -size 100x100 gradient: -distort SRT 60 gradient_srt.jpg
cme gradient_srt.jpg 73.jpg

echo "gradient_swirl.jpg"
convert -size 100x100 gradient: -swirl 180 gradient_swirl.jpg
cme gradient_swirl.jpg 74.jpg

echo "gradient_trapezoid.jpg"
convert -size 100x100 gradient: -rotate -90  -distort Perspective '0,0 40,0  99,0 59,0  0,99 -10,99 99,99 109,99'  gradient_trapezoid.jpg
cme gradient_trapezoid.jpg 75.jpg

echo "gradient_arc.jpg"
convert -size 100x100 gradient: -distort Arc '180 0 50 0'  gradient_arc.jpg
cme gradient_arc.jpg 76.jpg

echo "gradient_circle.jpg"
convert -size 100x100 gradient: -distort Arc '360 0 50 0'  gradient_circle.jpg
cme gradient_circle.jpg 77.jpg

echo "gradient_angle_even.png"
convert -size 1x1000 gradient: -rotate 90  -distort Arc '360 -90 50 0' +repage  -gravity center -crop 76x76+0+0 +repage  gradient_angle_even.png
cme gradient_angle_even.png 78.png

echo "gradient_angle_masked.png"
convert -size 50x1000 gradient: -rotate 90 -alpha set  -virtual-pixel Transparent +distort Polar 49 +repage  -transverse  gradient_angle_masked.png
cme gradient_angle_masked.png 79.png

echo "gradient_angle_odd.png"
convert -size 1x1000 gradient: -rotate 90  +distort Polar '36.5,0,.5,.5' +repage  -transverse  gradient_angle_odd.png
cme gradient_angle_odd.png 80.png

echo "gradient_triangle.jpg"
convert -size 100x100 radial-gradient:  -background black -wave -28x200 -crop 100x100+0+0 +repage  gradient_triangle.jpg
cme gradient_triangle.jpg 81.jpg

echo "gradient_bird.jpg"
convert -size 100x100 radial-gradient:  +distort Polar '49' +repage  gradient_bird.jpg
cme gradient_bird.jpg 82.jpg

echo "gradient_venetian.jpg"
convert -size 100x100 gradient: \( +clone +clone \)  -background gray50 -compose ModulusAdd -flatten  gradient_venetian.jpg
cme gradient_venetian.jpg 83.jpg

echo "gradient_vent_diag.jpg"
convert -size 100x100 gradient: \( gradient: -rotate -90 \)  \( -clone 0--1 -clone 0--1 \)  -background gray50 -compose ModulusAdd -flatten  gradient_vent_diag.jpg
cme gradient_vent_diag.jpg 84.jpg

echo "gradient_colormap.jpg"
convert -size 100x100 gradient:yellow-blue  \( gradient:black-lime -rotate -90 \)  -compose CopyGreen -composite  gradient_colormap.jpg
cme gradient_colormap.jpg 85.jpg

echo "gradient_rainbow.jpg"
convert -size 30x600 xc:red -colorspace HSB  gradient: -compose CopyRed -composite  -colorspace RGB -rotate 90  gradient_rainbow.jpg
cme gradient_rainbow.jpg 86.jpg

echo "gradient_hue_polar.png"
convert -size 100x300 gradient:'#FFF-#0FF' -rotate 90  -alpha set -virtual-pixel Transparent +distort Polar 49 +repage  -rotate 90 -set colorspace HSB -colorspace RGB  gradient_hue_polar.png
cme gradient_hue_polar.png 87.png

echo "gradient_rainbow_2.jpg"
convert -size 30x600 gradient:'#FFF-#0FF' -rotate 90  -set colorspace HSB -colorspace RGB  gradient_rainbow_2.jpg
cme gradient_rainbow_2.jpg 88.jpg

echo "gradient_resize.jpg"
echo "P1 1 2   0  1 " |  convert - -resize 100x100\!   gradient_resize.jpg
cme gradient_resize.jpg 89.jpg

echo "gradient_resize2.jpg"
convert -size 1x2  gradient:khaki-tomato  -resize 100x100\!   gradient_resize2.jpg
cme gradient_resize2.jpg 90.jpg

echo "gradient_resize3.jpg"
echo "P2 2 2 2   2 1 1 0 " |  convert - -resize 100x100\!   gradient_resize3.jpg
cme gradient_resize3.jpg 91.jpg

echo "gradient_resize4.jpg"
convert \( xc:red xc:blue +append \)  \( xc:yellow xc:cyan +append \) -append  -filter triangle -resize 100x100\!   gradient_resize4.jpg
cme gradient_resize4.jpg 92.jpg

echo "gradient_resize5.jpg"
convert -size 1x2  gradient:  -filter Cubic  -resize 100x100\!    gradient_resize5.jpg
cme gradient_resize5.jpg 93.jpg

echo "gradient_rs_rainbow.jpg"
convert xc:black xc:red xc:yellow xc:green1 xc:cyan xc:blue xc:black  +append -filter Cubic -resize 600x30\! gradient_rs_rainbow.jpg
cme gradient_rs_rainbow.jpg 94.jpg

echo "gradient_interpolated.jpg"
convert -size 600x30 xc:   \( +size xc:gold xc:firebrick +append \)   -fx 'v.p{i/(w-1),0}'    gradient_interpolated.jpg
cme gradient_interpolated.jpg 95.jpg

echo "gradient_clut.jpg"
convert -size 30x600 gradient: -rotate 90  -interpolate Catrom  \( +size xc:black xc:tomato xc:wheat +append \) -clut  gradient_clut.jpg
cme gradient_clut.jpg 96.jpg

echo "gradient_clut_recolored.jpg"
convert -size 30x600 gradient: -rotate 90  \( +size xc:gold xc:firebrick +append \) -clut  gradient_clut_recolored.jpg
cme gradient_clut_recolored.jpg 97.jpg

echo "gradient_bilinear.jpg"
convert \( xc:red xc:blue +append \)  \( xc:yellow xc:cyan +append \) -append  -size 100x100 xc: +swap  -fx 'v.p{i/(w-1),j/(h-1)}'  gradient_bilinear.jpg
cme gradient_bilinear.jpg 98.jpg

echo "gradient_mesh.jpg"
convert \( xc:red xc:gold +append \)  \( xc:gold xc:green +append \) -append  -filter point -interpolate mesh  -define distort:viewport=100x100  -distort Affine '.5,.5 .5,.5   1.5,1.5 99.5,99.5'  gradient_mesh.jpg
cme gradient_mesh.jpg 99.jpg

echo "gradient_catrom.jpg"
convert \( xc:red xc:blue +append \)  \( xc:yellow xc:cyan +append \) -append  -filter point -interpolate catrom  -define distort:viewport=100x100  -distort Affine '.5,.5 .5,.5   1.5,1.5 99.5,99.5'  gradient_catrom.jpg
cme gradient_catrom.jpg 100.jpg

echo "gradient_fx_linear.gif"
convert  rose:  -channel G -fx 'i/w' -separate   gradient_fx_linear.gif
cme gradient_fx_linear.gif 101.gif

echo "gradient_fx_x4.gif"
convert  rose:  -channel G -fx '(i/w)^4' -separate   gradient_fx_x4.gif
cme gradient_fx_x4.gif 102.gif

echo "gradient_fx_cos.gif"
convert  rose:  -channel G -fx 'cos(pi*(i/w-.5))'  -separate   gradient_fx_cos.gif
cme gradient_fx_cos.gif 103.gif

echo "gradient_fx_radial.gif"
convert -size 100x100 xc: -channel G  -fx 'rr=hypot(i/w-.5, j/h-.5); 1-rr*1.42'  -separate gradient_fx_radial.gif
cme gradient_fx_radial.gif 104.gif

echo "gradient_fx_spherical.gif"
convert -size 100x100 xc: -channel G  -fx 'xx=i/w-.5; yy=j/h-.5; rr=xx*xx+yy*yy; 1-rr*4'  -separate gradient_fx_spherical.gif
cme gradient_fx_spherical.gif 105.gif

echo "gradient_fx_quad2.gif"
convert -size 100x100 xc: -channel G  -fx '(1-(2*i/w-1)^4)*(1-(2*j/h-1)^4)'  -separate  gradient_fx_quad2.gif
cme gradient_fx_quad2.gif 106.gif

echo "gradient_fx_angular.gif"
convert -size 100x100 xc:  -channel G  -fx '.5 - atan2(j-h/2,w/2-i)/pi/2'  -separate  gradient_fx_angular.gif
cme gradient_fx_angular.gif 107.gif

echo "gradient_inverse_alt.gif"
convert -size 100x100 xc:  -sparse-color  Inverse '50,10 red  10,70 yellow  90,90 lime'  gradient_inverse_alt.gif
cme gradient_inverse_alt.gif 108.gif

echo "gradient_shepards_alt.gif"
convert -size 100x100 xc:  -sparse-color  Shepards '50,10 red  10,70 yellow  90,90 lime'  gradient_shepards_alt.gif
cme gradient_shepards_alt.gif 109.gif

echo "gradient_inverse_RGB.png"
convert -size 100x100 xc:  -sparse-color  Inverse '50,10 red  10,70 blue  90,90 lime'  gradient_inverse_RGB.png
cme gradient_inverse_RGB.png 110.png

echo "gradient_inverse_RGB_Hue.gif"
convert gradient_inverse_RGB.png -colorspace HSB  -channel GB -evaluate set 100% +channel  -colorspace RGB gradient_inverse_RGB_Hue.gif
cme gradient_inverse_RGB_Hue.gif 111.gif

echo "sparse_bary_triangle.png"
convert -size 100x100 xc:  -sparse-color Barycentric '30,10 red   10,80 blue   90,90 lime'  \( -size 100x100 xc:black -fill white  -draw 'polygon 30,10  10,80  90,90' \)  -alpha Off -compose CopyOpacity -composite  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82  circle 90,90 90,92'  sparse_bary_triangle.png
cme sparse_bary_triangle.png 112.png

echo "sparse_barycentric.png"
convert -size 100x100 xc: -sparse-color  Barycentric  '30,10 red   10,80 blue   90,90 lime'  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82  circle 90,90 90,92'  sparse_barycentric.png
cme sparse_barycentric.png 113.png

echo "sparse_bary_triangle_2.png"
if grep -q 'VERSION=\"15' /etc/os-release ; then
    convert -channel RGB -size 100x100 xc:none -draw "polygon 30,10  10,80  90,90" -sparse-color Barycentric '30,10 red   10,80 blue   90,90 lime'  sparse_bary_triangle_2.png
else
    convert -size 100x100 xc:none -draw "polygon 30,10  10,80  90,90"  -sparse-color Barycentric '30,10 red   10,80 blue   90,90 lime'  sparse_bary_triangle_2.png
fi
cme sparse_bary_triangle_2.png 114.png

echo "sparse_bary_0.gif"
convert sparse_barycentric.png -separate sparse_bary_%d.gif
cme sparse_bary_0.gif 115.gif

echo "sparse_bary_gradient.png"
convert -size 100x100 xc: -sparse-color  Barycentric  '30,10 red   10,80 red   90,90 lime'  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82  circle 90,90 90,92'  sparse_bary_gradient.png
cme sparse_bary_gradient.png 116.png

echo "sparse_bary_gradient_2.png"
convert -size 100x100 xc: -sparse-color  Barycentric  '50,70 red   10,80 red   90,90 lime'  -fill white -stroke black  -draw 'circle 50,70 50,72  circle 10,80 10,82  circle 90,90 90,92'  sparse_bary_gradient_2.png
cme sparse_bary_gradient_2.png 117.png

echo "diagonal_gradient.jpg"
convert -size 600x60 xc: -sparse-color barycentric  '0,0 skyblue  -%w,%h skyblue  %w,%h black' diagonal_gradient.jpg
cme diagonal_gradient.jpg 118.jpg

echo "sparse_bary_two_point.png"
convert -size 100x100 xc: -sparse-color  Barycentric  '30,10 red     90,90 lime'  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 90,90 90,92'  sparse_bary_two_point.png
cme sparse_bary_two_point.png 119.png

echo "diagonal_gradient_2.jpg"
convert -size 600x60 xc: -sparse-color barycentric  '0,%h black  -%w,0 black  %w,0 skyblue' diagonal_gradient_2.jpg
cme diagonal_gradient_2.jpg 120.jpg

echo "sparse_bilinear.png"
convert -size 100x100 xc: -sparse-color  Bilinear  '30,10 red  10,80 blue  70,60 lime  80,20 yellow'  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_bilinear.png
cme sparse_bilinear.png 121.png

echo "sparse_bilin_0.gif"
convert sparse_bilinear.png -separate sparse_bilin_%d.gif
cme sparse_bilin_0.gif 122.gif

echo "sparse_voronoi.gif"
convert -size 100x100 xc: -sparse-color  Voronoi  '30,10 red  10,80 blue  70,60 lime  80,20 yellow'  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_voronoi.gif
cme sparse_voronoi.gif 123.gif

echo "gradient_scale.png"
convert  -size 1x5 gradient:  -scale 2000% gradient_scale.png
cme gradient_scale.png 124.png

echo "sparse_voronoi_ssampled.png"
convert -size 400x400 xc: -sparse-color  Voronoi  '120,40 red  40,320 blue  270,240 lime  320,80 yellow'  -scale 25%        -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_voronoi_ssampled.png
cme sparse_voronoi_ssampled.png 125.png

echo "gradient_math.png"
convert -size 1x5 xc:  -sparse-color Barycentric '0,-0.5 white  0,%[fx:h-.5] black'  -scale 2000%  gradient_math.png
cme gradient_math.png 126.png

echo "sparse_voronoi_smoothed.png"
convert -size 100x100 xc: -sparse-color  Voronoi  '30,10 red  10,80 blue  70,60 lime  80,20 yellow'  -blur 1x0.7    -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_voronoi_smoothed.png
cme sparse_voronoi_smoothed.png 127.png

echo "gradient_equiv.png"
convert -size 1x5 xc:  -sparse-color Barycentric '0,0 white  0,%[fx:h-1] black'  -scale 2000%  gradient_equiv.png
cme gradient_equiv.png 128.png

echo "sparse_voronoi_blur.png"
convert -size 100x100 xc: -sparse-color  Voronoi  '30,10 red  10,80 blue  70,60 lime  80,20 yellow'  -blur 0x15    -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_voronoi_blur.png
cme sparse_voronoi_blur.png 129.png

echo "gradient_shifted.png"
convert -size 1x5 xc:  -sparse-color Barycentric '0,0 white  0,%h black'  -scale 2000%  gradient_shifted.png
cme gradient_shifted.png 130.png

echo "sparse_voronoi_gradient.png"
convert -size 100x100 xc: -sparse-color  Voronoi  '30,10 red  10,80 blue  70,60 lime  80,20 yellow'  -blur 10x65535      -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_voronoi_gradient.png
cme sparse_voronoi_gradient.png 131.png

echo "gradient_chopped.png"
convert -size 1x6 gradient: -chop 0x1 -scale 2000%  gradient_chopped.png
cme gradient_chopped.png 132.png

echo "sparse_shepards.png"
convert -size 100x100 xc: -sparse-color  Shepards  '30,10 red  10,80 blue  70,60 lime  80,20 yellow'  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_shepards.png
cme sparse_shepards.png 133.png

echo "sparse_inverse.png"
convert -size 100x100 xc: -sparse-color  Inverse  '30,10 red  10,80 blue  70,60 lime  80,20 yellow'  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_inverse.png
cme sparse_inverse.png 134.png

echo "sparse_shepards_0.5.png"
convert -size 100x100 xc: -define shepards:power=0.5  -sparse-color Shepards '30,10 red  10,80 blue  70,60 lime  80,20 yellow'  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_shepards_0.5.png
cme sparse_shepards_0.5.png 135.png

echo "sparse_shepards_1.png"
convert -size 100x100 xc: -define shepards:power=1  -sparse-color Shepards '30,10 red  10,80 blue  70,60 lime  80,20 yellow'  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_shepards_1.png
cme sparse_shepards_1.png 136.png

echo "sparse_shepards_2.png"
convert -size 100x100 xc: -define shepards:power=2  -sparse-color Shepards '30,10 red  10,80 blue  70,60 lime  80,20 yellow'  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_shepards_2.png
cme sparse_shepards_2.png 137.png

echo "plasma_smooth.jpg"
convert plasma_fractal2.jpg  -blur 0x2  plasma_smooth.jpg
cme plasma_smooth.jpg 138.jpg

echo "sparse_shepards_3.png"
convert -size 100x100 xc: -define shepards:power=3  -sparse-color Shepards '30,10 red  10,80 blue  70,60 lime  80,20 yellow'  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_shepards_3.png
cme sparse_shepards_3.png 139.png

echo "sparse_shepards_8.png"
convert -size 100x100 xc: -define shepards:power=8  -sparse-color Shepards '30,10 red  10,80 blue  70,60 lime  80,20 yellow'  -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_shepards_8.png
cme sparse_shepards_8.png 140.png

echo "sparse_shepards_gray.gif"
convert -size 100x100 xc: -channel G -sparse-color Shepards  '30,10 gray70  10,80 black  70,60 white  80,20 gray(33.3333%)'  -separate +channel    -fill white -stroke black  -draw 'circle 30,10 30,12  circle 10,80 10,82'  -draw 'circle 70,60 70,62  circle 80,20 80,22'  sparse_shepards_gray.gif
cme sparse_shepards_gray.gif 141.gif

echo "rose_alpha_gradient.png"
convert rose: -alpha set -channel A  -sparse-color Barycentric  '0,0 opaque   %w,-%h opaque    %w,%h transparent'  rose_alpha_gradient.png
cme rose_alpha_gradient.png 142.png

echo "sparse_source.gif"
convert -size 100x100 xc:none +antialias -fill none -strokewidth 0.5  -stroke Gold        -draw "path 'M 20,70  A 1,1 0 0,1 80,50'"  -stroke DodgerBlue  -draw "line 30,10  50,80"  -stroke Red         -draw "circle 80,60  82,60"  sparse_source.gif
cme sparse_source.gif 143.gif

echo "sparse_fill.png"
convert sparse_source.gif txt:- | sed '1d; / 0) /d; s/:.* /,/;' | convert sparse_source.gif -alpha off  -sparse-color shepards '' sparse_fill.png
cme sparse_fill.png 144.png

echo "shape_edge_pixels.gif"
convert shape.gif -channel A -morphology EdgeIn Diamond shape_edge_pixels.gif
cme shape_edge_pixels.gif 145.gif

echo "shape_edge_in_lights.png"
convert shape_edge_pixels.gif txt:- | sed '1d; / 0) /d; s/:.* /,/;' |  convert shape_edge_pixels.gif -alpha off  -sparse-color shepards '' shape_edge_in_lights.png
cme shape_edge_in_lights.png 146.png

echo "shape_in_lights.png"
convert shape_edge_in_lights.png shape.gif -composite shape_in_lights.png
cme shape_in_lights.png 147.png

echo "sparse_blur_simple.png"
convert sparse_source.gif   -channel RGBA -blur 0x15  -alpha off  sparse_blur_simple.png
cme sparse_blur_simple.png 148.png

echo "sparse_blur_pyramid.png"
convert sparse_source.gif  \( +clone -resize 50% \)  \( +clone -resize 50% \)  \( +clone -resize 50% \)  \( +clone -resize 50% \)  \( +clone -resize 50% \)  \( +clone -resize 50% \)  \( +clone -resize 50% \)  -layers RemoveDups -filter Gaussian -resize 100x100\! -reverse  -background None -flatten -alpha off    sparse_blur_pyramid.png
cme sparse_blur_pyramid.png 149.png

echo "sparse_lines_near_source.gif"
convert -size 100x100 xc:none +antialias -fill none -strokewidth 0.5  -stroke Red    -draw "path 'M 26,0  A 55,61 0 0,1 26,100'"  -stroke White  -draw "line 50,0  50,100"  sparse_lines_near_source.gif
cme sparse_lines_near_source.gif 150.gif

echo "sparse_lines_near.png"
convert sparse_lines_near_source.gif txt:- | sed '1d; / 0) /d; s/:.* /,/;' | convert -size 100x100 xc: -sparse-color shepards ''  sparse_lines_near.png
cme sparse_lines_near.png 151.png

echo "plasma_paint.jpg"
convert plasma_fractal2.jpg  -blur 0x1 -paint 8  plasma_paint.jpg
cme plasma_paint.jpg 152.jpg

echo "plasma_emboss.jpg"
if grep -q 'VERSION=\"15' /etc/os-release ; then
    convert plasma_fractal2.jpg -channel RGB -blur 0x5 -emboss 2 plasma_emboss.jpg
else
    convert plasma_fractal2.jpg -blur 0x5 -emboss 2 plasma_emboss.jpg
fi
cme plasma_emboss.jpg 153.jpg

echo "plasma_sharp.jpg"
convert plasma_fractal2.jpg  -blur 0x5 -sharpen 0x15 plasma_sharp.jpg
cme plasma_sharp.jpg 154.jpg

echo "plasma_seeded.jpg"
convert -size 100x100 -seed 4321  plasma:    plasma_seeded.jpg
cme plasma_seeded.jpg 155.jpg

echo "plasma_rnd1.jpg"
convert -size 100x100 -seed 4321 plasma:grey-grey         plasma_rnd1.jpg
cme plasma_rnd1.jpg 156.jpg

echo "plasma_rnd2.jpg"
convert -size 100x100 -seed 4321 plasma:white-blue        plasma_rnd2.jpg
cme plasma_rnd2.jpg 157.jpg

echo "plasma_rnd3.jpg"
convert -size 100x100 -seed 4321 plasma:green-yellow      plasma_rnd3.jpg
cme plasma_rnd3.jpg 158.jpg

echo "plasma_rnd4.jpg"
convert -size 100x100 -seed 4321 plasma:red-blue          plasma_rnd4.jpg
cme plasma_rnd4.jpg 159.jpg

echo "plasma_rnd5.jpg"
convert -size 100x100 -seed 4321 plasma:tomato-steelblue  plasma_rnd5.jpg
cme plasma_rnd5.jpg 160.jpg

echo "random_mask.png"
convert random.png  -channel G -threshold 5% -separate  +channel -negate    random_mask.png
cme random_mask.png 161.png

echo "random_black.png"
convert random.png   -channel G -threshold 5% -negate  -channel RG -separate +channel  -compose Multiply    -composite   random_black.png
cme random_black.png 162.png

echo "random_white.png"
convert random.png   -channel G -threshold 5%  -channel RG -separate +channel  -compose Screen      -composite   random_white.png
cme random_white.png 163.png

echo "random_1.png"
convert random.png -virtual-pixel tile  -blur 0x1  -auto-level  random_1.png
cme random_1.png 164.png

echo "random_trans.png"
convert random.png   -channel G -threshold 5% -negate  -channel RG -separate +channel  -compose CopyOpacity -composite   random_trans.png
cme random_trans.png 165.png

echo "random_3.png"
convert random.png -virtual-pixel tile  -blur 0x3  -auto-level  random_3.png
cme random_3.png 166.png

echo "random_5.png"
convert random.png -virtual-pixel tile  -blur 0x5  -auto-level  random_5.png
cme random_5.png 167.png

echo "random_10.png"
convert random.png -virtual-pixel tile  -blur 0x10 -auto-level  random_10.png
cme random_10.png 168.png

echo "random_20.png"
convert random.png -virtual-pixel tile  -blur 0x20 -auto-level  random_20.png
cme random_20.png 169.png

echo "random_0_gray.png"
convert random.png     -channel G  -separate   random_0_gray.png
cme random_0_gray.png 170.png

echo "random_1_gray.png"
convert random_1.png   -channel G  -separate   random_1_gray.png
cme random_1_gray.png 171.png

echo "random_3_gray.png"
convert random_3.png   -channel G  -separate   random_3_gray.png
cme random_3_gray.png 172.png

echo "random_5_gray.png"
convert random_5.png   -channel G  -separate   random_5_gray.png
cme random_5_gray.png 173.png

echo "random_10_gray.png"
convert random_10.png  -channel G  -separate   random_10_gray.png
cme random_10_gray.png 174.png

echo "random_20_gray.png"
convert random_20.png  -channel G  -separate   random_20_gray.png
cme random_20_gray.png 175.png

echo "random_0_thres.png"
convert random_0_gray.png   -threshold 50%   random_0_thres.png
cme random_0_thres.png 176.png

echo "random_1_thres.png"
convert random_1_gray.png   -threshold 50%   random_1_thres.png
cme random_1_thres.png 177.png

echo "random_3_thres.png"
convert random_3_gray.png   -threshold 50%   random_3_thres.png
cme random_3_thres.png 178.png

echo "random_5_thres.png"
convert random_5_gray.png   -threshold 50%   random_5_thres.png
cme random_5_thres.png 179.png

echo "random_10_thres.png"
convert random_10_gray.png  -threshold 50%   random_10_thres.png
cme random_10_thres.png 180.png

echo "random_20_thres.png"
convert random_20_gray.png  -threshold 50%   random_20_thres.png
cme random_20_thres.png 181.png

echo "random_5_blobs.png"
convert random_5_gray.png  -ordered-dither threshold,3  random_5_blobs.png
cme random_5_blobs.png 182.png

echo "ripples_1.png"
convert random_10_gray.png  -function Sinusoid 1,90   ripples_1.png
cme ripples_1.png 183.png

echo "ripples_2.png"
convert random_10_gray.png  -function Sinusoid 2,90   ripples_2.png
cme ripples_2.png 184.png

echo "ripples_3.png"
convert random_10_gray.png  -function Sinusoid 3,90   ripples_3.png
cme ripples_3.png 185.png

echo "ripples_4.png"
convert random_10_gray.png  -function Sinusoid 4,90   ripples_4.png
cme ripples_4.png 186.png

echo "random_enhanced.png"
convert random_10_gray.png        -level 25%            random_enhanced.png
cme random_enhanced.png 187.png

echo "ripples_4e.png"
convert random_enhanced.png  -function Sinusoid 4,90    ripples_4e.png
cme ripples_4e.png 188.png

echo "random_sigmoidal.png"
convert random_10_gray.png   -sigmoidal-contrast 10,50% random_sigmoidal.png
cme random_sigmoidal.png 189.png

echo "ripples_4s.png"
convert random_sigmoidal.png -function Sinusoid 4,90    ripples_4s.png
cme ripples_4s.png 190.png

echo "ripples_3e000.png"
convert random_enhanced.png  -function Sinusoid 3,0     ripples_3e000.png
cme ripples_3e000.png 191.png

echo "ripples_3e090.png"
convert random_enhanced.png  -function Sinusoid 3,90    ripples_3e090.png
cme ripples_3e090.png 192.png

echo "ripples_3e180.png"
convert random_enhanced.png  -function Sinusoid 3,180   ripples_3e180.png
cme ripples_3e180.png 193.png

echo "ripples_3e270.png"
convert random_enhanced.png  -function Sinusoid 3,270   ripples_3e270.png
cme ripples_3e270.png 194.png

echo "ripples_3.5e.png"
convert random_enhanced.png  -function Sinusoid 3.5,90    ripples_3.5e.png
cme ripples_3.5e.png 195.png

echo "tile_size.gif"
convert -size 60x60 tile:bg.gif  tile_size.gif
cme tile_size.gif 196.gif

echo "tile_over.gif"
convert test.png -size 200x200 tile:tile_disks.jpg  -composite  tile_over.gif
cme tile_over.gif 197.gif

echo "tile_draw.gif"
convert -size 60x60 xc: -tile tile_aqua.jpg  -draw "circle 30,30 2,30"   tile_draw.gif
cme tile_draw.gif 198.gif

echo "tile_reset.gif"
convert test.png   -tile tile_water.jpg  -draw "color 0,0 reset"  tile_reset.gif
cme tile_reset.gif 199.gif

echo "tile_distort_sized.gif"
convert rose: -set option:distort:viewport '%g' +delete   tree.gif -virtual-pixel tile -filter point -distort SRT 0  tile_distort_sized.gif
cme tile_distort_sized.gif 200.gif

echo "offset_tile.gif"
convert -size 80x80 -tile-offset +30+30 tile:rose:  offset_tile.gif
cme offset_tile.gif 201.gif

echo "offset_pattern.gif"
convert -size 80x80 -tile-offset +20+20  pattern:checkerboard offset_pattern.gif
cme offset_pattern.gif 202.gif

echo "offset_tile_fill.gif"
convert -tile-offset +30+30  -tile rose:  -size 80x80 xc: -draw 'color 30,20 reset'    offset_tile_fill.gif
cme offset_tile_fill.gif 203.gif

echo "offset_pattern_fail.gif"
convert -tile-offset +20+20 -tile pattern:checkerboard  -size 80x80  xc: -draw 'color 30,20 reset'  offset_pattern_fail.gif
cme offset_pattern_fail.gif 204.gif

echo "offset_pattern_good.gif"
convert -size 80x80  xc:  -tile-offset +20+20 +size -tile pattern:checkerboard  -draw 'color 30,20 reset'  offset_pattern_good.gif
cme offset_pattern_good.gif 205.gif

echo "tile_clone.gif"
convert tree.gif  \( +clone +clone \) +append  \( +clone +clone \) -append  tile_clone.gif
cme tile_clone.gif 206.gif

echo "tile_clone_flip.gif"
convert tree.gif  \( +clone -flop +clone \) +append  \( +clone -flip +clone \) -append  tile_clone_flip.gif
cme tile_clone_flip.gif 207.gif

echo "tile_mpr.gif"
convert tree.gif   -write mpr:tile +delete  -size 100x100 tile:mpr:tile    tile_mpr.gif
cme tile_mpr.gif 208.gif

echo "tile_mpr_reset.gif"
convert tree.gif  -write mpr:tile +delete  granite: -fill mpr:tile  -draw 'color 0,0 reset'  tile_mpr_reset.gif
cme tile_mpr_reset.gif 209.gif

echo "tile_mpr_fill.gif"
convert tree.gif -write mpr:tile +delete  granite:  -tile mpr:tile  -draw 'circle 64,64 0,64'  tile_mpr_fill.gif
cme tile_mpr_fill.gif 210.gif

echo "tile_distort.gif"
convert tree.gif -set option:distort:viewport 100x100+0+0  -virtual-pixel tile -filter point  -distort SRT 0  tile_distort.gif
cme tile_distort.gif 211.gif

echo "tile_distort_checks.gif"
convert tree.gif -set option:distort:viewport 100x100-10-10  -background firebrick  -virtual-pixel CheckerTile  -distort SRT 0 +repage    tile_distort_checks.gif
cme tile_distort_checks.gif 212.gif

echo "tile_distort_polar.gif"
convert tree.gif -set option:distort:viewport 100x100-50-50  -virtual-pixel tile  -distort Arc '45 0 50' +repage  tile_distort_polar.gif
cme tile_distort_polar.gif 213.gif

echo "pattern_default.gif"
convert  pattern:checkerboard  pattern_default.gif
cme pattern_default.gif 214.gif

echo "pattern_hexagons.gif"
convert -size 60x60 pattern:hexagons  pattern_hexagons.gif
cme pattern_hexagons.gif 215.gif

echo "pattern_colored.gif"
convert -size 60x60 pattern:hexagons  -fill blue -opaque black   -fill skyblue -opaque white  pattern_colored.gif
cme pattern_colored.gif 216.gif

echo "pattern_color_checks.gif"
convert -size 60x60 pattern:checkerboard -auto-level  +level-colors red,blue     pattern_color_checks.gif
cme pattern_color_checks.gif 217.gif

echo "pattern_color_hexagons.gif"
convert -size 30x54 pattern:hexagons  -fill tomato     -opaque white  -fill dodgerblue -draw 'color 10,10 floodfill'  -fill limegreen  -draw 'color 10,25 floodfill'  -roll +15+27  -fill dodgerblue -draw 'color 10,10 floodfill'  -fill limegreen  -draw 'color 10,25 floodfill'   miff:- | convert -size 100x100 tile:- pattern_color_hexagons.gif
cme pattern_color_hexagons.gif 218.gif

echo "pattern_distorted.gif"
convert -size 160x100 pattern:hexagons  -wave 3x100 -background white -rotate 90 -wave 4x66 -rotate -87  -gravity center -crop 120x90+0+0 +repage   pattern_distorted.gif
cme pattern_distorted.gif 219.gif

echo "tile_mod_failure.jpg"
convert pattern:hexagons  -rotate 90  -blur 0x1  -edge 1  -negate  -shade 120x45  miff:- | convert  -size 100x100 tile:-   tile_mod_failure.jpg
cme tile_mod_failure.jpg 220.jpg

echo "tile_mod_vpixels.jpg"
convert pattern:hexagons  -rotate 90  -virtual-pixel tile  -blur 0x1  -edge 1  -negate  -shade 120x45  miff:- | convert  -size 100x100 tile:-   tile_mod_vpixels.jpg
cme tile_mod_vpixels.jpg 221.jpg

echo "tile_slanted_bricks.jpg"
convert pattern:leftshingle pattern:rightshingle +append  -virtual-pixel tile  -blur 0x0.75 -resize 150% -shade 100x45  -fill Peru  -tint 100%   miff:- | convert  -size 100x100 tile:-   tile_slanted_bricks.jpg
cme tile_slanted_bricks.jpg 222.jpg

echo "tile_mod_success.jpg"
convert -size 60x60 tile:pattern:hexagons  -rotate 90  -blur 0x1  -edge 1  -negate  -shade 120x45  -gravity center -crop 18x30+0+0 +repage miff:- | convert  -size 100x100 tile:-   tile_mod_success.jpg
cme tile_mod_success.jpg 223.jpg

echo "tile_circles.jpg"
convert pattern:circles \( +clone \) +append \( +clone \) -append  -fill grey -opaque black  -blur 0x0.5 -shade 120x45  -gravity center -crop 50%  +repage    miff:- | convert  -size 100x100 tile:-   tile_circles.jpg
cme tile_circles.jpg 224.jpg

echo "tile_hexagons.gif"
convert  pattern:hexagons  tile_hexagons.gif
cme tile_hexagons.gif 225.gif

echo "tiled_hexagons.gif"
convert  -size 64x64  pattern:hexagons  tiled_hexagons.gif
cme tiled_hexagons.gif 226.gif

echo "tile_line.gif"
convert -size 24x24 xc: -draw "rectangle 3,11 20,12"  tile_line.gif
cme tile_line.gif 227.gif

echo "tile_hex_lines.jpg"
convert tile_line.gif   -gravity center \( +clone -rotate    0 -crop 24x18+0+0 -write mpr:r1 +delete \)  \( +clone -rotate  120 -crop 24x18+0+0 -write mpr:r2 +delete \)  -rotate -120 -crop 24x18+0+0 -write mpr:r3 +repage  -extent 72x36        -page  +0+0  mpr:r3  -page +24+0  mpr:r1  -page +48+0  mpr:r2  -page -12+18 mpr:r1  -page +12+18 mpr:r2  -page +36+18 mpr:r3  -page +60+18 mpr:r1  -flatten tile_hex_lines.jpg
cme tile_hex_lines.jpg 228.jpg

echo "tiled_hex_lines.jpg"
convert -size 120x120  tile:tile_hex_lines.jpg  tiled_hex_lines.jpg
cme tiled_hex_lines.jpg 229.jpg

# clean-up
FILES=("test.png" "shape.gif" "plasma_fractal2.jpg" "random.png" "tile_weave.gif" "bg.gif" "tile_aqua.jpg" "tile_water.jpg" "tile_rings.jpg" "tile_disks.jpg" "tree.gif" "canvas_khaki.gif" "canvas_wheat.gif" "canvas_salmon.gif" "color_sparse.gif" "color_reset.gif" "color_flatten.gif" "color_extent.gif" "color_border.gif" "color_fx_constant.gif" "color_semitrans.png" "color_pick_fx.png" "color_pick_sparse.png" "color_pick_draw.png" "color_pick_distort.png" "black_threshold.png" "black_level.png" "black_fx.png" "black_evaluate.png" "black_gamma.png" "black_posterize.png" "black_alpha.png" "white_threshold.png" "white_level.png" "white_fx.png" "white_evaluate.png" "white_posterize.png" "white_alpha.png" "trans_alpha.png" "trans_compose.png" "color_matte.png" "trans_fx.png" "trans_evaluate.png" "trans_threshold.png" "trans_fx_alpha_off.jpg" "yellow_gamma.png" "grey_level.png" "gradient.jpg" "gradient_range1.jpg" "gradient_range2.jpg" "gradient_range3.jpg" "gradient_range4.jpg" "gradient_range5.jpg" "gradient_ice-sea.jpg" "gradient_burnished.jpg" "gradient_grassland.jpg" "gradient_sunset.jpg" "gradient_snow_scape.jpg" "rgradient.jpg" "rgradient_clip.jpg" "rgradient_crop.jpg" "rgradient_range1.jpg" "rgradient_range2.jpg" "rgradient_range3.jpg" "rgradient_range4.jpg" "gradient_transparent.png" "gradient_trans_colorize.png" "gradient_sigmoidal.jpg" "gradient_cosine.jpg" "gradient_peak.jpg" "gradient_bands.jpg" "gradient_diagonal.jpg" "gradient_srt.jpg" "gradient_swirl.jpg" "gradient_trapezoid.jpg" "gradient_arc.jpg" "gradient_circle.jpg" "gradient_angle_even.png" "gradient_angle_odd.png" "gradient_angle_masked.png" "gradient_triangle.jpg" "gradient_bird.jpg" "gradient_venetian.jpg" "gradient_vent_diag.jpg" "gradient_colormap.jpg" "gradient_rainbow.jpg" "gradient_rainbow_2.jpg" "gradient_hue_polar.png" "gradient_resize.jpg" "gradient_resize2.jpg" "gradient_resize3.jpg" "gradient_resize4.jpg" "gradient_resize5.jpg" "gradient_rs_rainbow.jpg" "gradient_interpolated.jpg" "gradient_clut_recolored.jpg" "gradient_clut.jpg" "gradient_bilinear.jpg" "gradient_catrom.jpg" "gradient_mesh.jpg" "gradient_fx_linear.gif" "gradient_fx_x4.gif" "gradient_fx_cos.gif" "gradient_fx_radial.gif" "gradient_fx_spherical.gif" "gradient_fx_quad2.gif" "gradient_fx_angular.gif" "gradient_inverse_alt.gif" "gradient_shepards_alt.gif" "gradient_inverse_RGB.png" "gradient_inverse_RGB_Hue.gif" "sparse_barycentric.png" "sparse_bary_triangle.png" "sparse_bary_triangle_2.png" "sparse_bary_0.gif" "sparse_bary_gradient.png" "sparse_bary_gradient_2.png" "diagonal_gradient.jpg" "diagonal_gradient_2.jpg" "sparse_bary_two_point.png" "gradient_scale.png" "gradient_equiv.png" "gradient_math.png" "gradient_shifted.png" "gradient_chopped.png" "sparse_bilinear.png" "sparse_bilin_0.gif" "sparse_voronoi.gif" "sparse_voronoi_ssampled.png" "sparse_voronoi_smoothed.png" "sparse_voronoi_blur.png" "sparse_voronoi_gradient.png" "sparse_shepards.png" "sparse_inverse.png" "sparse_shepards_0.5.png" "sparse_shepards_1.png" "sparse_shepards_2.png" "sparse_shepards_3.png" "sparse_shepards_8.png" "sparse_shepards_gray.gif" "rose_alpha_gradient.png" "sparse_source.gif" "sparse_fill.png" "shape_edge_pixels.gif" "shape_edge_in_lights.png" "shape_in_lights.png" "sparse_blur_simple.png" "sparse_blur_pyramid.png" "sparse_lines_near_source.gif" "sparse_lines_near.png" "plasma_smooth.jpg" "plasma_paint.jpg" "plasma_emboss.jpg" "plasma_sharp.jpg" "plasma_seeded.jpg" "plasma_rnd1.jpg" "plasma_rnd2.jpg" "plasma_rnd3.jpg" "plasma_rnd4.jpg" "plasma_rnd5.jpg" "random_mask.png" "random_black.png" "random_white.png" "random_trans.png" "random_1.png" "random_3.png" "random_5.png" "random_10.png" "random_20.png" "random_0_gray.png" "random_1_gray.png" "random_3_gray.png" "random_5_gray.png" "random_10_gray.png" "random_20_gray.png" "random_0_thres.png" "random_1_thres.png" "random_3_thres.png" "random_5_thres.png" "random_10_thres.png" "random_20_thres.png" "random_5_blobs.png" "ripples_1.png" "ripples_2.png" "ripples_3.png" "ripples_4.png" "random_enhanced.png" "ripples_4e.png" "random_sigmoidal.png" "ripples_4s.png" "ripples_3e000.png" "ripples_3e090.png" "ripples_3e180.png" "ripples_3e270.png" "ripples_3.5e.png" "tile_size.gif" "tile_over.gif" "tile_draw.gif" "tile_reset.gif" "tile_distort_sized.gif" "offset_tile.gif" "offset_pattern.gif" "offset_tile_fill.gif" "offset_pattern_fail.gif" "offset_pattern_good.gif" "tile_clone.gif" "tile_clone_flip.gif" "tile_mpr.gif" "tile_mpr_reset.gif" "tile_mpr_fill.gif" "tile_distort.gif" "tile_distort_checks.gif" "tile_distort_polar.gif" "pattern_default.gif" "pattern_hexagons.gif" "pattern_colored.gif" "pattern_color_checks.gif" "pattern_color_hexagons.gif" "pattern_distorted.gif" "tile_mod_failure.jpg" "tile_mod_vpixels.jpg" "tile_slanted_bricks.jpg" "tile_mod_success.jpg" "tile_circles.jpg" "tile_hexagons.gif" "tiled_hexagons.gif" "tile_line.gif" "tile_hex_lines.jpg" "tiled_hex_lines.jpg")
FILES+=("sparse_bary_1.gif" "sparse_bary_2.gif" "sparse_bilin_1.gif" "sparse_bilin_2.gif")
echo "clean-up"
for file in "${FILES[@]}"; do
    rm "$file" || exit 1
    echo -n "."
done
echo
echo "done"
exit 0
