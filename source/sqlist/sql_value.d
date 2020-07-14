module sqlist.sql_value;

import std.conv : to;
import std.format : format;
import std.variant : Variant;
import sqlist;

interface SQLValue : SQLGenerator {
    /**
     * A property getter to test if a SQL value is null.
     */
    @property bool isNull() const;

    /**
     * Creates a new copy of an existing SQLValue.
     */
    SQLValue dup() const;

    /**
     * Mandate the overriding of the equality test operator for the SQLValue
     * interface.
     */
    bool opEquals(const Object compare) const;
}

class BaseSQLValue : SQLValue {
    /**
     * Constant containing the string version of the nil value.
     */
    enum NULL_TEXT = "null";

    /**
     * Constructor that creates an instance with a null value.
     */
    this() {
    }

    /**
     * Constructor that creates an instance with a specified value.
     */
    this(T)(T value) {
        _value = value;
    }

    /**
     * A property getter to test if a SQL value is null.
     */
    @property bool isNull() const {
        return(!_value.hasValue);
    }

    /**
     * Property getter for a Variant containing the internally held value.
     */
    @property Variant value() const {
        Variant v = _value;
        return(v);
    }

    /**
     * Creates a new copy of an existing SQLValue.
     */
    SQLValue dup() const {
        return(new BaseSQLValue(_value));
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
        if(_value.hasValue) {
            if(_value.peek!string() !is null) {
                return(format("'%s'", _value.get!string()));
            } else if(_value.convertsTo!SQLGenerator()) {
                return(_value.get!SQLGenerator().toRawSQL(settings));
            } else {
                Variant v = _value;
                return(v.toString());
            }
        } else {
            return(NULL_TEXT);
        }
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
        if(!isNull) {
            if(_value.convertsTo!SQLGenerator()) {
                return(_value.get!SQLGenerator().toSQL(state, settings));
            } else {
                state.add(_value);
                return(format("$%d", state.length));
            }
        } else {
            return(NULL_TEXT);
        }
    }

    /**
     * Overloading of the equals operator for the BaseSQLValue class.
     */
    override bool opEquals(const Object compare) const {
        auto rhs = cast(BaseSQLValue)compare;
        return(rhs !is null && _value == rhs._value);
    }

    private Variant _value;
}

//==============================================================================
// Unit Tests
//==============================================================================
unittest {
    import std.exception;
    import std.stdio;

    writeln("  Running unit tests for the ", __FILE__, " file.");

    //--------------------------------------------------------------------------
    // Construction
    //--------------------------------------------------------------------------
    auto value = new BaseSQLValue();
    assert(value.isNull);

    value = new BaseSQLValue(1234);
    assert(!value.isNull);

    value = new BaseSQLValue("Some text.");
    assert(!value.isNull);

    //--------------------------------------------------------------------------
    // Extraction Of The Underlying Value
    //--------------------------------------------------------------------------
    value = new BaseSQLValue(1234);
    assert(value.value.get!int() == 1234);

    value = new BaseSQLValue("Some text.");
    assert(value.value.get!string() == "Some text.");

    //--------------------------------------------------------------------------
    // toRawSQL()
    //--------------------------------------------------------------------------
    value = new BaseSQLValue();
    assert(value.toRawSQL() == "null");

    value = new BaseSQLValue(1234);
    assert(value.toRawSQL() == "1234");

    value = new BaseSQLValue("Test text!");
    assert(value.toRawSQL() == "'Test text!'");

    value = new BaseSQLValue(FieldName.parse("field_name"));
    assert(value.toRawSQL() == "field_name");

    //--------------------------------------------------------------------------
    // toSQL()
    //--------------------------------------------------------------------------
    GeneratorState state;

    value = new BaseSQLValue();
    assert(value.toSQL(state) == "null");
    assert(state.length == 0);

    value = new BaseSQLValue(1234);
    assert(value.toSQL(state) == "$1");
    assert(state.length == 1);
    assert(state.values[0].get!int() == 1234);

    value = new BaseSQLValue("Test text!");
    assert(value.toSQL(state) == "$2");
    assert(state.length == 2);
    assert(state.values[1].get!string() == "Test text!");

    value = new BaseSQLValue(FieldName.parse("field_name"));
    assert(value.toSQL(state) == "field_name");
    assert(state.length == 2);

    //--------------------------------------------------------------------------
    // Comparison
    //--------------------------------------------------------------------------
    value = new BaseSQLValue("text");
    assert(value == new BaseSQLValue("text"));
    assert(value != new BaseSQLValue(23));

    SQLValue other = value;
    assert(other == value);
    assert(other == new BaseSQLValue("text"));
    assert(other != new BaseSQLValue(23));
}
