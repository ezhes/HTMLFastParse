# Begins fuzzing with honggfuzz
./honggfuzz --input corpus --output output --threads 16 --env OS_ACTIVITY_MODE=disable --env DYLD_INSERT_LIBRARIES=/usr/lib/libgmalloc.dylib --rlimit_rss 4096 -q -- ./fuzz_target
