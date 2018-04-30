# HTMLFastParse

When you need to transform complex HTML into rich NSAttributedStrings *right now*. 

This library, written mostly in C with `NSAttributedString` functions in Obj-C, is specially tuned for Reddit's HTML outputs and blows all other parsers out of the water. As a warning, the parser itself takes no shortcuts however I didn't implement any HTML tags which are not used by Reddit and so this isn't a complete formatter. If you are using it with Reddit, you are in luck because you'll have access to the following at actually lightning fast speed:

* Bold, italics, superscript, strikethrough, code blocks, quotes, links, etc
* Inline HTML entity decoding
* An extensible architecture which allows you to add and remove tags as necessary for your application

### Using it
Copy everything from HTMLFastParse/C Mode into your project. 

If you're using Objective-C simply import `FormatToAttributedString.h`. If you're using Swift you'll need to import `FormatToAttributedString.h` in your `???-Bridge-Header.h` instead.

Once you've imported everything initialize the engine with `FormatToAttributedString * formatter = [[FormatToAttributedString alloc]init];`

***Note that you'll want to store this somewhere. Do not recreate the formatter every time!*** The formatter generates a ton of fonts and colors when it is initialized and then caches them and so your performance will be dismal if you recreate the formatter every time you use it. 

After that you can simply use `[formatter attributedStringForHTML:<string>];` to get an attributed string out. 


### Benchmarks

To parse and format [this](https://www.reddit.com/r/reddit.com/comments/6ewgt/reddit_markdown_primer_or_how_do_you_do_all_that/c03nik6/) one thousand times on an iPhone X running 11.2 took just **477.956ms**. The nearest neighbor, Cocoamarkdown, took 8497ms. For a summary and comparisons against other engines see [my write up](https://blog.services.aero2x.eu/benchmarking-popular-markdown-parsers-on-ios.html).


### How it all fits together

A good way to get insight on the process and algorithms is to comment out `#define printf(fmt, ...) (0)` in `C_HTML_Parser.c`. This preprocessor definition disables printing which is important for speed as printf is slow.

Normally you will only ever work with *FormatToAttributedString*. This class handles calling all the much faster C functions below it as well as taking a flattened style array and applying it to a string to create the output product. In this class you can configure the attributed string's appearance (font, color of quotes/code, etc).

*C\_HTML\_Parser*: this class has two main methods.

1. `tokenizeHTML:` This method takes in a C string as well as an output buffer for human readable text as well as a tag buffer. This method in essence reads through the input, separating tags and displayed text, and putting them into their respective slots while also doing HTML entity decoding. The tags put in the output buffer are of type `t_tag` which is a C struct holding the contents of the first tag and also the start and end positions of the tag. Something important to note about start and ending positions is that they are anchored based on *visible* characters and not *byte characters*. This really doesn't matter if you're using pure ASCII however certain characters like 'â' are actually a combination of multiple characters however render to only one. NSAttributedString treats them as single characters and so the ranges in the tags reflect that.
2. `makeAttributesLinear:` This method takes a bunch of overlapping t_tags and converts them into a one dimensional/flattens them into a set of t_format structs. The algorithm I used for this is to apply the tag formats to its characters and then running back over that formatted array to generate a final style state which can be easily fed into NSAttributedString which doesn't really allow overlapping font styles. This is the method, along with `t_format` and `addAttributeToString:(NSMutableAttributedString *)string forFormat:(struct t_format)format` you'd modify if you want to add new styles.

If you have questions about implementing a new styling feature for your project and don't know what you need to change, submit an issue. 