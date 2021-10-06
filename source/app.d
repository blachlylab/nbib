import std.stdio;
import std.range.primitives : empty;
import mir.algebraic;

struct CSLOrdinaryField
{
    string key;
    string value;
}

/// Definition:
/// https://github.com/citation-style-language/schema/blob/c2142118a0265dfcf7d66aa3328251bedcc66af2/schemas/input/csl-data.json#L463-L498
struct CSLNameField
{
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

/// Definition:
/// https://github.com/citation-style-language/schema/blob/c2142118a0265dfcf7d66aa3328251bedcc66af2/schemas/input/csl-data.json#L505-L546
struct CSLDateField
{
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

alias CSLValue = Nullable!(CSLOrdinaryField, CSLNameField, CSLDateField);
    
CSLValue processTag(const char[] tag, const char[] value)
{
    if (tag == "AB") {
        stderr.writeln("Abstract (AB)");
        // return CSL "abstract"
        return CSLOrdinaryField("abstract", value);
    }
    else if (tag == "PMID") {
        stderr.writeln("Pubmed ID (PMID)");
        // return CSL "note"="PMID: {}"
        return CSLOrdinaryField("note", format!("PMID: %s", value));
    }
    else if (tag == "PMC") {
        stderr.writeln("PubMed Central Identifier (PMC)");
        // return CSL "note"="PMC: {}"
        return CSLOrdinaryField("note", format!("PMCID: %s", value));
    }
    // Manuscript Identifier (MID)
    
    else if (tag == "TI") {
        stderr.writeln("Title (TI)");
        // return CSL "title"
    }
    else if (tag == "VI") {
        stderr.writeln("Volume (VI)");
        // return CSL "volume"
    }
    else if (tag == "IP") {
        stderr.writeln("Issue (IP)");
        // return CSL "issue"
    }
    else if (tag == "PG") {
        stderr.writeln("Pagination (PG)");
        // return CSL "page"
    }
    else if (tag == "DP") {
        stderr.writeln("Date of Publication");
        // return CSL "issued"
        // need to transform to ISO 8601 per CSL specs;
        // medline looks like YYYY Mon DD
    }
    else if (tag == "FAU") {
        stderr.writeln("Full Author (FAU)");
        // return CSL author: { ... } via some other transformer
    }
    else if (tag == "AU") {
        stderr.writeln("Author (AU)");
        // return CSL author: { ... } via some other transformer
    }
    else if (tag == "AD") {
        stderr.writeln("Affilitation (AD)");
        // ???
    }
    else if (tag == "AUID") {
        stderr.writeln("Author Identifier (AUID)");
        // This would typically be an ORCID
        // CSL name-variable definition does not have designated place for author id
        // https://github.com/citation-style-language/schema/blob/c2142118a0265dfcf7d66aa3328251bedcc66af2/schemas/input/csl-data.json#L463-L498
    }

    else if (tag == "LA") {
        stderr.writeln("Language (LA)");
        // return CSL "language"
        // TODO, MEDLINE/Pubmed uses 3 letter language code; does CSL specify 3 or 2 letter?a
        // https://www.nlm.nih.gov/bsd/language_table.html
    }

    else if (tag == "SI") {
        
        CSLstderr.writeln("Secondary Source ID (SI)");
        // return CSL "note"
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
            return CSLOrdinaryField("type", "article-journal");
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
        return CSLOrdinaryField("container-title-short", value);
    }
    else if (tag == "JT") {
        stderr.writeln("Journal Title (JT)");
        // return CSL "container-title"
        return CSLOrdinaryField("container-title");
    }
    // NLM Unique ID (JID)
    // Registry Number/EC Number (RN)
    // Comment in 	(CIN)

    else if (tag == "MH" || tag == "OT") {
        stderr.writeln("MeSH Terms or Other Term (OT)");
        // emit CSL "note"=
    }

    // various status date fields

    // Publication Status (PST)

    else if (tag == "AID") {
        stderr.writeln("Article Identifier (AID)");
        // if DOI, return CSL "DOI" , and strip trailing "[doi]"
    }

    else {
        stderr.writefln("Unprocessed tag: %s", tag);
        CSLValue ret;
        ret.nullify;
        return ret;
    }
}

void main()
{
}
