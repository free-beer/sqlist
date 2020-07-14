module sqlist.insert;

import std.algorithm : canFind, map;
import std.array : array, join;
import std.format : format;
import std.outbuffer : OutBuffer;
import sqlist;

/**
 * This class represents a SQL insert statement.
 */
class Insert : Statement {
    /**
     * Constructor.
     */
    this(string tableName) {
        _tableName = tableName;
    }

    /**
     * This property returns a list of the field names assigned as part of the
     * insert. The order of the field names will match the order in which the
     * fields were set within the statement.
     */
    @property string[] assignedFieldNames() const {
        return(_assignments.map!(e => e.fieldName.name).array);
    }

    /**
     * This function retrieves a list of the field assignments within an insert.
     */
    @property const(FieldAssignment)[] assignments() const {
        return(_assignments.array);
    }

    /**
     * Returns the name of the primary table in the statement.
     */
    @property string baseTableName() const {
        return(_tableName);
    }

    /**
     * Property getter for the list of fields that will be returned from the
     * update statement.
     */
    @property const(SQLField)[] returns() const {
        return(_returns.array);
    }

    /**
     * Returns the names of all tables involved in the statement. The base table
     * name will be first in this list.
     */
    @property string[] tableNames() const {
        return([_tableName]);
    }

    /**
     * Adds one of more fields to the returning list for the insert statement.
     * Field name strings are parsed into field names, assuming the base table
     * name as default.
     */
    Insert returning(string firstField, string[] otherFields...) {
        SQLField[] names = [FieldName.parse(firstField, baseTableName)];

        foreach(name; otherFields) {
            names ~= FieldName.parse(name, baseTableName);
        }
        return(returning(names[0], names[1..$]));
    }

    /**
     * Adds one of more fields to the returning list for the insert statement.
     */
    Insert returning(FieldName firstName, FieldName[] otherNames...) {
        SQLField[] fields = [firstName];

        foreach(name; otherNames) {
            fields ~= name;
        }

        return(returning(fields[0], fields[1..$]));
    }

    /**
     * Adds one of more fields to the returning list for the insert statement.
     */
    Insert returning(SQLField firstField, SQLField[] otherFields...) {
        if(!_returns.canFind(firstField)) {
            _returns ~= firstField;
        }
        foreach(field; otherFields) {
            _returns ~= field;
        }
        return(this);
    }

    /**
     * This function sets a field value assignment as part of the insert. Note
     * that the field name string will be parsed into a FieldName and, if this
     * has a table name anything other than the base table name, it will cause
     * an exception. The method returns the Insert instance to allow for
     * chaining.
     */
    Insert set(T)(string fieldName, T fieldValue) {
        return(set(FieldName.parse(fieldName, baseTableName), fieldValue));
    }

    /**
     * This function sets a field value assignment as part of the insert. Note
     * that, if the field name has a table name other that the base table name,
     * it will cause an exception. The method returns the Insert instance to
     * allow for chaining.
     */
    Insert set(T)(const FieldName fieldName, T fieldValue) {
        if(fieldName.table != "" && fieldName.table != baseTableName) {
            throw(new SQListException(format("Invalid field %s specified for insert into the %s table.", fieldName, baseTableName)));
        }
        _assignments ~= new FieldAssignment(fieldName, fieldValue);
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
        auto buffer      = new OutBuffer();
        auto tableName   = baseTableName;
        auto fieldNames  = assignedFieldNames;
        auto fieldValues = _assignments.map!(e => e.fieldValue.toRawSQL(settings));

        if(settings.quoteNames) {
            tableName  = format("\"%s\"", baseTableName);
            fieldNames = fieldNames.map!(e => format("\"%s\"", e)).array;
        }

        buffer.writef("insert into %s(%s) values(%s)", tableName, fieldNames.join(", "), fieldValues.join(", "));
        if(_returns.length > 0) {
            buffer.writef(" returning %s", _returns.map!(e => e.toSQL(settings)).join(", "));
        }

        return(buffer.toString());
    }

    /**
     * Generates the SQL relating to a Statement and returns a tuple containing
     * the SQL code and the associated values.
     */
    SQLOutput toSQL() const {
        auto settings = GeneratorSettings.defaults();
        return(toSQL(settings));
    }

    /**
     * Generates the SQL relating to a Statement and returns a tuple containing
     * the SQL code and the associated values.
     */
    SQLOutput toSQL(ref GeneratorSettings settings) const {
        SQLOutput output;
        auto      state = GeneratorState();

        output.sql  = toSQL(state, settings);
        output.data = state.values;
        return(output);
    }

    /**
     * Generates SQL code and returns the code plus a collection of the data
     * values needed to run the code. Values are replaced inline in the code
     * with number placeholders (e.g. $1, $2 etc.). Code is generated with a
     * specified set of configuration settings.
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
        auto buffer     = new OutBuffer();
        auto tableName  = baseTableName;
        auto fieldNames = assignedFieldNames;
        auto first      = true;

        if(settings.quoteNames) {
            tableName  = format("\"%s\"", baseTableName);
            fieldNames = fieldNames.map!(e => format("\"%s\"", e)).array;
        }

        buffer.writef("insert into %s(%s) values(", tableName, fieldNames.join(", "));
        foreach(assignment; _assignments) {
            if(first) {
                first = false;
            } else {
                buffer.writef(", ");
            }
            buffer.writef("%s", assignment.fieldValue.toSQL(state, settings));
        }
        buffer.writef(")");
        if(_returns.length > 0) {
            buffer.writef(" returning %s", _returns.map!(e => e.toSQL(settings)).join(", "));
        }

        return(buffer.toString());
    }

    FieldAssignment[] _assignments;
    string _tableName;
    SQLField[] _returns;
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
    auto insert = new Insert("users");
    assert(insert.assignments.length == 0);
    assert(insert.assignedFieldNames.length == 0);
    assert(insert.baseTableName == "users");
    assert(insert.returns.length == 0);
    assert(insert.tableNames == ["users"]);

    //--------------------------------------------------------------------------
    // set()
    //--------------------------------------------------------------------------
    insert.set("email", "joe.bloggs@nowhere.com");
    insert.set(FieldName.parse("age"), 27);
    assert(insert.assignments.length == 2);
    assert(insert.assignments[0].fieldName.table == "users");
    assert(insert.assignments[0].fieldName.name == "email");
    assert(insert.assignments[0].fieldValue.toRawSQL() == "'joe.bloggs@nowhere.com'");
    assert(insert.assignments[1].fieldName.table == "");
    assert(insert.assignments[1].fieldName.name == "age");
    assert(insert.assignments[1].fieldValue.toRawSQL() == "27");

    assertThrown!SQListException(insert.set("orders.id", 25));

    //--------------------------------------------------------------------------
    // returning() and returns
    //--------------------------------------------------------------------------
    auto quoted    = GeneratorSettings.defaults();
    auto qualified = GeneratorSettings.defaults();
    auto both      = GeneratorSettings.defaults();

    quoted.quoteNames      = true;
    both.quoteNames        = true;
    qualified.qualifyNames = true;
    both.qualifyNames      = true;

    insert.returning("users.id", "updated_at");
    assert(insert.returns.length == 2);
    assert(insert.returns[0].toSQL(qualified) == "users.id");
    assert(insert.returns[1].toSQL(qualified) == "users.updated_at");

    //--------------------------------------------------------------------------
    // toRawSQL()
    //--------------------------------------------------------------------------
    assert(insert.toRawSQL() == "insert into users(email, age) " ~
                                "values('joe.bloggs@nowhere.com', 27) " ~
                                "returning id, updated_at");
    assert(insert.toRawSQL(quoted) == "insert into \"users\"(\"email\", \"age\") " ~
                                      "values('joe.bloggs@nowhere.com', 27) " ~
                                      "returning \"id\", \"updated_at\"");
    assert(insert.toRawSQL(qualified) == "insert into users(email, age) " ~
                                         "values('joe.bloggs@nowhere.com', 27) " ~
                                         "returning users.id, users.updated_at");
    assert(insert.toRawSQL(both) == "insert into \"users\"(\"email\", \"age\") " ~
                                    "values('joe.bloggs@nowhere.com', 27) " ~
                                    "returning \"users\".\"id\", \"users\".\"updated_at\"");

    //--------------------------------------------------------------------------
    // toSQL()
    //--------------------------------------------------------------------------
    auto state = GeneratorState();

    assert(insert.toSQL(state) == "insert into users(email, age) " ~
                                  "values($1, $2) " ~
                                  "returning id, updated_at");
    assert(state.values.length == 2);
    assert(state.values[0].get!string() == "joe.bloggs@nowhere.com");
    assert(state.values[1].get!int() == 27);

    state = GeneratorState();
    assert(insert.toSQL(state, quoted) == "insert into \"users\"(\"email\", \"age\") " ~
                                      "values($1, $2) " ~
                                      "returning \"id\", \"updated_at\"");
    assert(state.values.length == 2);
    assert(state.values[0].get!string() == "joe.bloggs@nowhere.com");
    assert(state.values[1].get!int() == 27);

    state = GeneratorState();
    assert(insert.toSQL(state, qualified) == "insert into users(email, age) " ~
                                         "values($1, $2) " ~
                                         "returning users.id, users.updated_at");
    assert(state.values.length == 2);
    assert(state.values[0].get!string() == "joe.bloggs@nowhere.com");
    assert(state.values[1].get!int() == 27);

    state = GeneratorState();
    assert(insert.toSQL(state, both) == "insert into \"users\"(\"email\", \"age\") " ~
                                    "values($1, $2) " ~
                                    "returning \"users\".\"id\", \"users\".\"updated_at\"");
    assert(state.values.length == 2);
    assert(state.values[0].get!string() == "joe.bloggs@nowhere.com");
    assert(state.values[1].get!int() == 27);
}