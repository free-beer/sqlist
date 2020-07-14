module sqlist.field_comparison;

import std.format : format;
import sqlist;

class Operator : SQLGenerator {
    /**
     * Copy of the Operator class for an equals comparison.
     */
    const static EQUAL = new Operator("=");

    /**
     * Copy of the Operator class for a greater than comparison.
     */
    const static GREATER_THAN = new Operator(">");

    /**
     * Copy of the Operator class for a greater than or equal comparison.
     */
    const static GREATER_OR_EQUAL = new Operator(">=");

    /**
     * Copy of the Operator class for a less than comparison.
     */
    const static LESS_THAN = new Operator("<");

    /**
     * Copy of the Operator class for a less than or equal comparison.
     */
    const static LESS_OR_EQUAL = new Operator("<");

    /**
     * Copy of the Operator class for a like comparison.
     */
    const static LIKE = new Operator("like");

    /**
     * Copy of the Operator class for a less than comparison.
     */
    const static MATCH = new Operator("~");

    /**
     * Copy of the Operator class for a not equal comparison.
     */
    const static NOT_EQUAL = new Operator("!=");

    /**
     * Copy of the Operator class for a not like comparison.
     */
    const static NOT_LIKE = new Operator("not like");

    /**
     * Copy of the Operator class for a no match comparison.
     */
    const static NO_MATCH = new Operator("!~");

    /**
     * Copy of the Operator class for a less than comparison.
     */
    const static NOT_SIMILAR = new Operator("not similiar to");

    /**
     * Copy of the Operator class for a similar comparison.
     */
    const static SIMILAR = new Operator("similar to");

    private this(string operator) {
        _operator = operator;
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
        return(format(" %s ", _operator));
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

    private string _operator;
}

class FieldComparison : SQLGenerator {
    /**
     * Constructor.
     */
    this(T)(string fieldName, T fieldValue, const Operator operator=Operator.EQUAL) {
        _name     = FieldName.parse(fieldName);
        _operator = operator;
        _value    = new BaseSQLValue(fieldValue);
    }

    /**
     * Constructor.
     */
    this(T)(const FieldName fieldName, T fieldValue, const Operator operator=Operator.EQUAL) {
        _name     = new FieldName(fieldName.name, fieldName.table, fieldName.asName);
        _operator = operator;
        _value    = new BaseSQLValue(fieldValue);
    }

    /**
     * Property getter for the comparison field name.
     */
    @property const(FieldName) fieldName() const {
        return(_name);
    }

    /**
     * Property getter for the comparison operator.
     */
    @property const(Operator) operator() const {
        return(_operator);
    }

    /**
     * Property getter for the comparison value.
     */
    @property const(SQLValue) value() const {
        return(_value);
    }

    /**
     * This function creates a copy of a FieldComparison object.
     */
    FieldComparison dup() const {
        return(new FieldComparison(_name, _value.value, _operator));
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
        return(format("%s%s%s",
                      _name.toRawSQL(settings),
                      _operator.toRawSQL(settings),
                      _value.toRawSQL(settings)));
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
        return(format("%s%s%s",
                      _name.toSQL(state, settings),
                      _operator.toSQL(state, settings),
                      _value.toSQL(state, settings)));
    }

    /**
     * Overloading of the equality comparison operator.
     */
    override bool opEquals(const Object compare) const {
        auto rhs = cast(FieldComparison)compare;
        return(operator is rhs.operator &&
               fieldName == rhs.fieldName &&
               value == rhs.value);
    }

    private FieldName _name;
    private const(Operator) _operator;
    private BaseSQLValue _value;
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
    auto comparison = new FieldComparison("users.age", 21, Operator.GREATER_OR_EQUAL);
    assert(comparison.fieldName.asName == "");
    assert(comparison.fieldName.name == "age");
    assert(comparison.fieldName.table == "users");
    assert(comparison.value.toRawSQL() == "21");
    assert(comparison.operator == Operator.GREATER_OR_EQUAL);

    comparison = new FieldComparison(FieldName.parse("email"), "%@nowhere.com", Operator.LIKE);
    assert(comparison.fieldName.asName == "");
    assert(comparison.fieldName.name == "email");
    assert(comparison.fieldName.table == "");
    assert(comparison.value.toRawSQL() == "'%@nowhere.com'");
    assert(comparison.operator == Operator.LIKE);

    comparison = new FieldComparison("first_name", "Bob");
    assert(comparison.fieldName.asName == "");
    assert(comparison.fieldName.name == "first_name");
    assert(comparison.fieldName.table == "");
    assert(comparison.value.toRawSQL() == "'Bob'");
    assert(comparison.operator == Operator.EQUAL);

    //--------------------------------------------------------------------------
    // dup()
    //--------------------------------------------------------------------------
    auto copy = comparison.dup();
    assert(copy.fieldName == comparison.fieldName);
    assert(copy.fieldName !is comparison.fieldName);
    assert(copy.operator == comparison.operator);
    assert(copy.operator is comparison.operator);
    assert(copy.value == comparison.value);
    assert(copy.value !is comparison.value);

    //--------------------------------------------------------------------------
    // toRawSQL()
    //--------------------------------------------------------------------------
    auto quoted    = GeneratorSettings.defaults();
    auto qualified = GeneratorSettings(quoted);
    auto both      = GeneratorSettings(quoted);

    quoted.quoteNames      = true;
    qualified.qualifyNames = true;
    both.quoteNames        = true;
    both.qualifyNames      = true;

    comparison = new FieldComparison("first_name", "Bob");
    assert(comparison.toRawSQL() == "first_name = 'Bob'");
    assert(comparison.toRawSQL(quoted) == "\"first_name\" = 'Bob'");
    assert(comparison.toRawSQL(qualified) == "first_name = 'Bob'");
    assert(comparison.toRawSQL(both) == "\"first_name\" = 'Bob'");

    comparison = new FieldComparison("users.first_name", "Bob");
    assert(comparison.toRawSQL() == "first_name = 'Bob'");
    assert(comparison.toRawSQL(quoted) == "\"first_name\" = 'Bob'");
    assert(comparison.toRawSQL(qualified) == "users.first_name = 'Bob'");
    assert(comparison.toRawSQL(both) == "\"users\".\"first_name\" = 'Bob'");

    comparison = new FieldComparison("users.id", FieldName.parse("orders.user_id"));
    assert(comparison.toRawSQL() == "id = user_id");
    assert(comparison.toRawSQL(quoted) == "\"id\" = \"user_id\"");
    assert(comparison.toRawSQL(qualified) == "users.id = orders.user_id");
    assert(comparison.toRawSQL(both) == "\"users\".\"id\" = \"orders\".\"user_id\"");

    //--------------------------------------------------------------------------
    // toSQL()
    //--------------------------------------------------------------------------
    auto state = GeneratorState();

    comparison = new FieldComparison("first_name", "Bob");
    assert(comparison.toSQL(state, ) == "first_name = $1");
    assert(comparison.toSQL(state, quoted) == "\"first_name\" = $2");
    assert(comparison.toSQL(state, qualified) == "first_name = $3");
    assert(comparison.toSQL(state, both) == "\"first_name\" = $4");
    assert(state.length == 4);
    assert(state.values[0].get!string() == "Bob");
    assert(state.values[1].get!string() == "Bob");
    assert(state.values[2].get!string() == "Bob");
    assert(state.values[3].get!string() == "Bob");

    state = GeneratorState();
    comparison = new FieldComparison("users.age", 21, Operator.GREATER_OR_EQUAL);
    assert(comparison.toSQL(state, ) == "age >= $1");
    assert(comparison.toSQL(state, quoted) == "\"age\" >= $2");
    assert(comparison.toSQL(state, qualified) == "users.age >= $3");
    assert(comparison.toSQL(state, both) == "\"users\".\"age\" >= $4");
    assert(state.length == 4);
    assert(state.values[0].get!int() == 21);
    assert(state.values[1].get!int() == 21);
    assert(state.values[2].get!int() == 21);
    assert(state.values[3].get!int() == 21);

    state = GeneratorState();
    comparison = new FieldComparison("users.id", FieldName.parse("orders.user_id"));
    assert(comparison.toSQL(state) == "id = user_id");
    assert(comparison.toSQL(state, quoted) == "\"id\" = \"user_id\"");
    assert(comparison.toSQL(state, qualified) == "users.id = orders.user_id");
    assert(comparison.toSQL(state, both) == "\"users\".\"id\" = \"orders\".\"user_id\"");
    assert(state.length == 0);

    //--------------------------------------------------------------------------
    // Comparison
    //--------------------------------------------------------------------------
    comparison = new FieldComparison("first_name", "Bob");
    assert(comparison == new FieldComparison("first_name", "Bob"));
    assert(comparison != new FieldComparison("first_name", "Joe"));
    assert(comparison != new FieldComparison("surname", "Bob"));
    assert(comparison != new FieldComparison("first_name", "Bob", Operator.NOT_EQUAL));
}