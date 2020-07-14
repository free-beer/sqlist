module sqlist.update;

import std.algorithm : canFind, map;
import std.array : array, join;
import std.format : format;
import std.outbuffer : OutBuffer;
import sqlist;

/**
 * This class represents a SQL update statement.
 */
class Update : Statement {
    /**
     * Constructor.
     */
    this(string tableName) {
        _tableName   = tableName;
        _whereClause = new WhereClause();
    }

    /**
     * This function retrieves a list of the field assignments within an update.
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
     * This function fetches the WhereClause for the Update statement.
     */
    @property WhereClause where() {
        return(_whereClause);
    }

    /**
     * This function fetches the WhereClause for the Update statement.
     */
    @property const(WhereClause) where() const {
        return(_whereClause);
    }

    /**
     * Adds one of more fields to the returning list for the update statement.
     * Field name strings are parsed into field names, assuming the base table
     * name as default.
     */
    Update returning(string firstField, string[] otherFields...) {
        SQLField[] names = [FieldName.parse(firstField, baseTableName)];

        foreach(name; otherFields) {
            names ~= FieldName.parse(name, baseTableName);
        }
        return(returning(names[0], names[1..$]));
    }

    /**
     * Adds one of more fields to the returning list for the update statement.
     */
    Update returning(FieldName firstName, FieldName[] otherNames...) {
        SQLField[] fields = [firstName];

        foreach(name; otherNames) {
            fields ~= name;
        }

        return(returning(fields[0], fields[1..$]));
    }

    /**
     * Adds one of more fields to the returning list for the update statement.
     */
    Update returning(SQLField firstField, SQLField[] otherFields...) {
        if(!_returns.canFind(firstField)) {
            _returns ~= firstField;
        }
        foreach(field; otherFields) {
            _returns ~= field;
        }
        return(this);
    }

    /**
     * This function sets a field value assignment as part of the update. Note
     * that the field name string will be parsed into a FieldName and, if this
     * has a table name anything other than the base table name, it will cause
     * an exception. The method returns the Update instance to allow for
     * chaining.
     */
    Update set(T)(string fieldName, T fieldValue) {
        return(set(FieldName.parse(fieldName, baseTableName), fieldValue));
    }

    /**
     * This function sets a field value assignment as part of the update. Note
     * that, if the field name has a table name other that the base table name,
     * it will cause an exception. The method returns the Update instance to
     * allow for chaining.
     */
    Update set(T)(const FieldName fieldName, T fieldValue) {
        if(fieldName.table != "" && fieldName.table != baseTableName) {
            throw(new SQListException(format("Invalid update field %s specified for update to the %s table.", fieldName, baseTableName)));
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
        auto buffer    = new OutBuffer();
        auto tableName = (settings.quoteNames ? format("\"%s\"", baseTableName) : baseTableName);

        buffer.writef("update %s set", tableName);
        for(auto i = 0; i < _assignments.length; i++) {
            auto fieldName = _assignments[i].fieldName.name;

            if(settings.quoteNames) {
                fieldName = format("\"%s\"", fieldName);
            }
            buffer.writef("%s%s = %s", (i == 0 ? " " : ", "), fieldName, _assignments[i].fieldValue.toRawSQL(settings));
        }
        if(!_whereClause.empty) {
            buffer.writef(" %s", _whereClause.toRawSQL(settings));
        }
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
        auto buffer    = new OutBuffer();
        auto tableName = (settings.quoteNames ? format("\"%s\"", baseTableName) : baseTableName);

        buffer.writef("update %s set", tableName);
        for(auto i = 0; i < _assignments.length; i++) {
            auto fieldName = _assignments[i].fieldName.name;

            if(settings.quoteNames) {
                fieldName = format("\"%s\"", fieldName);
            }
            buffer.writef("%s%s = %s", (i == 0 ? " " : ", "), fieldName, _assignments[i].fieldValue.toSQL(state, settings));
        }
        if(!_whereClause.empty) {
            buffer.writef(" %s", _whereClause.toSQL(state, settings));
        }
        if(_returns.length > 0) {
            buffer.writef(" returning %s", _returns.map!(e => e.toSQL(settings)).join(", "));
        }

        return(buffer.toString());
    }

    private FieldAssignment[] _assignments;
    private string _tableName;
    private WhereClause _whereClause;
    private SQLField[] _returns;
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
    auto update = new Update("orders");
    assert(update.assignments.length == 0);
    assert(update.baseTableName == "orders");
    assert(update.tableNames == ["orders"]);
    assert(update.where.length == 0);

    //--------------------------------------------------------------------------
    // set()
    //--------------------------------------------------------------------------
    update.set("quantity", 100);
    update.set(FieldName.parse("state"), "ACTIVE");
    update.set(FieldName.parse("orders.unit_price"), 123.34);

    assert(update.assignments.length == 3);
    assert(update.assignments[0].fieldName.table == "orders");
    assert(update.assignments[0].fieldName.name == "quantity");
    assert(update.assignments[0].fieldValue.toRawSQL() == "100");
    assert(update.assignments[1].fieldName.table == "");
    assert(update.assignments[1].fieldName.name == "state");
    assert(update.assignments[1].fieldValue.toRawSQL() == "'ACTIVE'");
    assert(update.assignments[2].fieldName.table == "orders");
    assert(update.assignments[2].fieldName.name == "unit_price");
    assert(update.assignments[2].fieldValue.toRawSQL() == "123.34");

    assertThrown!SQListException(update.set("users.name", "Bob"));

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

    update.returning("orders.id", "updated_at");
    assert(update.returns.length == 2);
    assert(update.returns[0].toSQL(qualified) == "orders.id");
    assert(update.returns[1].toSQL(qualified) == "orders.updated_at");

    //--------------------------------------------------------------------------
    // toRawSQL()
    //--------------------------------------------------------------------------
    update = new Update("orders").set("quantity", 100).set(FieldName.parse("state"), "ACTIVE").set(FieldName.parse("orders.unit_price"), 123.34);

    assert(update.toRawSQL() == "update orders " ~
                                "set quantity = 100, " ~
                                "state = 'ACTIVE', " ~
                                "unit_price = 123.34");
    assert(update.toRawSQL(quoted) == "update \"orders\" " ~
                                      "set \"quantity\" = 100, " ~
                                      "\"state\" = 'ACTIVE', " ~
                                      "\"unit_price\" = 123.34");
    assert(update.toRawSQL(qualified) == "update orders " ~
                                         "set quantity = 100, " ~
                                         "state = 'ACTIVE', " ~
                                         "unit_price = 123.34");
    assert(update.toRawSQL(both) == "update \"orders\" " ~
                                    "set \"quantity\" = 100, " ~
                                    "\"state\" = 'ACTIVE', " ~
                                    "\"unit_price\" = 123.34");

    update.where.and("orders.state", "PENDING").or("orders.size", 50, Operator.GREATER_THAN);
    assert(update.toRawSQL() == "update orders " ~
                                "set quantity = 100, " ~
                                "state = 'ACTIVE', " ~
                                "unit_price = 123.34 " ~
                                "where state = 'PENDING' " ~
                                "or size > 50");
    assert(update.toRawSQL(quoted) == "update \"orders\" " ~
                                      "set \"quantity\" = 100, " ~
                                      "\"state\" = 'ACTIVE', " ~
                                      "\"unit_price\" = 123.34 " ~
                                      "where \"state\" = 'PENDING' " ~
                                      "or \"size\" > 50");
    assert(update.toRawSQL(qualified) == "update orders " ~
                                         "set quantity = 100, " ~
                                         "state = 'ACTIVE', " ~
                                         "unit_price = 123.34 " ~
                                         "where orders.state = 'PENDING' " ~
                                         "or orders.size > 50");
    assert(update.toRawSQL(both) == "update \"orders\" " ~
                                    "set \"quantity\" = 100, " ~
                                    "\"state\" = 'ACTIVE', " ~
                                    "\"unit_price\" = 123.34 " ~
                                    "where \"orders\".\"state\" = 'PENDING' " ~
                                    "or \"orders\".\"size\" > 50");

    update.returning("id", "updated_at");
    assert(update.toRawSQL() == "update orders " ~
                                "set quantity = 100, " ~
                                "state = 'ACTIVE', " ~
                                "unit_price = 123.34 " ~
                                "where state = 'PENDING' " ~
                                "or size > 50 " ~
                                "returning id, updated_at");
    assert(update.toRawSQL(quoted) == "update \"orders\" " ~
                                      "set \"quantity\" = 100, " ~
                                      "\"state\" = 'ACTIVE', " ~
                                      "\"unit_price\" = 123.34 " ~
                                      "where \"state\" = 'PENDING' " ~
                                      "or \"size\" > 50 " ~
                                      "returning \"id\", \"updated_at\"");
    assert(update.toRawSQL(qualified) == "update orders " ~
                                         "set quantity = 100, " ~
                                         "state = 'ACTIVE', " ~
                                         "unit_price = 123.34 " ~
                                         "where orders.state = 'PENDING' " ~
                                         "or orders.size > 50 " ~
                                         "returning orders.id, orders.updated_at");
    assert(update.toRawSQL(both) == "update \"orders\" " ~
                                    "set \"quantity\" = 100, " ~
                                    "\"state\" = 'ACTIVE', " ~
                                    "\"unit_price\" = 123.34 " ~
                                    "where \"orders\".\"state\" = 'PENDING' " ~
                                    "or \"orders\".\"size\" > 50 " ~
                                    "returning \"orders\".\"id\", \"orders\".\"updated_at\"");

    //--------------------------------------------------------------------------
    // toSQL()
    //--------------------------------------------------------------------------
    auto state = GeneratorState();

    update = new Update("orders").set("quantity", 100).set(FieldName.parse("state"), "ACTIVE").set(FieldName.parse("orders.unit_price"), 123.34);

    assert(update.toSQL(state) == "update orders " ~
                                  "set quantity = $1, " ~
                                  "state = $2, " ~
                                  "unit_price = $3");
    assert(state.values.length == 3);
    assert(state.values[0].get!int() == 100);
    assert(state.values[1].get!string() == "ACTIVE");
    assert(state.values[2].get!double() == 123.34);

    state = GeneratorState();
    assert(update.toSQL(state, quoted) == "update \"orders\" " ~
                                          "set \"quantity\" = $1, " ~
                                          "\"state\" = $2, " ~
                                          "\"unit_price\" = $3");
    assert(state.values.length == 3);
    assert(state.values[0].get!int() == 100);
    assert(state.values[1].get!string() == "ACTIVE");
    assert(state.values[2].get!double() == 123.34);

    state = GeneratorState();
    assert(update.toSQL(state, qualified) == "update orders " ~
                                             "set quantity = $1, " ~
                                             "state = $2, " ~
                                             "unit_price = $3");
    assert(state.values.length == 3);
    assert(state.values[0].get!int() == 100);
    assert(state.values[1].get!string() == "ACTIVE");
    assert(state.values[2].get!double() == 123.34);

    state = GeneratorState();
    assert(update.toSQL(state, both) == "update \"orders\" " ~
                                        "set \"quantity\" = $1, " ~
                                        "\"state\" = $2, " ~
                                        "\"unit_price\" = $3");
    assert(state.values.length == 3);
    assert(state.values[0].get!int() == 100);
    assert(state.values[1].get!string() == "ACTIVE");
    assert(state.values[2].get!double() == 123.34);


    update.where.and("orders.state", "PENDING").or("orders.size", 50, Operator.GREATER_THAN);
    state = GeneratorState();
    assert(update.toSQL(state) == "update orders " ~
                                  "set quantity = $1, " ~
                                  "state = $2, " ~
                                  "unit_price = $3 " ~
                                  "where state = $4 " ~
                                  "or size > $5");
    assert(state.values.length == 5);
    assert(state.values[0].get!int() == 100);
    assert(state.values[1].get!string() == "ACTIVE");
    assert(state.values[2].get!double() == 123.34);
    assert(state.values[3].get!string() == "PENDING");
    assert(state.values[4].get!int() == 50);

    state = GeneratorState();
    assert(update.toSQL(state, quoted) == "update \"orders\" " ~
                                          "set \"quantity\" = $1, " ~
                                          "\"state\" = $2, " ~
                                          "\"unit_price\" = $3 " ~
                                          "where \"state\" = $4 " ~
                                          "or \"size\" > $5");
    assert(state.values.length == 5);
    assert(state.values[0].get!int() == 100);
    assert(state.values[1].get!string() == "ACTIVE");
    assert(state.values[2].get!double() == 123.34);
    assert(state.values[3].get!string() == "PENDING");
    assert(state.values[4].get!int() == 50);

    state = GeneratorState();
    assert(update.toSQL(state, qualified) == "update orders " ~
                                             "set quantity = $1, " ~
                                             "state = $2, " ~
                                             "unit_price = $3 " ~
                                             "where orders.state = $4 " ~
                                             "or orders.size > $5");
    assert(state.values.length == 5);
    assert(state.values[0].get!int() == 100);
    assert(state.values[1].get!string() == "ACTIVE");
    assert(state.values[2].get!double() == 123.34);
    assert(state.values[3].get!string() == "PENDING");
    assert(state.values[4].get!int() == 50);

    state = GeneratorState();
    assert(update.toSQL(state, both) == "update \"orders\" " ~
                                        "set \"quantity\" = $1, " ~
                                        "\"state\" = $2, " ~
                                        "\"unit_price\" = $3 " ~
                                        "where \"orders\".\"state\" = $4 " ~
                                        "or \"orders\".\"size\" > $5");
    assert(state.values.length == 5);
    assert(state.values[0].get!int() == 100);
    assert(state.values[1].get!string() == "ACTIVE");
    assert(state.values[2].get!double() == 123.34);
    assert(state.values[3].get!string() == "PENDING");
    assert(state.values[4].get!int() == 50);

    //--------------------------------------------------------------------------
    // toSQL() [Returns SQLOutput]
    //--------------------------------------------------------------------------
    auto output = update.toSQL();

    assert(output.data.length == 5);
    assert(output.data[0].get!int() == 100);
    assert(output.data[1].get!string() == "ACTIVE");
    assert(output.data[2].get!double() == 123.34);
    assert(output.data[3].get!string() == "PENDING");
    assert(output.data[4].get!int() == 50);
    state = GeneratorState();
    assert(output.sql == update.toSQL(state));

    output = update.toSQL(quoted);
    assert(output.data.length == 5);
    assert(output.data[0].get!int() == 100);
    assert(output.data[1].get!string() == "ACTIVE");
    assert(output.data[2].get!double() == 123.34);
    assert(output.data[3].get!string() == "PENDING");
    assert(output.data[4].get!int() == 50);
    state = GeneratorState();
    assert(output.sql == update.toSQL(state, quoted));

    output = update.toSQL(qualified);
    assert(output.data.length == 5);
    assert(output.data[0].get!int() == 100);
    assert(output.data[1].get!string() == "ACTIVE");
    assert(output.data[2].get!double() == 123.34);
    assert(output.data[3].get!string() == "PENDING");
    assert(output.data[4].get!int() == 50);
    state = GeneratorState();
    assert(output.sql == update.toSQL(state, qualified));

    output = update.toSQL(both);
    assert(output.data.length == 5);
    assert(output.data[0].get!int() == 100);
    assert(output.data[1].get!string() == "ACTIVE");
    assert(output.data[2].get!double() == 123.34);
    assert(output.data[3].get!string() == "PENDING");
    assert(output.data[4].get!int() == 50);
    state = GeneratorState();
    assert(output.sql == update.toSQL(state, both));
}