module sqlist.delete_statement;

import std.format : format;
import std.outbuffer : OutBuffer;
import sqlist;

/**
 * This class represents a SQL delete statement.
 */
class Delete : Statement {
    /**
     * Constructor.
     */
    this(string tableName) {
        _fromClause  = new FromClause(tableName);
        _whereClause = new WhereClause();
    }

    /**
     * Returns the name of the primary table in the statement.
     */
    @property string baseTableName() const {
        return(_fromClause.baseTableName);
    }

    /**
     * Property getter for the delete statements from clause.
     */
    @property FromClause from() {
        return(_fromClause);
    }

    /**
     * Property getter for the delete statements from clause.
     */
    @property const(FromClause) from() const {
        return(_fromClause);
    }

    /**
     * Returns the names of all tables involved in the statement. The base table
     * name will be first in this list.
     */
    @property string[] tableNames() const {
        return(_fromClause.tableNames);
    }

    /**
     * Property getter for the delete statements where clause.
     */
    @property WhereClause where() {
        return(_whereClause);
    }

    /**
     * Property getter for the delete statements where clause.
     */
    @property const(WhereClause) where() const {
        return(_whereClause);
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

        buffer.writef("delete %s", _fromClause.toRawSQL(settings));
        if(!_whereClause.empty) {
            buffer.writef(" %s", _whereClause.toRawSQL(settings));
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
        auto buffer    = new OutBuffer();
        auto tableName = (settings.quoteNames ? format("\"%s\"", baseTableName) : baseTableName);

        buffer.writef("delete %s", _fromClause.toSQL(state, settings));
        if(!_whereClause.empty) {
            buffer.writef(" %s", _whereClause.toSQL(state, settings));
        }

        return(buffer.toString());
    }

    FromClause  _fromClause;
    WhereClause _whereClause;
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
    auto statement = new Delete("order_lines");
    assert(statement.baseTableName == "order_lines");
    assert(statement.from.tableNames == ["order_lines"]);
    assert(statement.where.empty);
    assert(statement.from.tableNames == statement.tableNames);

    //--------------------------------------------------------------------------
    // toRawSQL()
    //--------------------------------------------------------------------------
    auto settings  = GeneratorSettings.defaults();
    auto quoted    = GeneratorSettings.defaults();
    auto qualified = GeneratorSettings.defaults();
    auto both      = GeneratorSettings.defaults();

    quoted.quoteNames       = true;
    both.quoteNames        = true;
    qualified.qualifyNames = true;
    both.qualifyNames      = true;

    statement.from.join("stock_levels", "item_id", "", "item_id");
    statement.where.and("order_lines.status", "OUT_OF_STOCK");
    statement.where.or(FieldName.parse("order_lines.quantity"), FieldName.parse("stock_levels.number_in_stock"), Operator.GREATER_THAN);

    assert(statement.toRawSQL() == "delete from order_lines " ~
                                   "inner join stock_levels on (order_lines.item_id = stock_levels.item_id) " ~
                                   "where status = 'OUT_OF_STOCK' " ~
                                   "or quantity > number_in_stock");

    assert(statement.toRawSQL(quoted) == "delete from \"order_lines\" " ~
                                         "inner join \"stock_levels\" on (\"order_lines\".\"item_id\" = \"stock_levels\".\"item_id\") " ~
                                         "where \"status\" = 'OUT_OF_STOCK' " ~
                                         "or \"quantity\" > \"number_in_stock\"");

    assert(statement.toRawSQL(qualified) == "delete from order_lines " ~
                                            "inner join stock_levels on (order_lines.item_id = stock_levels.item_id) " ~
                                            "where order_lines.status = 'OUT_OF_STOCK' " ~
                                            "or order_lines.quantity > stock_levels.number_in_stock");

    assert(statement.toRawSQL(both) == "delete from \"order_lines\" " ~
                                       "inner join \"stock_levels\" on (\"order_lines\".\"item_id\" = \"stock_levels\".\"item_id\") " ~
                                       "where \"order_lines\".\"status\" = 'OUT_OF_STOCK' " ~
                                       "or \"order_lines\".\"quantity\" > \"stock_levels\".\"number_in_stock\"");

    //--------------------------------------------------------------------------
    // toSQL()
    //--------------------------------------------------------------------------
    auto state = GeneratorState();

    assert(statement.toSQL(state) == "delete from order_lines " ~
                                     "inner join stock_levels on (order_lines.item_id = stock_levels.item_id) " ~
                                     "where status = $1 " ~
                                     "or quantity > number_in_stock");
    assert(state.values.length == 1);
    assert(state.values[0].get!string() == "OUT_OF_STOCK");

    state = GeneratorState();
    assert(statement.toSQL(state, quoted) == "delete from \"order_lines\" " ~
                                             "inner join \"stock_levels\" on (\"order_lines\".\"item_id\" = \"stock_levels\".\"item_id\") " ~
                                             "where \"status\" = $1 " ~
                                             "or \"quantity\" > \"number_in_stock\"");
    assert(state.values.length == 1);
    assert(state.values[0].get!string() == "OUT_OF_STOCK");

    state = GeneratorState();
    assert(statement.toSQL(state, qualified) == "delete from order_lines " ~
                                                "inner join stock_levels on (order_lines.item_id = stock_levels.item_id) " ~
                                                "where order_lines.status = $1 " ~
                                                "or order_lines.quantity > stock_levels.number_in_stock");
    assert(state.values.length == 1);
    assert(state.values[0].get!string() == "OUT_OF_STOCK");

    state = GeneratorState();
    assert(statement.toSQL(state, both) == "delete from \"order_lines\" " ~
                                           "inner join \"stock_levels\" on (\"order_lines\".\"item_id\" = \"stock_levels\".\"item_id\") " ~
                                           "where \"order_lines\".\"status\" = $1 " ~
                                           "or \"order_lines\".\"quantity\" > \"stock_levels\".\"number_in_stock\"");
    assert(state.values.length == 1);
    assert(state.values[0].get!string() == "OUT_OF_STOCK");
}