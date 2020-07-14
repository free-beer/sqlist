module sqlist.from_clause;

import std.algorithm : canFind;
import std.array : array;
import std.format : format;
import std.outbuffer : OutBuffer;
import std.string : strip;
import sqlist;

/**
 * This class encapsulates the functionality relating to the from clause for a
 * select ande delete SQL statement.
 */
class FromClause : SQLGenerator {
    /**
     * A constant for the default from field name to be used.
     */
    enum DEFAULT_FROM_FIELD_NAME = AbstractJoin.DEFAULT_FROM_FIELD_NAME;

    /**
     * Constructor.
     */
    this(string baseTableName, Join[] joins...) {
        _baseTableName = baseTableName;
        _joins         = joins.array;
    }

    /**
     * Property getter for the from clause base table name.
     */
    @property string baseTableName() const {
        return(_baseTableName);
    }

    /**
     * Property getter for the joins that make up a from clause.
     */
    @property const(Join)[] joins() const {
        return(_joins.array);
    }

    /**
     * Property getter the fetches a list of the table names within a FromClause
     * instance. The base table name will always be the first table in the list.
     */
    @property string[] tableNames() const {
        string[] names = [_baseTableName];

        foreach(join; _joins) {
            if(!names.canFind(join.fromTable)) {
                names ~= join.fromTable;
            }
            if(!names.canFind(join.toTable)) {
                names ~= join.toTable;
            }
        }

        return(names);
    }

    /**
     * This function adds one or more joins to a FromClause instance.
     */
    void add(Join first, Join[] others...) {
        _joins ~= first;
        foreach(join; others) {
            _joins ~= join;
        }
    }

    /**
     * This function provides a shortcut means of creating an inner join on a
     * FromClause object. Most of the parameters have default values that will
     * trigger specific behaviour, with only the name of the table being linked
     * to being compulsory. If the toFieldName is defaulted then the code will
     * attempt to generate the field name by taking the from table name,
     * stripping any 's' from the end of it and appending '_id' to it. If the
     * fromTableName is defaulted then the base table name will be assumed. If
     * the toFieldName is defaulted then the value of DEFAULT_FROM_FIELD_NAME
     * constant will be used.
     */
    void innerJoin(string toTableName, string toFieldName="", string fromTableName="", string fromFieldName=DEFAULT_FROM_FIELD_NAME) {
        auto fromTable = (fromTableName == "" ? baseTableName : fromTableName);
        add(new InnerJoin(fromTable, toTableName, toFieldName, fromFieldName));
    }

    /**
     * This is an alias for the innerJoin() function.
     */
    void join(string toTableName, string toFieldName="", string fromTableName="", string fromFieldName=DEFAULT_FROM_FIELD_NAME) {
        innerJoin(toTableName, toFieldName, fromTableName, fromFieldName);
    }

    /**
     * This function provides a shortcut means of creating an left join on a
     * FromClause object. Most of the parameters have default values that will
     * trigger specific behaviour, with only the name of the table being linked
     * to being compulsory. If the toFieldName is defaulted then the code will
     * attempt to generate the field name by taking the from table name,
     * stripping any 's' from the end of it and appending '_id' to it. If the
     * fromTableName is defaulted then the base table name will be assumed. If
     * the toFieldName is defaulted then the value of DEFAULT_FROM_FIELD_NAME
     * constant will be used.
     */
    void leftJoin(string toTableName, string toFieldName="", string fromTableName="", string fromFieldName=DEFAULT_FROM_FIELD_NAME) {
        auto fromTable = (fromTableName == "" ? baseTableName : fromTableName);
        add(new LeftJoin(fromTable, toTableName, toFieldName, fromFieldName));
    }

    /**
     * This function provides a shortcut means of creating an right join on a
     * FromClause object. Most of the parameters have default values that will
     * trigger specific behaviour, with only the name of the table being linked
     * to being compulsory. If the toFieldName is defaulted then the code will
     * attempt to generate the field name by taking the from table name,
     * stripping any 's' from the end of it and appending '_id' to it. If the
     * fromTableName is defaulted then the base table name will be assumed. If
     * the toFieldName is defaulted then the value of DEFAULT_FROM_FIELD_NAME
     * constant will be used.
     */
    void rightJoin(string toTableName, string toFieldName="", string fromTableName="", string fromFieldName=DEFAULT_FROM_FIELD_NAME) {
        auto fromTable = (fromTableName == "" ? baseTableName : fromTableName);
        add(new RightJoin(fromTable, toTableName, toFieldName, fromFieldName));
    }

    /**
     * This function provides a shortcut means of creating an full join on a
     * FromClause object. Most of the parameters have default values that will
     * trigger specific behaviour, with only the name of the table being linked
     * to being compulsory. If the toFieldName is defaulted then the code will
     * attempt to generate the field name by taking the from table name,
     * stripping any 's' from the end of it and appending '_id' to it. If the
     * fromTableName is defaulted then the base table name will be assumed. If
     * the toFieldName is defaulted then the value of DEFAULT_FROM_FIELD_NAME
     * constant will be used.
     */
    void fullJoin(string toTableName, string toFieldName="", string fromTableName="", string fromFieldName=DEFAULT_FROM_FIELD_NAME) {
        auto fromTable = (fromTableName == "" ? baseTableName : fromTableName);
        add(new FullJoin(fromTable, toTableName, toFieldName, fromFieldName));
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
        auto tableName = baseTableName;

        if(settings.quoteNames) {
            tableName = format("\"%s\"", tableName);
        }

        buffer.writef("from %s", tableName);
        foreach(join; _joins) {
            buffer.writef(" %s", join.toRawSQL(settings));
        }

        return(buffer.toString());
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
        auto tableName = baseTableName;

        if(settings.quoteNames) {
            tableName = format("\"%s\"", tableName);
        }

        buffer.writef("from %s", tableName);
        foreach(join; _joins) {
            buffer.writef(" %s", join.toSQL(state, settings));
        }

        return(buffer.toString());
    }

    private string _baseTableName;
    private Join[] _joins;
}

//==============================================================================
// Unit Tests
//==============================================================================
unittest {
    import std.exception;
    import std.stdio;

    writeln("  Running unit tests for the ", __FILE__, " file.");

    FieldComparison fieldMatch;
    Join[]     joins;
    joins ~= new InnerJoin("users", "addresses");
    joins ~= new LeftJoin("users", "orders");
    joins ~= new RightJoin("users", "invoices");

    //--------------------------------------------------------------------------
    // Construction & Base Properties
    //--------------------------------------------------------------------------
    auto clause = new FromClause("users");
    assert(clause.baseTableName == "users");
    assert(clause.joins.length == 0);
    assert(clause.tableNames == ["users"]);

    clause = new FromClause("users", joins[0]);
    assert(clause.baseTableName == "users");
    assert(clause.joins.length == 1);
    assert(clause.joins[0] == joins[0]);
    assert(clause.tableNames == ["users", "addresses"]);

    clause = new FromClause("users", joins[0], joins[1], joins[2]);
    assert(clause.baseTableName == "users");
    assert(clause.joins.length == joins.length);
    foreach(join; clause.joins) {
        joins.canFind(join);
    }
    assert(clause.tableNames == ["users", "addresses", "orders", "invoices"]);

    //--------------------------------------------------------------------------
    // innerJoin()
    //--------------------------------------------------------------------------
    clause = new FromClause("users");
    clause.innerJoin("addresses");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == clause.baseTableName);
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "inner join addresses on (users.id = addresses.user_id)");

    clause = new FromClause("users");
    clause.innerJoin("addresses", "owner_id");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == clause.baseTableName);
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "inner join addresses on (users.id = addresses.owner_id)");

    clause = new FromClause("users");
    clause.innerJoin("addresses", "owner_id", "other");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == "other");
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "inner join addresses on (other.id = addresses.owner_id)");

    clause = new FromClause("users");
    clause.innerJoin("addresses", "", "other");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == "other");
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "inner join addresses on (other.id = addresses.other_id)");

    clause = new FromClause("users");
    clause.innerJoin("addresses", "owner_id", "other", "identifier");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == "other");
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "inner join addresses on (other.identifier = addresses.owner_id)");

    //--------------------------------------------------------------------------
    // leftJoin()
    //--------------------------------------------------------------------------
    clause = new FromClause("users");
    clause.leftJoin("addresses");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == clause.baseTableName);
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "left join addresses on (users.id = addresses.user_id)");

    clause = new FromClause("users");
    clause.leftJoin("addresses", "owner_id");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == clause.baseTableName);
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "left join addresses on (users.id = addresses.owner_id)");

    clause = new FromClause("users");
    clause.leftJoin("addresses", "owner_id", "other");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == "other");
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "left join addresses on (other.id = addresses.owner_id)");

    clause = new FromClause("users");
    clause.leftJoin("addresses", "", "other");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == "other");
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "left join addresses on (other.id = addresses.other_id)");

    clause = new FromClause("users");
    clause.leftJoin("addresses", "owner_id", "other", "identifier");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == "other");
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "left join addresses on (other.identifier = addresses.owner_id)");

    //--------------------------------------------------------------------------
    // rightJoin()
    //--------------------------------------------------------------------------
    clause = new FromClause("users");
    clause.rightJoin("addresses");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == clause.baseTableName);
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "right join addresses on (users.id = addresses.user_id)");

    clause = new FromClause("users");
    clause.rightJoin("addresses", "owner_id");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == clause.baseTableName);
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "right join addresses on (users.id = addresses.owner_id)");

    clause = new FromClause("users");
    clause.rightJoin("addresses", "owner_id", "other");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == "other");
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "right join addresses on (other.id = addresses.owner_id)");

    clause = new FromClause("users");
    clause.rightJoin("addresses", "", "other");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == "other");
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "right join addresses on (other.id = addresses.other_id)");

    clause = new FromClause("users");
    clause.rightJoin("addresses", "owner_id", "other", "identifier");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == "other");
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "right join addresses on (other.identifier = addresses.owner_id)");

    //--------------------------------------------------------------------------
    // fullJoin()
    //--------------------------------------------------------------------------
    clause = new FromClause("users");
    clause.fullJoin("addresses");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == clause.baseTableName);
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "full join addresses on (users.id = addresses.user_id)");

    clause = new FromClause("users");
    clause.fullJoin("addresses", "owner_id");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == clause.baseTableName);
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "full join addresses on (users.id = addresses.owner_id)");

    clause = new FromClause("users");
    clause.fullJoin("addresses", "owner_id", "other");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == "other");
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "full join addresses on (other.id = addresses.owner_id)");

    clause = new FromClause("users");
    clause.fullJoin("addresses", "", "other");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == "other");
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "full join addresses on (other.id = addresses.other_id)");

    clause = new FromClause("users");
    clause.fullJoin("addresses", "owner_id", "other", "identifier");

    assert(clause.joins.length == 1);
    assert(clause.joins[0].fromTable == "other");
    assert(clause.joins[0].toTable == "addresses");
    assert(clause.joins[0].toRawSQL() == "full join addresses on (other.identifier = addresses.owner_id)");

    //--------------------------------------------------------------------------
    // toRawSQL()
    //--------------------------------------------------------------------------
    auto settings  = GeneratorSettings.defaults();
    auto quoted    = GeneratorSettings(settings);

    quoted.quoteNames      = true;

    clause = new FromClause("users");
    assert(clause.toRawSQL() == "from users");

    clause.innerJoin("addresses");
    assert(clause.toRawSQL() == "from users inner join addresses on (users.id = addresses.user_id)");

    clause.rightJoin("options");
    assert(clause.toRawSQL() == "from users inner join addresses on (users.id = addresses.user_id) right join options on (users.id = options.user_id)");

    assert(clause.toRawSQL(quoted) == "from \"users\" inner join \"addresses\" on (\"users\".\"id\" = \"addresses\".\"user_id\") right join \"options\" on (\"users\".\"id\" = \"options\".\"user_id\")");

    //--------------------------------------------------------------------------
    // toSQL()
    //--------------------------------------------------------------------------
    auto state = GeneratorState();

    clause = new FromClause("users");
    assert(clause.toSQL(state) == "from users");

    clause.innerJoin("addresses");
    assert(clause.toSQL(state) == "from users inner join addresses on (users.id = addresses.user_id)");

    clause.rightJoin("options");
    assert(clause.toSQL(state) == "from users inner join addresses on (users.id = addresses.user_id) right join options on (users.id = options.user_id)");
}
