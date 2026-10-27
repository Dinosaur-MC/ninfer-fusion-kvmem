#include "runtime/engine/stuck_latch.h"

#include <cstdio>

namespace {

int failures = 0;

void check(bool condition, const char* what) {
    if (condition) { return; }
    ++failures;
    std::fprintf(stderr, "FAIL: %s\n", what);
}

} // namespace

int main() {
    using ninfer::runtime::parse_stuck_latch_env;
    using ninfer::runtime::stuck_latch_blocks;

    // Default (latch off) never blocks, whatever the streak.
    for (unsigned streak = 0; streak <= 10; ++streak) {
        check(!stuck_latch_blocks(streak, false), "latch off must never block");
    }
    // Latch on blocks only at the threshold.
    check(!stuck_latch_blocks(0, true), "streak 0 must not block");
    check(!stuck_latch_blocks(1, true), "streak 1 must not block");
    check(!stuck_latch_blocks(2, true), "streak 2 must not block");
    check(stuck_latch_blocks(3, true), "streak 3 must block");
    check(stuck_latch_blocks(4, true), "streak 4 must block");

    // Environment parsing: only explicit truthy values enable the historical latch.
    check(!parse_stuck_latch_env(nullptr), "unset must default off");
    check(!parse_stuck_latch_env(""), "empty must default off");
    check(parse_stuck_latch_env("1"), "1 enables");
    check(parse_stuck_latch_env("true"), "true enables");
    check(parse_stuck_latch_env("TRUE"), "TRUE enables");
    check(parse_stuck_latch_env("on"), "on enables");
    check(parse_stuck_latch_env("ON"), "ON enables");
    check(parse_stuck_latch_env("yes"), "yes enables");
    check(!parse_stuck_latch_env("0"), "0 disables");
    check(!parse_stuck_latch_env("false"), "false disables");
    check(!parse_stuck_latch_env("FALSE"), "FALSE disables");
    check(!parse_stuck_latch_env("off"), "off disables");
    check(!parse_stuck_latch_env("no"), "no disables");
    check(!parse_stuck_latch_env("garbage"), "garbage disables");

    if (failures != 0) {
        std::fprintf(stderr, "%d assertion(s) failed\n", failures);
        return 1;
    }
    std::printf("stuck latch policy: ok\n");
    return 0;
}
