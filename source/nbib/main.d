module nbib.main;

import std.typecons : Tuple;
import std.array;
import std.algorithm : joiner, map, splitter, splitWhen, chunkBy, group;
import std.conv;
import std.string : strip, stripRight;
import std.format : format;
import std.stdio;
import std.range.primitives : empty;
import mir.algebraic;
import asdf;

import nbib.types;
import nbib.transforms;

void main()
{
    string filename = "pubmed.nbib";

    auto fi = File(filename);

    auto records = fi.byLineCopy
                        .map!stripRight
                        .array
                        .splitter("")
                        .map!mergeMultiLineItems
                        .map!medlineToCSL
                        .map!reduceAuthors;

    auto ser = records.toAsdf;

    writeln(ser.app.result.to!string);
}
