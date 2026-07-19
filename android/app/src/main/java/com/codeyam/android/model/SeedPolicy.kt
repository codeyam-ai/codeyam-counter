package com.codeyam.android.model

/**
 * Decides whether the app should trust state already present in a [KeyValueStore]
 * at launch. Ported from iOS `SeedPolicy`.
 *
 * CodeYam scenarios seed state by writing a scenario's preferences into the store
 * using the *exact same keys the app uses for real persistence* (`counters`,
 * `selectedCounterId`, …). Because seeding and real persistence share those keys,
 * the app cannot tell test-injected/stale state from genuine user state by key
 * alone. This policy centralizes the trust decision and adds a provenance marker
 * the app stamps when *it* persists — a marker CodeYam seeding never writes — so a
 * release build can safely discard bare injected/stale state while still honoring
 * a real user's own persisted data.
 */
enum class SeedPolicy {
    /** Adopt any injected/persisted state as-is — debug builds (CodeYam captures). */
    TRUST_INJECTED,

    /** Only adopt store state carrying the app's own provenance marker — release builds. */
    REQUIRE_PROVENANCE;

    /**
     * True when this policy should honor externally-supplied state in [store].
     * [REQUIRE_PROVENANCE] honors it only once the app's own marker is present.
     */
    fun trustsStore(store: KeyValueStore): Boolean = when (this) {
        TRUST_INJECTED -> true
        REQUIRE_PROVENANCE -> store.contains(PROVENANCE_KEY)
    }

    companion object {
        /**
         * The key the app stamps when it persists. Present ⇒ this store's data was
         * written by the app itself, not injected by CodeYam seeding.
         */
        const val PROVENANCE_KEY = "counterStoreProvenance"

        /**
         * The default for the running build: debug trusts injected state so CodeYam
         * captures keep working; release requires provenance so a distribution
         * launch never adopts scenario seed data. The app passes `BuildConfig.DEBUG`.
         */
        fun current(isDebug: Boolean): SeedPolicy =
            if (isDebug) TRUST_INJECTED else REQUIRE_PROVENANCE

        /** Stamp the marker so a real user's own persisted data is trusted next launch. */
        fun stampProvenance(store: KeyValueStore) {
            store.putBoolean(PROVENANCE_KEY, true)
        }
    }
}
