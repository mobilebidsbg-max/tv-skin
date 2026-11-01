package com.dzafirov.tvskin.widgets

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.async
import kotlinx.coroutines.coroutineScope

enum class Brand(val packageName: String, val label: String, val providerIds: String) {
    NETFLIX("com.netflix.ninja", "NETFLIX", "8"),
    HBO("com.wbd.stream", "max", "1899|384"),
}

/** One card in the Netflix / HBO Max strip. */
data class Promo(val title: String, val imageUrl: String, val meta: String, val brand: Brand)

/** Popular series from a TMDB discover response; titles without a backdrop are skipped. */
fun parseTmdb(json: String, brand: Brand): List<Promo> = runCatching {
    val results = org.json.JSONObject(json).getJSONArray("results")
    (0 until results.length()).mapNotNull { i ->
        val r = results.getJSONObject(i)
        val backdrop = r.optString("backdrop_path").takeIf { it.isNotEmpty() && it != "null" } ?: return@mapNotNull null
        val title = r.optString("name").ifEmpty { r.optString("title") }.ifEmpty { return@mapNotNull null }
        val year = r.optString("first_air_date").ifEmpty { r.optString("release_date") }.take(4)
        Promo(title, "https://image.tmdb.org/t/p/w780$backdrop", if (year.isNotEmpty()) "Series · $year" else "Series", brand)
    }
}.getOrDefault(emptyList())

/** Netflix, HBO Max, Netflix, … while both have titles, then whatever is left. */
fun interleave(a: List<Promo>, b: List<Promo>, count: Int): List<Promo> {
    val out = mutableListOf<Promo>()
    var i = 0
    while (out.size < count && (i < a.size || i < b.size)) {
        a.getOrNull(i)?.let { out += it }
        if (out.size < count) b.getOrNull(i)?.let { out += it }
        i++
    }
    return out.take(count)
}

/** Popular on Netflix and HBO Max in Bulgaria, from TMDB (free key in the Mac's .env). Cached 6 hours. */
class PromosRepository(private val apiKey: String, private val clock: () -> Long = System::currentTimeMillis) {
    private var cached: List<Promo> = emptyList()
    private var fetchedAt = 0L

    suspend fun latest(): List<Promo> {
        if (apiKey.isBlank()) return emptyList()
        if (cached.isNotEmpty() && clock() - fetchedAt < 6 * 60 * 60_000L) return cached
        val (netflix, hbo) = coroutineScope {
            val n = async(Dispatchers.IO) { load(Brand.NETFLIX) }
            val h = async(Dispatchers.IO) { load(Brand.HBO) }
            n.await() to h.await()
        }
        val mixed = interleave(netflix, hbo, count = 6)
        if (mixed.isNotEmpty()) { cached = mixed; fetchedAt = clock() }
        return cached
    }

    private fun load(brand: Brand): List<Promo> = runCatching {
        parseTmdb(
            fetch(
                "https://api.themoviedb.org/3/discover/tv?api_key=$apiKey&watch_region=BG&with_watch_providers=${brand.providerIds}" +
                    "&with_watch_monetization_types=flatrate&sort_by=popularity.desc&language=en-US&page=1",
            ),
            brand,
        )
    }.getOrDefault(emptyList())
}
