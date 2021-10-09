module nbib.types;

import std.array;
import std.string : strip, stripRight;
import std.stdio;
import std.range.primitives : empty;
import mir.algebraic;
import asdf;


/// CSL item record
///
/// Tags and values are stored in one of three arrays, according to whether they are ordinary, name, or date.
/// Serialization to JSON is implemented manually to keep contained `tag: value` at top level (non-nested)
/// A few transformations are made:
///     (1) `id` is injected (and any existing id, which shouldn't happen, is ignored)
///     (2) name field tags are aggregated and grouped by type (author, editor, etc.)
///     (3) ???
///
/// The end result should be semantically-correct CSL-JSON
///
/// Reference: https://citeproc-js.readthedocs.io/en/latest/csl-json/markup.html
/// Reference: https://github.com/citation-style-language/schema/blob/master/schemas/input/csl-data.json
struct CSLItem
{
    CSLOrdinaryField[] fields;
    CSLNameField[] names;
    CSLDateField[] dates;

    /// Identify unique keys used in name field type records
    private auto nameTypes() const
    {
        import std.algorithm.sorting : sort;
        import std.algorithm.iteration : map, uniq;
        // i hate that .dup is necessary but apparently the const (from struct) cascades
        // and we end up with const(string[]), which can't be sorted mutably *eyeroll*
        return this.names.map!(a => a.key).array.dup.sort.uniq;
    }

    /// Custom serialization
    ///     - inject `id`
    ///     - flatten ordinary fields
    ///     - aggegate and group by name type
    ///     - aggregate and group by date type (TODO: shouldn't be duplicates?)
    void serialize(S)(ref S serializer) const
    {
        import std.algorithm : filter;
        import std.format : format;

        auto state0 = serializer.structBegin();

            // Inject id, one of the only two required fields in CSL (other being `type`)
            serializer.putKey("id");
            serializer.putValue(format("nbib-%x", this.hashOf));

            // Ordinary fields
            foreach(f; this.fields) {
                if (f.key == "id") continue;    // already injected id
                //serializer.putKey(f.key);
                //serializer.putValue(f.value);
                serializer.serializeValue(f);   // OK if `f` doesn't emit structBegin/End
            }

            // names
            auto types = this.nameTypes;
            foreach(t; types) {
                serializer.putKey(t);   // e.g. "author"; "editor"
                auto state1 = serializer.arrayBegin();
                auto matchingNames = this.names.filter!(a => a.key == t);
                foreach(n; matchingNames) {
                    serializer.elemBegin();
                    serializer.serializeValue(n.np);
                }
                serializer.arrayEnd(state1);
            }

            // dates (TODO)

        serializer.structEnd(state0);
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
                    CSLNameField("editor", "Grever, Michael"),  // purposefully out of order
                    CSLNameField("author", "Byrd, John C")];
    
    writeln(item.serializeToJsonPretty);
    writeln(item.serializeToJson);

    writefln("hashOf: %x", item.hashOf);

    assert(item.serializeToJson ==
        `{"id":"nbib-c1ad8b2b8309f124","key1":"value1","key2":"value2","author":[{"family":"Blachly","given":"James S"},{"family":"Byrd","given":"John C"}],"editor":[{"family":"Grever","given":"Michael"}]}`);

}

/// CSL-JSON value
///
/// Specification defines them as ordinary fields, name fields, or date fields
/// We additionally allow None/null as signal for our conversion program taht
/// either something went wrong or that a tag was ignored in conversion
alias CSLValue = Nullable!(CSLOrdinaryField, CSLNameField, CSLDateField);

/// Ordinary field: key = value
struct CSLOrdinaryField
{
    string key;
    string value;

    void serialize(S)(ref S serializer) const
    {
        // Note that I purposefully OMIT structBegin/structEnd
        // now, we can use this object's serialization from containing objects
        // without creating an extra nsted layer, which has the effect of "flattening"
        serializer.putKey(this.key);
        serializer.putValue(value);
    }

    string toString() const
    {
        return serializeToJson(this);
    }
}
unittest
{
    auto f = CSLOrdinaryField("xyzzy", "magic");
    writefln("CSLOrdinaryField: %s", f);
    assert( f.serializeToJson == `"xyzzy":"magic"` );
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

    
