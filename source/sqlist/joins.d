module sqlist.joins;

import std.algorithm : endsWith;
import std.array : array;
import std.format : format;
import std.outbuffer : OutBuffer;
import std.typecons : Tuple;
import sqlist;

/**
 * This interface defines the functionality that concrete join types must
 * implement.
 */
interface Join : SQLGenerator {
    /**
     * Adds a match to an existing Join.
     */
    Join addMatch(T)(string fieldName, T fieldValue);

    /**
     * Adds a match to an existing Join.
     */
    Join addMatch(T)(FieldName fieldName, T fieldValue);

    /**
     * Retrieves the name of the table being joined from.
     */
    @property string fromTable() const;

    /**
     * Retrieves a list of the field matches that make up the join.
     */
    @property const(FieldComparison)[] fieldMatches() const;

    /**
     * Retrieves the name of the table being joined to.
     */
    @property string toTable() const;
}

/**
 * An abstract base class that will provide functionality that can be shared
 * between more concrete join types.
 */
abstract class AbstractJoin : Join {
    /**
     * A constant for the default from field name.
     */
    enum DEFAULT_FROM_FIELD_NAME = "id";

    this(string joinType, string fromTable, string toTable, string toField="", string fromField=DEFAULT_FROM_FIELD_NAME) {
        _fromTable = fromTable;
        _joinType  = joinType;
        _toTable   = toTable;
        if(toField == "") {
            toField = generateToFieldName();
        }
        addMatch(new FieldName(fromField, fromTable),
                 new FieldName(toField, toTable));
    }

    /**
     * Property getter for the join from table name.
     */
    @property string fromTable() const {
        return(_fromTable);
    }

    /**
     * Retrieves a list of the field matches that make up the join.
     */
    @property const(FieldComparison)[] fieldMatches() const {
        return(_matches.array);
    }

    /**
     * Property getter for the join to table name.
     */
    @property string toTable() const {
        return(_toTable);
    }
    /**
     * Adds a match to an existing Join.
     */
    Join addMatch(T)(string fieldName, T fieldValue) {
        return(addMatch(FieldName.parse(fieldName), fieldValue));
    }


    /**
     * Adds a match to an existing Join.
     */
    Join addMatch(T)(FieldName fieldName, T fieldValue) {
        if(fieldName.table != fromTable && fieldName.table != toTable) {
            throw(new SQListException(format("Invalid join field name. The %s does not stipulate either of the tables that are part of the join.", fieldName)));
        }
        _matches ~= new FieldComparison(fieldName, fieldValue);
        return(this);
    }

    /**
     * Implementation of the addMatch() function that specializes the fieldValue
     * parameter to being a FieldName.
     */
    Join addMatch(T: FieldName)(FieldName fieldName, T fieldValue) {
        if(fieldName.table != fromTable && fieldName.table != toTable) {
            throw(new SQListException(format("Invalid join field name. The %s field does not stipulate either of the tables that are part of the join.", fieldName)));
        }
        if(fieldValue.table != fromTable && fieldValue.table != toTable) {
            throw(new SQListException(format("Invalid join field name. The %s field does not stipulate either of the tables that are part of the join.", fieldValue)));
        }
        _matches ~= new FieldComparison(fieldName, fieldValue);
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
        auto   matchSettings = GeneratorSettings(settings);
        string toTable       = _toTable;

        matchSettings.qualifyNames = true;
        if(settings.quoteNames) {
            toTable = format("\"%s\"", toTable);
        }
        return(format("%s join %s on (%s)", _joinType, toTable, matchesList(matchSettings)));
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
        auto   matchSettings = GeneratorSettings(settings);
        string toTable       = _toTable;

        matchSettings.qualifyNames = true;
        if(settings.quoteNames) {
            toTable = format("\"%s\"", toTable);
        }
        return(format("%s join %s on (%s)", _joinType, toTable, matchesList(state, matchSettings)));
    }

    private string generateToFieldName() {
        if(_fromTable.endsWith("s")) {
            return(_fromTable[0..$-1] ~ "_id");
        } else {
            return(_fromTable ~ "_id");
        }
    }

    private string matchesList(GeneratorSettings settings) const {
        auto buffer = new OutBuffer();
        auto first  = true;

        foreach(match; _matches) {
            if(!first) {
                buffer.writef(", ");
            } else {
                first = false;
            }
            buffer.writef("%s", match.toRawSQL(settings));
        }
        return(buffer.toString());
    }

    private string matchesList(ref GeneratorState state, GeneratorSettings settings) const {
        auto buffer = new OutBuffer();
        auto first  = true;

        foreach(match; _matches) {
            if(!first) {
                buffer.writef(", ");
            } else {
                first = false;
            }
            buffer.writef("%s", match.toSQL(state, settings));
        }
        return(buffer.toString());
    }

    string            _fromTable;
    string            _joinType;
    string            _toTable;
    FieldComparison[] _matches;
}

/**
 * This class represents a SQL inner join.
 */
class InnerJoin : AbstractJoin {
    this(string fromTable, string toTable, string toField="", string fromField=DEFAULT_FROM_FIELD_NAME) {
        super("inner", fromTable, toTable, toField, fromField);
    }
}

/**
 * This class represents a SQL left outer join.
 */
class LeftJoin : AbstractJoin {
    this(string fromTable, string toTable, string toField="", string fromField=DEFAULT_FROM_FIELD_NAME) {
        super("left", fromTable, toTable, toField, fromField);
    }
}

/**
 * This class represents a SQL right outer join.
 */
class RightJoin : AbstractJoin {
    this(string fromTable, string toTable, string toField="", string fromField=DEFAULT_FROM_FIELD_NAME) {
        super("right", fromTable, toTable, toField, fromField);
    }
}

/**
 * This class represents a SQL full outer join.
 */
class FullJoin : AbstractJoin {
    this(string fromTable, string toTable, string toField="", string fromField=DEFAULT_FROM_FIELD_NAME) {
        super("full", fromTable, toTable, toField, fromField);
    }
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
    auto settings = GeneratorSettings.defaults();
    auto join = new InnerJoin("accounts", "orders");

    settings.qualifyNames = true;
    assert(join.fromTable == "accounts");
    assert(join.toTable == "orders");
    assert(join.fieldMatches.length == 1);
    assert(join.fieldMatches[0].fieldName == FieldName.parse("accounts.id"));
    assert(join.fieldMatches[0].value.toRawSQL(settings) == "orders.account_id");

    //--------------------------------------------------------------------------
    // addMatch()
    //--------------------------------------------------------------------------
    join.addMatch("orders.status", "ACTIVE");
    assert(join.fieldMatches.length == 2);
    assert(join.fieldMatches[0].fieldName == FieldName.parse("accounts.id"));
    assert(join.fieldMatches[0].value.toRawSQL(settings) == "orders.account_id");
    assert(join.fieldMatches[1].fieldName == FieldName.parse("orders.status"));
    assert(join.fieldMatches[1].value.toRawSQL(settings) == "'ACTIVE'");

    join.addMatch("accounts.key", FieldName.parse("orders.account_key"));
    assert(join.fieldMatches.length == 3);
    assert(join.fieldMatches[0].fieldName == FieldName.parse("accounts.id"));
    assert(join.fieldMatches[0].value.toRawSQL(settings) == "orders.account_id");
    assert(join.fieldMatches[1].fieldName == FieldName.parse("orders.status"));
    assert(join.fieldMatches[1].value.toRawSQL(settings) == "'ACTIVE'");
    assert(join.fieldMatches[2].fieldName == FieldName.parse("accounts.key"));
    assert(join.fieldMatches[2].value.toRawSQL(settings) == "orders.account_key");

    assertThrown!SQListException(join.addMatch(FieldName.parse("new_table.other_field"), 123));
    assertThrown!SQListException(join.addMatch(FieldName.parse("orders.other_field"), FieldName.parse("new_table.some_field")));

    //--------------------------------------------------------------------------
    // toRawSQL()
    //--------------------------------------------------------------------------
    auto quoted = GeneratorSettings(settings);

    quoted.quoteNames = true;

    join = new InnerJoin("accounts", "orders");
    assert(join.toRawSQL() == "inner join orders on (accounts.id = orders.account_id)");

    join = new InnerJoin("accounts", "orders", "acc_id");
    assert(join.toRawSQL() == "inner join orders on (accounts.id = orders.acc_id)");

    join = new InnerJoin("accounts", "orders", "acc_book_id", "book_id");
    assert(join.toRawSQL() == "inner join orders on (accounts.book_id = orders.acc_book_id)");

    join = new InnerJoin("accounts", "orders");
    join.addMatch(FieldName.parse("orders.status"), "ACTIVE");
    assert(join.toRawSQL() == "inner join orders on (accounts.id = orders.account_id, orders.status = 'ACTIVE')");
    assert(join.toRawSQL(quoted) == "inner join \"orders\" on (\"accounts\".\"id\" = \"orders\".\"account_id\", \"orders\".\"status\" = 'ACTIVE')");

    //--------------------------------------------------------------------------
    // toRawSQL()
    //--------------------------------------------------------------------------
    auto state = GeneratorState();

    join = new InnerJoin("accounts", "orders");
    assert(join.toSQL(state) == "inner join orders on (accounts.id = orders.account_id)");
    assert(state.length == 0);

    join = new InnerJoin("accounts", "orders", "acc_id");
    assert(join.toSQL(state) == "inner join orders on (accounts.id = orders.acc_id)");
    assert(state.length == 0);

    join = new InnerJoin("accounts", "orders", "acc_book_id", "book_id");
    assert(join.toSQL(state) == "inner join orders on (accounts.book_id = orders.acc_book_id)");
    assert(state.length == 0);

    join = new InnerJoin("accounts", "orders");
    join.addMatch(FieldName.parse("orders.status"), "ACTIVE");
    assert(join.toSQL(state) == "inner join orders on (accounts.id = orders.account_id, orders.status = $1)");
    assert(state.length == 1);
    assert(state.values[0].get!string() == "ACTIVE");
    assert(join.toSQL(state, quoted) == "inner join \"orders\" on (\"accounts\".\"id\" = \"orders\".\"account_id\", \"orders\".\"status\" = $2)");
    assert(state.length == 2);
    assert(state.values[0].get!string() == "ACTIVE");
    assert(state.values[1].get!string() == "ACTIVE");

    //--------------------------------------------------------------------------
    // Other Join Types
    //--------------------------------------------------------------------------
    assert((new LeftJoin("accounts", "orders")).toRawSQL() == "left join orders on (accounts.id = orders.account_id)");
    assert((new RightJoin("accounts", "orders")).toRawSQL() == "right join orders on (accounts.id = orders.account_id)");
    assert((new FullJoin("accounts", "orders")).toRawSQL() == "full join orders on (accounts.id = orders.account_id)");
}