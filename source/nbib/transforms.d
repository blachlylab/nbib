module nbib.transforms;

import std.typecons : Tuple;
import std.array;
import std.algorithm : count, filter, joiner, map, cumulativeFold, fold, reduce, splitter, splitWhen, chunkBy, group;
import std.range : isInputRange, takeNone, takeOne, chain;
import std.conv;
import std.string : strip, stripRight;
import std.format : format;
import std.stdio;
import std.range.primitives : empty;
import mir.algebraic;
import asdf;

import nbib.types;

/// Convert a MEDLINE/Pubmed nbib (RIS-like) tag into corresponding CSL tag/value
///
/// The return type is a nullable algebreic type that supports ordinary types, name fields, and date fields
/// Recognized but non-supported tags, and unrecognized tags both yield an empty result: CSLValue(null)
/// On error, CSLValue(null) is also returned (TODO: consider expect package or similar)
CSLValue processTag(string tag, string value)
{
    assert(!tag.empty && tag.length <= 4, "MEDLINE/Pubmed nbib tags are 1-4 characters");

    if (tag == "AB") {
        return cast(CSLValue) CSLOrdinaryField("abstract", value);
    }
    else if (tag == "PMID") {
        return CSLValue(CSLOrdinaryField("note", format("PMID: %s", value)));
    }
    else if (tag == "PMC") {
        return CSLValue(CSLOrdinaryField("note", format("PMCID: %s", value)));
    }
    // Manuscript Identifier (MID)
    
    else if (tag == "TI") {
        return CSLValue(CSLOrdinaryField("title", value));
    }
    else if (tag == "VI") {
        return CSLValue(CSLOrdinaryField("volume", value));
    }
    else if (tag == "IP") {
        return CSLValue(CSLOrdinaryField("issue", value));
    }
    else if (tag == "PG") {
        return CSLValue(CSLOrdinaryField("page", value));
    }
    else if (tag == "DP") {
        // TODO need to transform to ISO 8601 per CSL specs;
        // medline looks like YYYY Mon DD
        return CSLValue(CSLDateField("issued", value));
    }
    else if (tag == "FAU") return CSLValue(CSLNameField("author", value));
    else if (tag == "AU") return CSLValue(CSLNameField("author", value));
    else if (tag == "FED") return CSLValue(CSLNameField("editor", value));
    else if (tag == "ED") return CSLValue(CSLNameField("editor", value));
    
    else if (tag == "AUID") {
        // This would typically be an ORCID
        // CSL name-variable definition does not have designated place for author id
        // https://github.com/citation-style-language/schema/blob/c2142118a0265dfcf7d66aa3328251bedcc66af2/schemas/input/csl-data.json#L463-L498
        //
        // Because this can appear in the middle of author lists, we will ignore it for now :/
        //return CSLValue(CSLOrdinaryField("note", value));
        return CSLValue(null);
    }

    else if (tag == "LA") {
        // return CSL "language"
        // TODO, MEDLINE/Pubmed uses 3 letter language code; does CSL specify 3 or 2 letter?a
        // https://www.nlm.nih.gov/bsd/language_table.html
        return CSLValue(CSLOrdinaryField("language", value));
    }

    else if (tag == "SI") {
        // return CSL "note"
        return CSLValue(CSLOrdinaryField("note", value));
    }

    // (GR) Grant Number

    else if (tag == "PT") {
        // This field describes the type of material that the article represents;
        // it characterizes the nature of the information or the manner in which
        // it is conveyed (e.g., Review, Letter, Retracted Publication, Clinical Trial).
        // Records may contain more than one Publication Type, which are listed in alphabetical order.
        // 
        // Almost all citations have one of these four basic, most frequently used
        // Publication Types applied to them: Journal Article, Letter, Editorial, News.
        // One of the above four Publication Types is applied to more than 99% of
        // all citations indexed for MEDLINE.
        //
        // Reference: https://www.nlm.nih.gov/mesh/pubtypes.html
        if (value == "Journal Article") {
            // return "type": "article-journal"
            // https://aurimasv.github.io/z2csl/typeMap.xml#map-journalArticle
            return CSLValue(CSLOrdinaryField("type", "article-journal"));
        } else {
            // else throw(?) or return Option<None>
            CSLValue ret;
            ret.nullify;
            return ret;
        }
    }

    else if (tag == "TA")
        return CSLValue(CSLOrdinaryField("container-title-short", value));
    else if (tag == "JT")
        return CSLValue(CSLOrdinaryField("container-title", value));
    
    else if (tag == "AID") {
        // if DOI, return CSL "DOI" , and strip trailing "[doi]"
        if (value[$-5 .. $] == "[doi]")
            return CSLValue(CSLOrdinaryField("DOI", value[0 .. $-6]));
        else {
            CSLValue ret;
            ret.nullify;
            return ret;
        }
    }

    else {
        //stderr.writefln("Unprocessed tag: %s", tag);
        CSLValue ret;
        ret.nullify;
        return ret;
    }

    assert(0, "Tag matched without return");
}
unittest
{
    assert( processTag("XYZ", "val") == CSLValue(null) );

    assert( processTag("AB", "This is the abstract") == CSLValue(CSLOrdinaryField("abstract", "This is the abstract")) );

    assert( processTag("PMID", "12345") == CSLValue(CSLOrdinaryField("note", "PMID: 12345")) );

    assert( processTag("FAU", "Blachly, James S") == CSLNameField("author", "Blachly, James S") );

    // TODO test date field
}

/// Merge multi-line records from a range of strings
/// (Unfortunately, not lazily)
///
/// For example:
/// ["AB  - Abstract first line...", "      continued second..."]
/// would be merged into a single record in the output range
/// The complete range might look like:
/// ["PMID- 12345", "TI  - Article title", "AB  - Abstr line 1", "      ...line2", "AU  - Blachly JS"]
auto mergeMultiLineItems(R)(R range)
    if (isInputRange!R)
{
    string[] ret;
    string[] buf;   // temporary buffer

    foreach(row; range) {
        assert(row.length > 4, "Malformed record of length <= 4");
        if (row[4] == '-' && buf.empty)
            buf ~= row.strip;
        else if (row[4] == '-' && !buf.empty) {
            // New record; buf may contain one or more rows
            // merge (if applicable) buf and append to ret

            if (buf.length == 1) {
                // New record immediately after prior single-line record
                ret ~= buf[0];
                buf.length = 0;
            } else {
                // New record after prior multi-line record
                ret ~= buf.joiner(" ").array.to!string;    // strip removed trailing and leading spaces
                buf.length = 0;
            }
            // then add current record to buf
            buf ~= row.strip;
        } else if (row[4] != '-' && !buf.empty) {
            // A multi-line continuation
            buf ~= row.strip;
        } else
            assert(0, "Invalid state");
    }
    // Now, buf may be empty if the last row was the end of a multi-line record (unlikely)
    // but to be safe we must test it is nonempty before finally dumping it to ret
    if (buf.length == 0) assert(buf.length == 0);
    else if (buf.length == 1) ret ~= buf[0];
    else ret ~= buf.joiner(" ").array.to!string;
    return ret;
}
unittest
{
    string[] rec = [
        "PMID- 12345",
        "XY  - Unused field",
        "AB  - This is the abstract's first line",
        "      and this is its second line;",
        "      with conclusion.",
        "FAU - Blachly, James S",
        "FAU - Gregory, Charles Thomas"
    ];

    auto mergedRec = mergeMultiLineItems(rec);

    assert(mergedRec.length == 5);
    assert(mergedRec[2] == "AB  - This is the abstract's first line and this is its second line; with conclusion.");
}

/// Convert medline record (group of tags) to CSL-JSON item tags
/// TODO make lazy
auto medlineToCSL(R)(R range)
{
    CSLValue[] ret;

    foreach(row; range) {
        // Format: "XXXX- The quick brown fox jumped..."
        // where XXXX of length 1-4 and right-padded
        assert(row.length >= 7, "Malformed record");
        assert(row[4] == '-', "Malformed record");

        auto key = row[0 .. 4].stripRight;
        auto value = row[6 .. $];

        auto csl = processTag(key, value);
        if (!csl.isNull)
            ret ~= processTag(key, value);
    }

    return ret;
}

/// Merge author records when both FAU and AU appear for same author
/// (or make best effort)
/// 
/// Takes a range of CSL tags/values (collectively, a complete record => rec)
///
/// TODO: support multiple types (author, editor)
auto reduceAuthors(R)(R rec)
    if (isInputRange!R)
{
    // Strategy 0: exploratory
/+
    auto names = rec.filter!(
        v => v.visit!(
            (CSLOrdinaryField x) => false,
            (CSLNameField x) => true,
            (CSLDateField x) => false
        ));
            
    auto namesTypes = rec.filter!(
        v => v.visit!(
            (CSLOrdinaryField x) => false,
            (CSLNameField x) => true,
            (CSLDateField x) => false
        ))
        .map!(x => x.getMember!"key")    // not sure why this compiles since also Nullable?
        .group;
+/              
    auto namesGroupedByType = rec.filter!(
        v => v.visit!(
            (CSLOrdinaryField x) => false,
            (CSLNameField x) => true,
            (CSLDateField x) => false
        ))
        .chunkBy!((a,b) => a.key == b.key);

    auto reduced = namesGroupedByType
        .map!(n => n.chunkBy!(
            (a,b) => a.tryGetMember!"np".family.split(" ")[0] ==
                     b.tryGetMember!"np".family.split(" ")[0])
            .map!(y => y.takeOne)
        ).joiner.joiner;
    // `reduced` now contains deduplicated names

    auto noNames = rec.filter!(
    visit!(
        (CSLOrdinaryField x) => true,
        (CSLNameField x) => false,
        (CSLDateField x) => true
    ));

    return chain(noNames, reduced);
   /+ 
    // Strategy 1: if len(FAU) and len(AU) same, remove AU

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
    stderr.writefln("Full authors: %d", nFAU);
    stderr.writefln("Old-style authors: %d", nAU);

    // If only one or the other record type appears, no worries, bail out
    if (nFAU == 0 || nAU == 0)
        return rec;

    // remove non-full authors
    if (nFAU == nAU)
        return rec.filter!(
            v => v.visit!(
                (CSLOrdinaryField x) => true,
                (CSLNameField x) => x.full,
                (CSLDateField x) => true
            )).array;

    else if (nFAU > nAU)
        stderr.writefln("WARNING: Can't handle Full:%d > Non-full:%d for type ", nFAU, nAU);

    else if (nAU > nFAU)
        stderr.writefln("WARNING: Can't handle Non-full:%d > Full:%d for type ", nAU, nFAU);

    else
        assert(0, "Unanticipated condition");

    // Strategy 2: match on surname;
    // prone to breakage if ther are participles like "van" "von" "de" etc.
    // TODO

    return rec;
+/
}
unittest
{
    string a = "author";
    string e = "editor";

    void check(CSLValue[] testData, size_t preLength, size_t postLength)
    {
        assert(testData.length == preLength);
        auto res = testData.reduceAuthors.array;
        writefln("res: %s", res);
        assert(res.length == postLength);
    }
 
    CSLValue[] test0 = [
        CSLValue( CSLNameField(a, "Blachly, James S") ),
        CSLValue( CSLNameField(a, "Blachly JS") ),
        CSLValue( CSLNameField(a, "Gregory, Charles T") ),
        CSLValue( CSLNameField(a, "Gregory CT") )
    ];

    check(test0, 4, 2);

    CSLValue[] test1 = [
        CSLValue( CSLNameField(a, "Blachly, James S") ),
        CSLValue( CSLNameField(a, "Blachly JS") ),
        CSLValue( CSLNameField(a, "Gregory CT") ),
        CSLValue( CSLNameField(a, "Kautto, Esko A") )
    ];

    check(test1, 4, 3);   

    // Now test handling when we mix name types: author and editor
    CSLValue[] test2 = [
        CSLValue( CSLNameField(a, "Blachly, James S") ),
        CSLValue( CSLNameField(a, "Blachly JS") ),
        CSLValue( CSLNameField(a, "Gregory, Charles T") ),
        CSLValue( CSLNameField(a, "Gregory CT") ),
        CSLValue( CSLNameField(e, "Professor, Esteemed") )   // FED - 
    ];
   
    check(test2, 5, 3); // result: 2 FAU, 1 FED 
}

/// Convert range of records (where each record is a range of tags)
/// to `asdf` (a binary JSON-like representation), which can then
/// be serialized out to (non-pretty-printed) JSON
auto toAsdf(R)(R records)
{
    import std.algorithm : count, each, filter;
    
    auto ser = asdfSerializer();
    auto state0 = ser.listBegin();
    foreach (rec; records) {
        CSLItem item;

        // Load the CSLItem by field type
        rec.each!(v => v.visit!(
            (CSLOrdinaryField x) => item.fields ~= x,
            (CSLNameField x) => item.names ~= x,
            (CSLDateField x) => item.dates ~= x
        ));

        ser.elemBegin;
        ser.serializeValue(item);
    }
    ser.listEnd(state0);

    return ser;
}

