module sqlist.query;

import std.algorithm : canFind, map;
import std.array : array, join;
import std.format : format;
import std.outbuffer : OutBuffer;
import sqlist;

/**
 * This class represents a SQL query (select) statement.
 */
class Query : Statement {
    this(string baseTableName) {
        _baseTable   = baseTableName;
        _fromClause  = new FromClause(_baseTable);
        _whereClause = new WhereClause();
    }
    /**
     * Returns the name of the primary table in the statement. For selects this
     * will be the first table in the from list. For inserts, updates and
     * deletes this will be the name of the target table.
     */
    @property string baseTableName() const {
        return(_baseTable);
    }

    /**
     * A property getter for the current limit setting for the query. A limit
     * of less than 1 indicates no limit being applied.
     */
    @property ulong limit() const {
        return(_limit);
    }

    /**
     * Property setter for the query limit setting.
     */
    @property void limit(ulong setting) {
        _limit = setting;
    }

    /**
     * A property getter for the current offset setting for the query. An offset
     * of less than 1 indicates no offset being applied.
     */
    @property ulong offset() const {
        return(_offset);
    }

    /**
     * Property setter for the query offset setting.
     */
    @property void offset(ulong setting) {
        _offset = setting;
    }

    /**
     * Property getter for the list of order by fields on the query.
     */
    @property const(SQLField)[] orderByFields() const {
        return(_orderBy.array);
    }

    /**
     * Returns the names of all tables involved in the statement. The base table
     * name will be first in this list.
     */
    @property string[] tableNames() const {
        string[] names = [_baseTable];

        foreach(name; _fromClause.tableNames) {
            if(!names.canFind(name)) {
                names ~= name;
            }
        }
        return(names);
    }

    /**
     * Retrieves the FromClause associated with the query.
     */
    @property FromClause from() {
        return(_fromClause);
    }

    /**
     * Retrieves the FromClause associated with the query.
     */
    @property const(FromClause) from() const {
        return(_fromClause);
    }

    /**
     * This function returns a list of the fields that are selected as part of
     * the query.
     */
    @property const(SQLField)[] selections() const {
        return(_selections.array);
    }

    /**
     * Retrieves the WhereClause associated with the query.
     */
    @property WhereClause where() {
        return(_whereClause);
    }

    /**
     * Retrieves the WhereClause associated with the query.
     */
    @property const(WhereClause) where() const {
        return(_whereClause);
    }

    /**
     * This function adds one or more field to the order by clause for the
     * query. Note that strings will be parsed to field names using the
     * base table name as the default table.
     */
    Query orderBy(string firstField, string[] otherFields...) {
        SQLField[] fields = [FieldName.parse(firstField, baseTableName)];

        foreach(name; otherFields) {
            fields ~= FieldName.parse(name, baseTableName);
        }
        return(orderBy(fields[0], fields[1..$]));
    }

    /**
     * This function adds one or more field to the order by clause for the
     * query.
     */
    Query orderBy(FieldName firstField, FieldName[] otherFields...) {
        SQLField[] fields = [firstField];

        foreach(field; otherFields) {
            fields ~= field;
        }
        return(orderBy(fields[0], fields[1..$]));
    }

    /**
     * This function adds one or more field to the order by clause for the
     * query.
     */
    Query orderBy(SQLField firstField, SQLField[] otherFields...) {
        if(!_orderBy.canFind(firstField)) {
            _orderBy ~= firstField;
        }

        foreach(field; otherFields) {
            if(!_orderBy.canFind(field)) {
                _orderBy ~= field;
            }
        }
        return(this);
    }

    /**
     * Adds fields to the list to be selected by the query. Note that the
     * strings passed in will be parsed to field names, with the base table
     * name actings as their default table name if it is not explicitly
     * specified.
     */
    Query select(string firstName, string[] otherNames...) {
        auto        first  = FieldName.parse(firstName, baseTableName);
        FieldName[] others;

        foreach(name; otherNames) {
            others ~= FieldName.parse(name, baseTableName);
        }

        return(select(first, others));
    }

    Query select(FieldName firstName, FieldName[] otherNames...) {
        SQLField[] fields;

        foreach(name; otherNames) {
            fields ~= name;
        }
        return(select(firstName, fields));
    }

    /**
     * Adds fields to the list to be selected by the query.
     */
    Query select(SQLField firstField, SQLField[] otherFields...) {
        if(!_selections.canFind(firstField)) {
            _selections ~= firstField;
        }
        foreach(field; otherFields) {
            if(!_selections.canFind(field)) {
                _selections ~= field;
            }
        }
        return(this);
    }

    /**
     * Generates SQL code and inlines any data values that are part of that
     * code. Code is generated with a default set of configuration settings.
     */
    string toRawSQL() const {
        auto settings = GeneratorSettings.defaults();
        return(toRawSQL(settings));
    }

    /**
     * Generates SQL code and inlines any data values that are part of that
     * code. Code is generated with a specified set of configuration settings.
     */
    string toRawSQL(GeneratorSettings settings) const {
        auto buffer = new OutBuffer();
        
        buffer.writef("select %s %s", selectionsToSQL(settings), _fromClause.toRawSQL(settings));
        if(_whereClause.length > 0) {
            buffer.writef(" %s", _whereClause.toRawSQL(settings));
        }
        if(_orderBy.length > 0) {
            buffer.writef(" order by %s", _orderBy.map!(e => e.toRawSQL(settings)).join(", "));
        }
        if(_offset > 0) {
            buffer.writef(" offset %d", _offset);
        }
        if(_limit > 0) {
            buffer.writef(" limit %d", _limit);
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
        SQLOutput      output;
        GeneratorState state;

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
        auto settings = GeneratorSettings.defaults();
        return(toSQL(state, settings));
    }

    /**
     * Generates SQL code and returns the code plus a collection of the data
     * values needed to run the code. Values are replaced inline in the code
     * with number placeholders (e.g. $1, $2 etc.). Code is generated with a
     * specified set of configuration settings.
     */
    string toSQL(ref GeneratorState state, GeneratorSettings settings) const {
        auto buffer = new OutBuffer();
        
        buffer.writef("select %s %s", selectionsToSQL(settings), _fromClause.toSQL(state, settings));
        if(_whereClause.length > 0) {
            buffer.writef(" %s", _whereClause.toSQL(state, settings));
        }
        if(_orderBy.length > 0) {
            buffer.writef(" order by %s", _orderBy.map!(e => e.toRawSQL(settings)).join(", "));
        }
        if(_offset > 0) {
            buffer.writef(" offset %d", _offset);
        }
        if(_limit > 0) {
            buffer.writef(" limit %d", _limit);
        }

        return(buffer.toString());
    }

    /**
     * Class internal function used to generate the SQL for the list of selected
     * fields.
     */
    private string selectionsToSQL(ref GeneratorSettings settings) const {
        if(_selections.length == 0) {
            if(settings.quoteNames) {
                return(format("\"%s\".*", baseTableName));
            } else {
                return(format("%s.*", baseTableName));
            }
        } else {
            return(_selections.map!(e => e.toSQL(settings)).join(", "));
        }
    }

    private string      _baseTable;
    private FromClause  _fromClause;
    private ulong       _limit;
    private ulong       _offset;
    private SQLField[]  _orderBy;
    private SQLField[]  _selections;
    private WhereClause _whereClause;
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
    auto query = new Query("users");
    assert(query.baseTableName == "users");
    assert(query.tableNames == ["users"]);
    assert(query.where.length == 0);
    assert(query.selections.length == 0);

    //--------------------------------------------------------------------------
    // Selections
    //--------------------------------------------------------------------------
    auto quoted    = GeneratorSettings.defaults();
    auto qualified = GeneratorSettings.defaults();
    auto both      = GeneratorSettings.defaults();

    quoted.quoteNames      = true;
    both.quoteNames        = true;
    qualified.qualifyNames = true;
    both.qualifyNames      = true;

    query.select("first_name", "last_name", "orders.id");
    assert(query.selections.length == 3);
    assert(query.selections[0].toSQL(qualified) == "users.first_name");
    assert(query.selections[1].toSQL(qualified) == "users.last_name");
    assert(query.selections[2].toSQL(qualified) == "orders.id");

    query.select(FieldName.parse("orders.state"), FieldName.parse("orders.quantity"));
    assert(query.selections.length == 5);
    assert(query.selections[3].toSQL(qualified) == "orders.state");
    assert(query.selections[4].toSQL(qualified) == "orders.quantity");

    //--------------------------------------------------------------------------
    // toRawSQL()
    //--------------------------------------------------------------------------
    query.from.join("orders");
    query.where.and("orders.price", 100.25, Operator.GREATER_OR_EQUAL).or("orders.quantity", 50, Operator.LESS_THAN);
    query.orderBy("orders.id", "last_name", "first_name");

    assert(query.toRawSQL() == "select first_name, last_name, id, state, quantity " ~
                               "from users " ~
                               "inner join orders on (users.id = orders.user_id) " ~
                               "where price >= 100.25 or quantity < 50 " ~
                               "order by id, last_name, first_name");

    assert(query.toRawSQL(quoted) == "select \"first_name\", \"last_name\", \"id\", \"state\", \"quantity\" " ~
                                     "from \"users\" " ~
                                     "inner join \"orders\" on (\"users\".\"id\" = \"orders\".\"user_id\") " ~
                                     "where \"price\" >= 100.25 or \"quantity\" < 50 " ~
                                     "order by \"id\", \"last_name\", \"first_name\"");

    assert(query.toRawSQL(qualified) == "select users.first_name, users.last_name, orders.id, orders.state, orders.quantity " ~
                                        "from users " ~
                                        "inner join orders on (users.id = orders.user_id) " ~
                                        "where orders.price >= 100.25 or orders.quantity < 50 " ~
                                        "order by orders.id, users.last_name, users.first_name");

    assert(query.toRawSQL(both) == "select \"users\".\"first_name\", \"users\".\"last_name\", \"orders\".\"id\", \"orders\".\"state\", \"orders\".\"quantity\" " ~
                                   "from \"users\" " ~
                                   "inner join \"orders\" on (\"users\".\"id\" = \"orders\".\"user_id\") " ~
                                   "where \"orders\".\"price\" >= 100.25 or \"orders\".\"quantity\" < 50 " ~
                                   "order by \"orders\".\"id\", \"users\".\"last_name\", \"users\".\"first_name\"");

    //--------------------------------------------------------------------------
    // toSQL() [returning a string]
    //--------------------------------------------------------------------------
    auto state = GeneratorState();

    query = new Query("users");
    query.from.join("orders");
    query.where.and("orders.price", 100.25, Operator.GREATER_OR_EQUAL).and("orders.quantity", 50, Operator.LESS_THAN);
    query.offset = 123;
    query.limit  = 100;

    assert(query.toSQL(state) == "select users.* " ~
                                 "from users " ~
                                 "inner join orders on (users.id = orders.user_id) " ~
                                 "where price >= $1 and quantity < $2 " ~
                                 "offset 123 limit 100");
    assert(state.values.length == 2);
    assert(state.values[0].get!double() == 100.25);
    assert(state.values[1].get!int() == 50);

    state = GeneratorState();
    assert(query.toSQL(state, quoted) == "select \"users\".* " ~
                                         "from \"users\" " ~
                                         "inner join \"orders\" on (\"users\".\"id\" = \"orders\".\"user_id\") " ~
                                         "where \"price\" >= $1 and \"quantity\" < $2 " ~
                                         "offset 123 limit 100");
    assert(state.values.length == 2);
    assert(state.values[0].get!double() == 100.25);
    assert(state.values[1].get!int() == 50);

    state = GeneratorState();
    assert(query.toSQL(state, qualified) == "select users.* " ~
                                            "from users " ~
                                            "inner join orders on (users.id = orders.user_id) " ~
                                            "where orders.price >= $1 and orders.quantity < $2 " ~
                                            "offset 123 limit 100");
    assert(state.values.length == 2);
    assert(state.values[0].get!double() == 100.25);
    assert(state.values[1].get!int() == 50);

    state = GeneratorState();
    assert(query.toSQL(state, both) == "select \"users\".* " ~
                                       "from \"users\" " ~
                                       "inner join \"orders\" on (\"users\".\"id\" = \"orders\".\"user_id\") " ~
                                       "where \"orders\".\"price\" >= $1 and \"orders\".\"quantity\" < $2 " ~
                                       "offset 123 limit 100");
    assert(state.values.length == 2);
    assert(state.values[0].get!double() == 100.25);
    assert(state.values[1].get!int() == 50);

    //--------------------------------------------------------------------------
    // toSQL() [returning a SQLOutput]
    //--------------------------------------------------------------------------
    auto output = query.toSQL();

    assert(output.sql == "select users.* " ~
                         "from users " ~
                         "inner join orders on (users.id = orders.user_id) " ~
                         "where price >= $1 and quantity < $2 " ~
                         "offset 123 limit 100");
    assert(output.data.length == 2);
    assert(output.data[0].get!double() == 100.25);
    assert(output.data[1].get!int() == 50);

    output = query.toSQL(qualified);
    assert(output.sql == "select users.* " ~
                         "from users " ~
                         "inner join orders on (users.id = orders.user_id) " ~
                         "where orders.price >= $1 and orders.quantity < $2 " ~
                         "offset 123 limit 100");
    assert(output.data.length == 2);
    assert(output.data[0].get!double() == 100.25);
    assert(output.data[1].get!int() == 50);
}