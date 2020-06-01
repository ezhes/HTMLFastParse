ALL   = fuzz_target
FLAGS = -Wall -O3 -fblocks -framework CoreFoundation -framework AppKit -fsanitize=address
CC	= ./hfuzz-cc
.PHONY: all clean

all: $(ALL)

fuzz_target: ../HTMLFastParseFuzzingCli/*.m
	$(CC) -o $@ $^ "../HTMLFastParse/entities.c" "../HTMLFastParse/C_HTML_Parser.c" "../HTMLFastParse/Stack.c" "../HTMLFastParse/base64.c" $(FLAGS)

clean:
	rm -f $(ALL)
	rm -rf output
	mkdir output
	rm *.fuzz
	rm HONGGFUZZ.REPORT.TXT
