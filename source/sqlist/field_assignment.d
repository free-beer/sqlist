module sqlist.field_assignment;

import std.format : format;
import sqlist;

class FieldAssignment : SQLGenerator {
    /**
     * Constructor. The field name specified will be parsed into a FieldName
     * object (see FieldName.parse() for details).
     */
    this(T)(string fieldName, T fieldValue) {
        _name  = FieldName.parse(fieldName);
        _value = new BaseSQLValue(fieldValue);
    }

    /**
     * Constructor. The field name specified will be copied into the new object.
     */
    this(T)(const FieldName fieldName, T fieldValue) {
        _name  = new FieldName(fieldName.name, fieldName.table, fieldName.asName);
        _value = new BaseSQLValue(fieldValue);
    }

    /**
     * Property getter for the assignment field name.
     */
    @property const(FieldName) fieldName() const {
        return(_name);
    }

    /**
     * Property getter for the assignment field value.
     */
    @property const(SQLValue) fieldValue() const {
        return(_value);
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
        return(format("%s = %s", formatFieldName(settings), _value.toRawSQL(settings)));
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
        state.add(_value.value);
        return(format("%s = $%d", formatFieldName(settings), state.length));
    }

    /**
     * Private function used internally by the class to format the field name
     * for SQL output.
     */
    private string formatFieldName(ref GeneratorSettings settings) const {
        if(settings.quoteNames) {
            return(format("\"%s\"", _name.name));
        } else {
            return(_name.name);
        }
    }

    private FieldName _name;
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
    auto assignment = new FieldAssignment("users.email", "someone@nowhere.com");
    assert(assignment.fieldName.asName == "");
    assert(assignment.fieldName.name == "email");
    assert(assignment.fieldName.table == "users");
    assert(assignment.fieldValue.toRawSQL() == "'someone@nowhere.com'");

    assignment = new FieldAssignment("order_lines.quantity", 321);
    assert(assignment.fieldName.asName == "");
    assert(assignment.fieldName.name == "quantity");
    assert(assignment.fieldName.table == "order_lines");
    assert(assignment.fieldValue.toRawSQL() == "321");

    assignment = new FieldAssignment(FieldName.parse("first_name"), "Bob");
    assert(assignment.fieldName.asName == "");
    assert(assignment.fieldName.name == "first_name");
    assert(assignment.fieldName.table == "");
    assert(assignment.fieldValue.toRawSQL() == "'Bob'");

    //--------------------------------------------------------------------------
    // toRawSQL()
    //--------------------------------------------------------------------------
    auto settings = GeneratorSettings.defaults();

    settings.qualifyNames = true;
    assignment = new FieldAssignment("users.address as email", "someone@nowhere.com");
    assert(assignment.toRawSQL() == "address = 'someone@nowhere.com'");
    assert(assignment.toRawSQL(settings) == "address = 'someone@nowhere.com'");

    assignment = new FieldAssignment("quantity", 1010.25);
    assert(assignment.toRawSQL() == "quantity = 1010.25");
    assert(assignment.toRawSQL(settings) == "quantity = 1010.25");

    settings.quoteNames = true;
    assignment = new FieldAssignment("users.address as email", "someone@nowhere.com");
    assert(assignment.toRawSQL(settings) == "\"address\" = 'someone@nowhere.com'");

    //--------------------------------------------------------------------------
    // toSQL()
    //--------------------------------------------------------------------------
    auto state = GeneratorState();

    settings              = GeneratorSettings.defaults();
    settings.qualifyNames = true;

    assignment = new FieldAssignment("users.address as email", "someone@nowhere.com");
    assert(assignment.toSQL(state) == "address = $1");
    assert(state.length == 1);
    assert(state.values[0].get!string() == "someone@nowhere.com");
    assert(assignment.toSQL(state, settings) == "address = $2");
    assert(state.length == 2);
    assert(state.values[1].get!string() == "someone@nowhere.com");

    assignment = new FieldAssignment("quantity", 1010.25);
    assert(assignment.toSQL(state) == "quantity = $3");
    assert(state.length == 3);
    assert(state.values[2].get!double() == 1010.25);
    assert(assignment.toSQL(state, settings) == "quantity = $4");
    assert(state.length == 4);
    assert(state.values[3].get!double() == 1010.25);

    settings.quoteNames = true;
    assignment = new FieldAssignment("users.address as email", "someone@nowhere.com");
    assert(assignment.toSQL(state, settings) == "\"address\" = $5");
}
