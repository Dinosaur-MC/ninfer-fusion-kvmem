#pragma once

#include <cstdint>

namespace ninfer::runtime {

// Historical latch rule: this many consecutive context-cache refusals with no successful
// admission in between made the Engine report itself unavailable, so a healthcheck-driven
// restart clears the wedged pools.
inline constexpr std::uint32_t kStuckContextCacheExhaustions = 3;

// The latch decision, isolated from Engine state so it can be tested directly.
[[nodiscard]] constexpr bool stuck_latch_blocks(std::uint32_t streak,
                                                bool latch_enabled) noexcept {
    return latch_enabled && streak >= kStuckContextCacheExhaustions;
}

// NINFER_KV_STUCK_LATCH: "1"/"true"/"on"/"yes" (case-insensitive first letter) enable the latch;
// unset, empty, "0", "false", "off" and "no" keep the default of a permanently available Engine.
// The value is read once per process.
[[nodiscard]] inline bool parse_stuck_latch_env(const char* value) noexcept {
    if (value == nullptr || value[0] == '\0') { return false; }
    const char lead = value[0];
    if (lead == '1' || lead == 't' || lead == 'T' || lead == 'y' || lead == 'Y') { return true; }
    if (lead == 'o' || lead == 'O') { return value[1] == 'n' || value[1] == 'N'; }
    return false;
}

} // namespace ninfer::runtime
