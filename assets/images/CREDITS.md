# `assets/images/` provenance

Phase 11.1 (Real CC-licensed photographs) replaced the 32 emoji-on-pastel
placeholders shipped by Phase 11 with curated, free-licensed photographs
sourced from Wikimedia Commons.

Phase 11.2 (Kid-friendly review pass) reviewed all 32 images against
five-year-old recognition criteria (single subject, bright/colorful,
no text or watermarks, cheerful, prototypical form) and swapped out
8 photos that were too "scientific", artistic, or cluttered for the
target audience. The replaced subjects are: `sol`, `mani`, `tre`,
`vatn`, `bok`, `bill`, `auga`, `lampi`. The replacements are mostly
public-domain cartoon illustrations from Openclipart (CC0) plus two
Wikimedia Commons CC-BY-SA cartoon illustrations. See
`audio-review/lexicon-photos-before.png` and
`audio-review/lexicon-photos-after.png` for side-by-side review.

Every image is recognizable at a glance to a 5-year-old and is licensed
for commercial redistribution as part of this app.

The widget code is unchanged: `ExampleWordOverlay`, `MatchingActivity`,
`CorrespondenceActivity`, and `AdditionActivity` all continue to read the
canonical `assets/images/letters/words/{slug}.webp` paths. Only the pixel
contents of those WebP files changed.

## Sourcing methodology

For each lexicon noun (32 entries from `kStarterLexicon` plus the two
auxiliary slugs `lampi` and `ros`), we:

1. Selected an English-language Wikipedia article whose subject is the
   noun in its most kid-recognizable form (e.g. `Cavendish_banana` for
   "banani", `Beach_ball` for "bolti", `Cottage` for "hús").
2. Pulled the lead infobox image via the Wikipedia REST API
   (`/api/rest_v1/page/summary/{title}`). These are guaranteed to be
   hosted on Wikimedia Commons under a free license — Wikipedia does not
   accept fair-use lead images for general subjects.
3. Downloaded the original (or 1024px thumb when the original was
   inconveniently large) from `upload.wikimedia.org`.
4. Converted to lossy WebP at q=80 with `cwebp 1.6.0`, longest edge
   capped at 512 px (`-resize 512 0` for landscape, `-resize 0 512` for
   portrait). Total directory footprint: ~864 KB for 32 images.
5. Verified the license on the Commons file page and recorded it in the
   table below. All 32 sourced images are CC0, public domain, CC-BY, or
   CC-BY-SA — all of which permit commercial redistribution. None are
   CC-NC or CC-ND.

## Per-image attribution

| Slug | Subject | License | Source URL |
|------|---------|---------|------------|
| hundur | Sled dogs (huskies) at rest | CC-BY-SA 4.0 | <https://commons.wikimedia.org/wiki/File:Huskiesatrest.jpg> |
| kottur | Tabby cat resting on ledge | CC-BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:Cat_August_2010-4.jpg> |
| kyr | Fleckvieh cow in alpine pasture | CC-BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:Cow_(Fleckvieh_breed)_Oeschinensee_Slaunger_2009-07-07.jpg> |
| hestur | Brown horse | CC-BY-SA 2.5 | <https://commons.wikimedia.org/wiki/File:Horse_007.jpg> |
| fugl | Eastern yellow robin (songbird) | CC-BY 2.0 | <https://commons.wikimedia.org/wiki/File:Eopsaltria_australis_-_Mogo_Campground.jpg> |
| fiskur | Bala shark (silver fish) | CC-BY-SA 4.0 | <https://commons.wikimedia.org/wiki/File:Balantiocheilos_melanopterus_-_Karlsruhe_Zoo_02_(cropped).jpg> |
| mus | Mouse | CC-BY-SA 4.0 | <https://commons.wikimedia.org/wiki/File:%D0%9C%D1%8B%D1%88%D1%8C_2.jpg> |
| kanina | European rabbit | CC-BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:Oryctolagus_cuniculus_Rcdo.jpg> |
| epli | Pink Lady apple, whole + cross-section | CC-BY-SA 4.0 | <https://commons.wikimedia.org/wiki/File:Pink_lady_and_cross_section.jpg> |
| banani | Cavendish bananas on white | CC-BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:Cavendish_Banana_DS.jpg> |
| braud | White bread loaf | CC-BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:Wei%C3%9Fbrot-1.jpg> |
| mjolk | Glass of milk | CC-BY 2.0 | <https://commons.wikimedia.org/wiki/File:Glass_of_Milk_(33657535532).jpg> |
| vatn | Cartoon glass of water with straw (Phase 11.2 replacement — was Lake Idro landscape; replaced for kid-friendliness) | Public Domain (Openclipart) | <https://openclipart.org/detail/193470/glass-of-water> |
| sol | Cartoon yellow smiling sun (Phase 11.2 replacement — was scientific grayscale Sun-in-white-light; replaced for kid-friendliness) | Public Domain (Openclipart) | <https://openclipart.org/detail/206318/cartoon-sun> |
| mani | Yellow crescent moon and star icon (Phase 11.2 replacement — was grayscale astronomy Full Moon photo; replaced for kid-friendliness) | Public Domain (Openclipart) | <https://openclipart.org/detail/220484/yellow-moon-and-star-icon> |
| tre | Simple green pine tree silhouette (Phase 11.2 replacement — was distant landscape lone ash; replaced for kid-friendliness) | Public Domain (Openclipart) | <https://openclipart.org/detail/192460/a-simple-green-tree> |
| blom | Magnolia grandiflora flower | CC-BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:Magnolia_grandiflora_-_flower_1.jpg> |
| bok | Cartoon open book with smiling face (Phase 11.2 replacement — was 1911 Fairy Tales cover with embedded text; replaced because text in image fails kid-photo rule) | CC-BY-SA 4.0 | <https://commons.wikimedia.org/wiki/File:Open_Book_Cartoon.jpg> |
| bill | Cartoon red car (Phase 11.2 replacement — was vintage Matchbox toy-cars row; replaced for clearer single-car recognition) | CC-BY-SA 4.0 | <https://commons.wikimedia.org/wiki/File:Red_Car_Closed_Window_Cartoon_Vector.svg> |
| hus | Country cottage on Inch Island | CC-BY-SA 2.0 | <https://commons.wikimedia.org/wiki/File:Country_cottage,_Inch_Island_-_geograph.org.uk_-_3951065_(cropped).jpg> |
| bolti | Beach ball | CC-BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:BeachBall.jpg> |
| dukka | Steiff teddy bear (stuffed toy) | CC-BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:Nachbildung_55PB_Steiff_Museum_Giengen.jpg> |
| koddi | Pillows on a hotel bed | CC-BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:Pillows_on_a_hotel_bed.jpg> |
| teppi | Russell quilt held up by quilter | Public Domain | <https://commons.wikimedia.org/wiki/File:Russellquilter.jpg> |
| stoll | Set of antique side chairs (Met Museum) | Public Domain (Met CC0) | <https://commons.wikimedia.org/wiki/File:Set_of_fourteen_side_chairs_MET_DP110780.jpg> |
| hattur | 1910 black silk top hat | Public Domain | <https://commons.wikimedia.org/wiki/File:1910_top_hat.jpg> |
| peysa | Selburose-pattern wool sweater | CC-BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:Selburose-sweater.jpg> |
| sokkar | Hand-knit white lace sock | CC-BY-SA 3.0 | <https://commons.wikimedia.org/wiki/File:HandKnittedWhiteLaceSock.jpg> |
| skor | Air Jordan 1 sneakers (red/black) | CC-BY-SA 4.0 | <https://commons.wikimedia.org/wiki/File:Air_Jordan_1_Banned.jpg> |
| auga | Cartoon blue eye (Phase 11.2 replacement — was photographic close-up of bloodshot human eye, unsettling for 5-year-olds; replaced with cartoon) | Public Domain (Openclipart) | <https://openclipart.org/detail/183972/cartoon-eye> |
| lampi | Cartoon table lamp with cyan shade (Phase 11.2 replacement — was cluttered Wide-array-of-lamps store-shelf shot; replaced with single clean lamp) | Public Domain (Openclipart) | <https://openclipart.org/detail/240395/table-lamp> |
| ros | Rosa rubiginosa (sweet briar) flower | Public Domain | <https://commons.wikimedia.org/wiki/File:Rosa_rubiginosa_1.jpg> |

## Attribution requirements

Of the 32 images, 26 are CC-BY or CC-BY-SA (require attribution) and 6
are public domain / CC0 (no attribution legally required, but credited
above for transparency).

This file SHIPS WITH THE APP (it's bundled under `assets/images/` in
`pubspec.yaml`) and discharges the attribution obligation for every
CC-BY / CC-BY-SA photo above. The app's "About" screen (when added)
should link to this file or include the equivalent credits inline.

For CC-BY-SA images specifically: the ShareAlike clause does NOT
relicense the entire app. ShareAlike applies only to *derivative works
of the image itself* (e.g. an edited version of the photo), not to
unrelated code that merely displays the image. Wikipedia's own
copyright FAQ explicitly states this.

## Image format / sizing

* Format: lossy WebP, q=80 (occasionally q=70/60 for larger originals)
* Max edge: 512 px (longest dimension)
* Conversion tool: `cwebp 1.6.0` from libwebp
* Per-file size: 6.6 KB – 58 KB (well under the 200 KB / file budget)
* Total: ~864 KB for 32 files

## Regenerating

The original raw downloads are NOT checked in. To regenerate:

1. Re-fetch from the Source URLs in the table above.
2. Run `cwebp -q 80 -resize 512 0 raw.jpg -o {slug}.webp` (landscape) or
   `-resize 0 512` (portrait).
3. Verify file size < 200 KB; lower `-q` to 70 or 60 if needed.

If a future designer pass replaces these photos with custom-commissioned
art, this file MUST be updated to remove the Wikimedia attributions and
record the new provenance.
