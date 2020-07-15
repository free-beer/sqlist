module sqlist.sql_function;

import std.algorithm : map;
import std.array : join;
import std.format : format;
import std.string : strip;
import std.variant : Variant;
import sqlist;

/**
 * This class represents a call to a function within a SQL statement.
 */
class SQLFunction : SQLField {
    this(string name) {
        _name = name.strip();
        if(_name == "") {
            throw(new SQListException("Invalid name specified for SQLFunction. Function names cannot be blank."));
        }
    }

    /**
     * Property getter for the function name.
     */
    @property string name() const {
        return(_name);
    }

    /**
     * Property getter for the function parameters.
     */
    @property const(Variant)[] parameters() const {
        Variant[] parameters;

        foreach(parameter; _parameters) {
            Variant copy = parameter;
            parameters ~= copy;
        }
        return(parameters);
    }

    /**
     * This function adds an entry to the list of parameters for a SQLFunction
     * object.
     */
    SQLFunction add(T)(T value) {
        _parameters ~= Variant(new BaseSQLValue(value));
        return(this);
    }

    /**
     * This function adds a FieldName to the list of parameters for a
     * SQLFunction object.
     */
    SQLFunction add(T: FieldName)(T fieldName) {
        _parameters ~= Variant(fieldName);
        return(this);
    }

    /**
     * This function adds a SQLField to the list of parameters for a
     * SQLFunction object.
     */
    SQLFunction add(T: SQLField)(T field) {
        _parameters ~= Variant(field);
        return(this);
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
        return(toSQL(settings));
    }

    /**
     * Generate the SQL for a field given a set of preferences.
     */
    string toSQL(ref GeneratorSettings settings) const {
        auto parameters = _parameters.map!((parameter) {
                                               if(parameter.peek!(SQLField) !is null) {
                                                   return(parameter.get!SQLField().toSQL(settings));
                                               } else {
                                                   return(parameter.get!SQLGenerator().toRawSQL(settings));
                                               }
                                           }).join(", ");
        return(format("%s(%s)", _name, parameters));
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

    private string _name;
    private Variant[] _parameters;
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
    auto func = new SQLFunction("to_char");
    assert(func.name == "to_char");
    assert(func.parameters.length == 0);

    assertThrown!SQListException(new SQLFunction(""));

    //--------------------------------------------------------------------------
    // add()
    //--------------------------------------------------------------------------
    assert(func.add(FieldName.parse("orders.updated_at")) is func);
    func.add("YYYY-Mon-DD HH24:MI:SS.US");
    assert(func.parameters.length == 2);

    //--------------------------------------------------------------------------
    // toSQL(ref GeneratorSettings)
    //--------------------------------------------------------------------------
    auto settings = GeneratorSettings.defaults();
    auto quoted = GeneratorSettings.defaults();
    auto qualified = GeneratorSettings.defaults();

    quoted.quoteNames = true;
    qualified.qualifyNames = true;

    assert(func.toSQL(settings) == "to_char(updated_at, 'YYYY-Mon-DD HH24:MI:SS.US')");
    assert(func.toSQL(quoted) == "to_char(\"updated_at\", 'YYYY-Mon-DD HH24:MI:SS.US')");
    assert(func.toSQL(qualified) == "to_char(orders.updated_at, 'YYYY-Mon-DD HH24:MI:SS.US')");
}
