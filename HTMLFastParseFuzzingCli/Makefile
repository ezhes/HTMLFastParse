ALL   = fuzz_target
FLAGS = -Wall -O3 -fblocks -framework CoreFoundation -framework AppKit -fsanitize=address
CC	= ./hfuzz-cc
.PHONY: all clean

all: $(ALL)

fuzz_target: ../HTMLFastParseFuzzingCli/*.m
	$(CC) -o $@ $^ "../HTMLFastParse/C Mode/entities.c" "../HTMLFastParse/C Mode/C_HTML_Parser.c" "../HTMLFastParse/C Mode/Stack.c" $(FLAGS)

clean:
	rm -f $(ALL)
