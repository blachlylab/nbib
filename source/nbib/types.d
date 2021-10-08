module nbib.types;

import std.array;
import std.string : strip, stripRight;
import std.stdio;
import std.range.primitives : empty;
import mir.algebraic;
import asdf;

/// CSL item record
///
/// Serialization to JSON is implemented manually to keep tag: value at top level (non-nested)
///
/// TODO: Inject "id" field since we don't get one from MEDLINE/Pubmed format, and is required
///
/// Reference: https://citeproc-js.readthedocs.io/en/latest/csl-json/markup.html
/// Reference: https://github.com/citation-style-language/schema/blob/master/schemas/input/csl-data.json
struct CSLItem
{
    CSLOrdinaryField[] fields;
    CSLNameField[] names;
    CSLDateField[] dates;

    // Custom serialization needed to flatten structure
    void serialize(S)(ref S serializer) const
    {
        auto o = serializer.structBegin();

            // Ordinary fields
            foreach(f; this.fields) {
                serializer.putKey(f.key);
                serializer.putValue(f.value);
            }

            // names
            serializer.putKey("author");
            auto state1 = serializer.arrayBegin();
                foreach(n; this.names) {
                    serializer.elemBegin();
                    serializer.serializeValue(n.np);
                }
            serializer.arrayEnd(state1);

        serializer.structEnd(o);
    }

    string toString() const
    {
        return serializeToJson(this);
    }
}
unittest
{
    CSLItem item;
    item.fields = [ CSLOrdinaryField("key1", "value1"),
                    CSLOrdinaryField("key2", "value2") ];
    item.names = [ CSLNameField("author", "Blachly, James S"),
                    CSLNameField("author", "Byrd, John C")];
    writeln(item.serializeToJsonPretty);

    assert(item.serializeToJson == `{"key1":"value1","key2":"value2","author":[{"family":"Blachly","given":"James S"},{"family":"Byrd","given":"John C"}]}`);


}

struct CSLOrdinaryField
{
    string key;
    string value;

    void serialize(S)(ref S serializer) const
    {
        auto o = serializer.structBegin();
        serializer.putKey(this.key);
        serializer.putValue(value);
        serializer.structEnd(o);
    }

    string toString() const
    {
        return serializeToJson(this);
    }
}

/// Definition:
/// https://github.com/citation-style-language/schema/blob/c2142118a0265dfcf7d66aa3328251bedcc66af2/schemas/input/csl-data.json#L463-L498
struct CSLNameField
{
    string key;
    
    // "Full" author, editor, etc. name; in MEDLINE/Pubmed format
    // corresponds to "FAU" or "FED"
    bool full;

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

    this(string nametype, string name)
    {
        this.key = nametype;

        // TODO: this could be made more sophiticated by detecting
        // dropping participles like Dr. and Rev., etc., and suffixes like Jr., PhD., etc.
        // which I would do with a separate function.
        auto name_parts = name.split(",");
        if (name_parts.length == 1)
            this.np.family = name.strip;
        else if (name_parts.length == 2) {
            this.full = true;
            this.np.family = name_parts[0].strip;
            this.np.given = name_parts[1].strip;
        }
        else {
            stderr.writefln("Too many name parts: %s", name);
            this.np.family = name.strip;
        }   
    }
    
    void serialize(S)(ref S serializer) const
    {
        auto o = serializer.structBegin();
        serializer.putKey(this.key);
        serializer.serializeValue(this.np);
        serializer.structEnd(o);
    }

    string toString() const
    {
        return serializeToJson(this);
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
    
