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
                        .map!medlineToCSL;

    foreach (rec; records) {
        import std.algorithm : count, filter;
        // Count full authors
        auto nFAU = rec.filter!(
            v => v.visit!(
                (CSLOrdinaryField x) => false,
                (CSLNameField x) => x.full,
                (CSLDateField x) => false
            )).count;
        // Count old-style authors
        auto nAU = rec.filter!(
            v => v.visit!(
                (CSLOrdinaryField x) => false,
                (CSLNameField x) => !x.full,
                (CSLDateField x) => false
            )).count;
        writefln("Full authors: %d", nFAU);
        writefln("Old-style authors: %d", nAU);
        // remove non-full authors
        if (nFAU >= nAU)
            rec = rec.filter!(
                v => v.visit!(
                    (CSLOrdinaryField x) => true,
                    (CSLNameField x) => x.full,
                    (CSLDateField x) => true
                )).array;

        writeln(rec.serializeToJsonPretty);
    }
}
