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

struct CSLOrdinaryField
{
    string key;
    string value;
}

/// Definition:
/// https://github.com/citation-style-language/schema/blob/c2142118a0265dfcf7d66aa3328251bedcc66af2/schemas/input/csl-data.json#L463-L498
struct CSLNameField
{
    string key;

    struct NameParts {
        @serdeIgnoreOutIf!empty
        string family;

        @serdeIgnoreOutIf!empty
        string given;

        @serdeKeys("dropping-particle")
        @serdeIgnoreOutIf!empty
        string dropping_particle;

        @serdeKeys("non-dropping-particle")
        @serdeIgnoreOutIf!empty
        string non_dropping_particle;

        @serdeIgnoreOutIf!empty
        string suffix;

        @serdeKeys("comma-suffix")
        @serdeIgnoreOutIf!empty
        string comma_suffix;

        @serdeKeys("static-ordering")
        @serdeIgnoreOutIf!empty
        string static_ordering;

        @serdeIgnoreOutIf!empty
        string literal;

        @serdeKeys("parse-names")
        @serdeIgnoreOutIf!empty
        string parse_names;
    }
    NameParts np;

    this(string family)
    {
        this.np.family = family;
    }
    this(string family, string given)
    {
        this.np.family = family;
        this.np.given = given;
    }
}

/// Definition:
/// https://github.com/citation-style-language/schema/blob/c2142118a0265dfcf7d66aa3328251bedcc66af2/schemas/input/csl-data.json#L505-L546
struct CSLDateField
{
    string key;

    struct DateParts {
        @serdeKeys("date-parts")
        @serdeIgnoreOutIf!empty
        string date_parts;

        @serdeIgnoreOutIf!empty
        string season;

        @serdeIgnoreOutIf!empty
        string circa;   // string, number, bool

        @serdeIgnoreOutIf!empty
        string literal;

        @serdeIgnoreOutIf!empty
        string raw;

        @serdeIgnoreOutIf!empty
        string edtf;
    }
    DateParts dp;

    this(string raw) { this.dp.raw = raw; }
}

alias CSLValue = Nullable!(CSLOrdinaryField, CSLNameField, CSLDateField);
    
CSLValue processTag(string tag, string value)
{
    if (tag == "AB") {
        stderr.writeln("Abstract (AB)");
        return cast(CSLValue) CSLOrdinaryField("abstract", value);
    }
    else if (tag == "PMID") {
        stderr.writeln("Pubmed ID (PMID)");
        return CSLValue(CSLOrdinaryField("note", format("PMID: %s", value)));
    }
    else if (tag == "PMC") {
        stderr.writeln("PubMed Central Identifier (PMC)");
        return CSLValue(CSLOrdinaryField("note", format("PMCID: %s", value)));
    }
    // Manuscript Identifier (MID)
    
    else if (tag == "TI") {
        stderr.writeln("Title (TI)");
        return CSLValue(CSLOrdinaryField("title", value));
    }
    else if (tag == "VI") {
        stderr.writeln("Volume (VI)");
        return CSLValue(CSLOrdinaryField("volume", value));
    }
    else if (tag == "IP") {
        stderr.writeln("Issue (IP)");
        return CSLValue(CSLOrdinaryField("issue", value));
    }
    else if (tag == "PG") {
        stderr.writeln("Pagination (PG)");
        return CSLValue(CSLOrdinaryField("page", value));
    }
    else if (tag == "DP") {
        stderr.writeln("Date of Publication (DP)");
        // return CSL "issued"
        // need to transform to ISO 8601 per CSL specs;
        // medline looks like YYYY Mon DD
        return CSLValue(CSLDateField(value));
    }
    else if (tag == "FAU") {
        stderr.writeln("Full Author (FAU)");
        // return CSL author: { ... } via some other transformer
        // TODO split name
        return CSLValue(CSLNameField(value));
    }
    else if (tag == "AU") {
        stderr.writeln("Author (AU)");
        // return CSL author: { ... } via some other transformer
        // TODO split name
        return CSLValue(CSLNameField(value));
    }
    // Affilitation (AD)
    else if (tag == "AUID") {
        stderr.writeln("Author Identifier (AUID)");
        // This would typically be an ORCID
        // CSL name-variable definition does not have designated place for author id
        // https://github.com/citation-style-language/schema/blob/c2142118a0265dfcf7d66aa3328251bedcc66af2/schemas/input/csl-data.json#L463-L498
        return CSLValue(CSLOrdinaryField("note", format("ORCID: %s", value)));
    }

    else if (tag == "LA") {
        stderr.writeln("Language (LA)");
        // return CSL "language"
        // TODO, MEDLINE/Pubmed uses 3 letter language code; does CSL specify 3 or 2 letter?a
        // https://www.nlm.nih.gov/bsd/language_table.html
        return CSLValue(CSLOrdinaryField("language", value));
    }

    else if (tag == "SI") {
        stderr.writeln("Secondary Source ID (SI)");
        // return CSL "note"
        return CSLValue(CSLOrdinaryField("note", value));
    }

    // (GR) Grant Number

    else if (tag == "PT") {
        stderr.writeln("Publication Type (PT)");
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
            stderr.writeln("Journal Article");
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

    // Date of Electronic Publication 	(DEP)
    
    else if (tag == "TA") {
        stderr.writeln("Title Abbreviation (TA)");
        // return CSL "container-title-short"
        return CSLValue(CSLOrdinaryField("container-title-short", value));
    }
    else if (tag == "JT") {
        stderr.writeln("Journal Title (JT)");
        // return CSL "container-title"
        return CSLValue(CSLOrdinaryField("container-title"));
    }
    // NLM Unique ID (JID)
    // Registry Number/EC Number (RN)
    // Comment in 	(CIN)

    else if (tag == "MH" || tag == "OT") {
        stderr.writeln("MeSH Terms or Other Term (OT)");
        // emit CSL "note"=
        return CSLValue(CSLOrdinaryField("note", value));
    }

    // various status date fields

    // Publication Status (PST)

    else if (tag == "AID") {
        stderr.writeln("Article Identifier (AID)");
        // if DOI, return CSL "DOI" , and strip trailing "[doi]"
        if (value[$-5 .. $] == "[doi]")
            return CSLValue(CSLOrdinaryField("DOI", value[0 .. $-5]));
        else {
            CSLValue ret;
            ret.nullify;
            return ret;
        }
    }

    else {
        stderr.writefln("Unprocessed tag: %s", tag);
        CSLValue ret;
        ret.nullify;
        return ret;
    }

    assert(0, "Tag matched without return");
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

/// TODO make lazy
auto medlineToCSL(R)(R range)
{
    CSLValue[] ret;

    foreach(row; range) {
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

    writeln(records);

}
