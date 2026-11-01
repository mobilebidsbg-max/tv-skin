package com.dzafirov.tvskin.ui

/** The TV's UI: 1920x1080 px at density 2 (320 dpi), so 960x540 dp. */
const val TV_QUALIFIERS = "w960dp-h540dp-land-television-xhdpi"

/** Reference PNGs live next to the tests so they are committed and reviewed. */
fun snapshot(name: String) = "src/test/snapshots/$name.png"
