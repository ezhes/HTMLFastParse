ALL   = fuzz_target
FLAGS = -Wall -Ofast -fsanitize=address
CC	= ./hfuzz-cc
.PHONY: all clean

all: $(ALL)

# It's good practice to ensure the Swift library is built before trying to link against it.
# This can be a separate command the user runs, or hinted in comments.
# For this subtask, just modify the fuzz_target rule's compilation line.

fuzz_target: ../HTMLFastParseFuzzingCli/main.c ../Sources/HTMLSwiftParser/HTMLFastParseCAPI.h # Depend on the CAPI header
	# First, ensure the Swift Package is built (path relative to Makefile in HTMLFastParseFuzzingCli/)
	# This command might be `swift build -C ../` if Makefile is in a subdirectory.
	# Or simply assume it's built and try to link.
	# The path to .build will be relative to the package root, so ../.build
	$(CC) -o $@ $< $(FLAGS) -L../.build/debug -lHTMLFastParse \
	    -Xlinker -rpath -Xlinker @executable_path/../.build/debug \
	    -Xlinker -rpath -Xlinker /usr/lib/swift # Common rpath for Swift libs on Linux, macOS might differ or handle via @rpath

clean:
	rm -f $(ALL)
	rm -rf output
	mkdir output
	rm *.fuzz
	rm HONGGFUZZ.REPORT.TXT
