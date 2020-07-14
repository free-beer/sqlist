module sqlist.field_name;

import std.format : format;
import std.regex : matchFirst, regex;
import std.string : strip;
import sqlist;

class FieldName : SQLField {
    /**
     * A constant for a regular expression pattern used to parse strings into
     * FieldName objects.
     */
    enum PARSE_PATTERN_1 = r"\s*([^\s.]+)\.([^\s.]+)\s+[A|a][S|s]\s+([^\s]+).*";

    /**
     * A constant for a regular expression pattern used to parse strings into
     * FieldName objects.
     */
    enum PARSE_PATTERN_2 = r"\s*([^\s]+)\s+[A|a][S|s]\s+([^\s]+).*";

    /**
     * A constant for a regular expression pattern used to parse strings into
     * FieldName objects.
     */
    enum PARSE_PATTERN_3 = r"\s*([^\s]+)\.([^\s]+).*";

    /**
     * Constructor.
     */
    this(string fieldName, string tableName="", string fieldAlias="") {
        if(fieldName.strip() == "") {
            throw(new SQListException("Invalid name specified for field. Field names cannot be blank."));
        }
        _fieldAlias = fieldAlias.strip();
        _fieldName  = fieldName.strip();
        _tableName  = tableName.strip();
    }

    /**
     * Property getter for the fields alias if it has one.
     */
    @property string asName() const {
        return(_fieldAlias);
    }

    /**
     * Property getter for the fields actual name.
     */
    @property string name() const {
        return(_fieldName);
    }

    /**
     * Property getter for the fields table name.
     */
    @property string table() const {
        return(_tableName);
    }

    /**
     * This function returns the field name suffixed with it's alias, if
     * available, and separated by the text ' as '.
     */
    string fieldNameWithAlias(bool quoteNames=false) const {
        auto fieldName  = (quoteNames ? format("\"%s\"", _fieldName) : _fieldName);
        if(_fieldAlias != "") {
            auto fieldAlias = (quoteNames ? format("\"%s\"", _fieldAlias) : _fieldAlias);
            return(format("%s as %s", fieldName, fieldAlias));
        } else {
            return(fieldName);
        }
    }

    /**
     * This function returns the field name prefixed with it's table name, if
     * available, and separated by a '.'.
     */
    string fieldNameWithTable(bool quoteNames=false) const {
        auto settings = GeneratorSettings.defaults();

        settings.quoteNames   = quoteNames;
        settings.qualifyNames = true;
        return((new FieldName(_fieldName, _tableName)).toRawSQL(settings));
    }

    /**
     * Generates SQL code and inlines any data values that are part of that
     * code. Code is generated with a default set of configuration settings.
     */
    string toRawSQL() const {
        return(toRawSQL(GeneratorSettings.defaults()));
    }

    /**
     * Generates SQL code and inlines any data values that are part of that
     * code. Code is generated with a specified set of configuration settings.
     */
    string toRawSQL(GeneratorSettings settings) const {
        if(settings.qualifyNames) {
            auto output = "";

            if(settings.quoteNames) {
                output = format("\"%s\"", _fieldName);
            } else {
                output = _fieldName;
            }

            if(_tableName != "") {
                if(settings.quoteNames) {
                    output = format("\"%s\".%s", _tableName, output);
                } else {
                    output = _tableName ~ "." ~ output;
                }
            }

            if(_fieldAlias != "") {
                if(settings.quoteNames) {
                    output = format("%s as \"%s\"", output, _fieldAlias);
                } else {
                    output = output ~ " as " ~ _fieldAlias;
                }
            }

            return(output);
        } else {
            if(settings.quoteNames) {
                return(format("\"%s\"", _fieldName));
            } else {
                return(_fieldName);
            }
        }
    }

    /**
     * Implementation of the toSQL() function mandated by the SQLField
     * interface.
     */
    string toSQL(ref GeneratorSettings settings) const {
        return(toRawSQL(settings));
    }

    /**
     * Generates SQL code and returns the code plus a collection of the data
     * values needed to run the code. Values are replaced inline in the code
     * with number placeholders (e.g. $1, $2 etc.). Code is generated with a
     * default set of configuration settings.
     */
    string toSQL(ref GeneratorState state) const {
        return(toSQL(state, GeneratorSettings.defaults()));
    }

    /**
     * Generates SQL code and returns the code plus a collection of the data
     * values needed to run the code. Values are replaced inline in the code
     * with number placeholders (e.g. $1, $2 etc.). Code is generated with a
     * specified set of configuration settings.
     */
    string toSQL(ref GeneratorState state, GeneratorSettings settings) const {
        return(toRawSQL(settings));
    }

    /**
     * An implementation of the toString() function for FieldNames.
     */
    override string toString() const {
        return(fieldNameWithTable());
    }

    /**
     * This function parses a string into a FieldName object. The function
     * accepts input in four possible formats which are...
     *
     *    table_name.field_name as field_alias
     *    field_name as field_alias
     *    table_name.field_name
     *    field_name
     *
     */
    static FieldName parse(string field, string defaultTableName="") {
        auto fieldAlias = "";
        auto fieldName  = "";
        auto tableName  = defaultTableName;
        auto captures   = field.matchFirst(regex(PARSE_PATTERN_1));

        if(captures.empty) {
            captures = field.matchFirst(regex(PARSE_PATTERN_2));
            if(captures.empty) {
                captures = field.matchFirst(regex(PARSE_PATTERN_3));
                if(!captures.empty) {
                    fieldName  = captures[2].strip();
                    tableName  = captures[1].strip();
                }
            } else {
                fieldAlias = captures[2].strip();
                fieldName  = captures[1].strip();
            }
        } else {
            fieldAlias = captures[3].strip();
            fieldName  = captures[2].strip();
            tableName  = captures[1].strip();
        }

        if(fieldName == "") {
            fieldName = field.strip();
        }

        return(new FieldName(fieldName, tableName, fieldAlias));
    }

    /**
     * Equals operator overload for the FieldName class. Note that field names
     * are equivalent if they refer to the same table and field - field alias
     * is not taken into account.
     */
    override bool opEquals(const Object compare) const {
        auto rhs = cast(FieldName)compare;
        return(rhs !is null && name == rhs.name && table == rhs.table);
    }

    /**
     * Equals operator overload for the FieldName class.
     */
    bool opEquals(string rhs) const {
        return(this == FieldName.parse(rhs));
    }

    private string _fieldAlias;
    private string _fieldName;
    private string _tableName;
}

//==============================================================================
// Unit Tests
//==============================================================================
unittest {
    import std.exception;
    import std.stdio;

    writeln("  Running unit tests for the ", __FILE__, " file.");

    //--------------------------------------------------------------------------
    // Construction & Base Properties
    //--------------------------------------------------------------------------
    auto name = new FieldName("field_name", "table_name", "field_alias");
    assert(name.asName == "field_alias");
    assert(name.name == "field_name");
    assert(name.table == "table_name");

    assertThrown!SQListException(new FieldName(""));

    //--------------------------------------------------------------------------
    // parse()
    //--------------------------------------------------------------------------
    assertNotThrown!SQListException(name = FieldName.parse("table_name.field_name as field_alias"));
    assert(name.asName == "field_alias");
    assert(name.name == "field_name");
    assert(name.table == "table_name");

    assertNotThrown!SQListException(name = FieldName.parse("field_name as field_alias"));
    assert(name.asName == "field_alias");
    assert(name.name == "field_name");
    assert(name.table == "");

    assertNotThrown!SQListException(name = FieldName.parse("table_name.field_name"));
    assert(name.asName == "");
    assert(name.name == "field_name");
    assert(name.table == "table_name");

    assertNotThrown!SQListException(name = FieldName.parse("field_name"));
    assert(name.asName == "");
    assert(name.name == "field_name");
    assert(name.table == "");

    assertNotThrown!SQListException(name = FieldName.parse("field_name", "table_name"));
    assert(name.asName == "");
    assert(name.name == "field_name");
    assert(name.table == "table_name");

    assertThrown!SQListException(FieldName.parse(""));

    //--------------------------------------------------------------------------
    // fieldNameWithAlias()
    //--------------------------------------------------------------------------
    name = FieldName.parse("email");
    assert(name.fieldNameWithAlias() == "email");
    assert(name.fieldNameWithAlias(true) == "\"email\"");

    name = FieldName.parse("users.email");
    assert(name.fieldNameWithAlias() == "email");
    assert(name.fieldNameWithAlias(true) == "\"email\"");

    name = FieldName.parse("users.email as address");
    assert(name.fieldNameWithAlias() == "email as address");
    assert(name.fieldNameWithAlias(true) == "\"email\" as \"address\"");

    //--------------------------------------------------------------------------
    // fieldNameWithTable()
    //--------------------------------------------------------------------------
    name = FieldName.parse("email");
    assert(name.fieldNameWithTable() == "email");
    assert(name.fieldNameWithTable(true) == "\"email\"");

    name = FieldName.parse("users.email");
    assert(name.fieldNameWithTable() == "users.email");
    assert(name.fieldNameWithTable(true) == "\"users\".\"email\"");

    name = FieldName.parse("users.email as address");
    assert(name.fieldNameWithTable() == "users.email");
    assert(name.fieldNameWithTable(true) == "\"users\".\"email\"");

    //------------------------------------------------------------------------
    // toRawSQL()
    //--------------------------------------------------------------------------
    auto settings = GeneratorSettings.defaults();

    name = new FieldName("field_name", "table_name", "field_alias");
    assert(name.toRawSQL() == "field_name");

    settings.qualifyNames = true;
    assert(name.toRawSQL(settings) == "table_name.field_name as field_alias");

    settings.quoteNames = true;
    assert(name.toRawSQL(settings) == "\"table_name\".\"field_name\" as \"field_alias\"");

    //--------------------------------------------------------------------------
    // Comparisons
    //--------------------------------------------------------------------------
    name = new FieldName("address", "users", "email");
    assert(name == FieldName.parse("users.address as email"));
    assert(name == "users.address as email");
    assert(name == FieldName.parse("users.address"));
    assert(name != FieldName.parse("orders.id"));
    assert(name == "users.address");
    assert(name != "orders.id");
}
