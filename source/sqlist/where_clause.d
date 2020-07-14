module sqlist.where_clause;

import std.array : array;
import std.outbuffer : OutBuffer;
import std.typecons : Tuple;
import sqlist;

/**
 * This class provides the functionality for a where clause part of a SQL
 * statement.
 */
class WhereClause : SQLGenerator {
    /**
     * An enumeration of the various condition types.
     */
    enum ConditionType {
        And = "and",
        Or  = "or"
    }

    alias Condition = Tuple!(ConditionType, "type", FieldComparison, "test");

    /**
     * Default constructor.
     */
    this() {
    }

    /**
     * Property getter for the where clause conditions.
     */
    @property const(Condition)[] conditions() const {
        return(_conditions.array);
    }

    /**
     * Property getter that can be used to test whether a WhereClause contains
     * no test conditions.
     */
    @property bool empty() const {
        return(_conditions.length == 0);
    }

    /**
     * Property getter for the number of conditions within a where clause.
     */
    @property size_t length() const {
        return(_conditions.length);
    }

    /**
     * This function appends a new condition to the where clause. The condition
     * added is an 'and' condition. The function returns the WhereClause to
     * allow for chaining.
     */
    WhereClause and(T)(string fieldName, T fieldValue, const Operator operator=Operator.EQUAL) {
        return(and(FieldName.parse(fieldName), fieldValue, operator));
    }

    /**
     * This function appends a new condition to the where clause. The condition
     * added is an 'and' condition. The function returns the WhereClause to
     * allow for chaining.
     */
    WhereClause and(T)(const FieldName fieldName, T fieldValue, const Operator operator=Operator.EQUAL) {
        return(and(new FieldComparison(fieldName, fieldValue, operator)));
    }

    /**
     * This function appends a new condition to the where clause. The condition
     * added is an 'and' condition. The function returns the WhereClause to
     * allow for chaining.
     */
    WhereClause and(const FieldComparison comparison) {
        Condition condition;

        condition.type = ConditionType.And;
        condition.test = comparison.dup;
        _conditions ~= condition;

        return(this);
    }

    /**
     * This function appends a new condition to the where clause. The condition
     * added is an 'or' condition. The function returns the WhereClause to
     * allow for chaining.
     */
    WhereClause or(T)(string fieldName, T fieldValue, const Operator operator=Operator.EQUAL) {
        return(or(FieldName.parse(fieldName), fieldValue, operator));
    }

    /**
     * This function appends a new condition to the where clause. The condition
     * added is an 'or' condition. The function returns the WhereClause to
     * allow for chaining.
     */
    WhereClause or(T)(const FieldName fieldName, T fieldValue, const Operator operator=Operator.EQUAL) {
        return(or(new FieldComparison(fieldName, fieldValue, operator)));
    }

    /**
     * This function appends a new condition to the where clause. The condition
     * added is an 'or' condition. The function returns the WhereClause to
     * allow for chaining.
     */
    WhereClause or(const FieldComparison comparison) {
        Condition condition;

        condition.type = ConditionType.Or;
        condition.test = comparison.dup;
        _conditions ~= condition;

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
        auto buffer = new OutBuffer();

        if(_conditions.length > 0) {
            buffer.writef("where %s", _conditions[0].test.toRawSQL(settings));
            foreach(condition; _conditions[1..$]) {
                auto type = (condition.type == ConditionType.And ? "and" : "or");
                buffer.writef(" %s %s", type, condition.test.toRawSQL(settings));
            }
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
        auto buffer = new OutBuffer();

        if(_conditions.length > 0) {
            buffer.writef("where %s", _conditions[0].test.toSQL(state, settings));
            foreach(condition; _conditions[1..$]) {
                auto type = (condition.type == ConditionType.And ? "and" : "or");
                buffer.writef(" %s %s", type, condition.test.toSQL(state, settings));
            }
        }
        return(buffer.toString());
    }


    private Condition[] _conditions;
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
    auto clause = new WhereClause();
    assert(clause.length == 0);
    assert(clause.conditions == []);

    //--------------------------------------------------------------------------
    // and()
    //--------------------------------------------------------------------------
    assert(clause.and("users.age", 25) is clause);
    assert(clause.length == 1);
    assert(clause.conditions[0].test == new FieldComparison("users.age", 25));
    assert(clause.conditions[0].type is WhereClause.ConditionType.And);

    clause.and(FieldName.parse("users.first_name"), "Joe");
    assert(clause.length == 2);
    assert(clause.conditions[0].test == new FieldComparison("users.age", 25));
    assert(clause.conditions[0].type is WhereClause.ConditionType.And);
    assert(clause.conditions[1].test == new FieldComparison("users.first_name", "Joe"));
    assert(clause.conditions[1].type is WhereClause.ConditionType.And);

    clause.and(new FieldComparison("users.surname", "Bloggs"));
    assert(clause.length == 3);
    assert(clause.conditions[0].test == new FieldComparison("users.age", 25));
    assert(clause.conditions[0].type is WhereClause.ConditionType.And);
    assert(clause.conditions[1].test == new FieldComparison("users.first_name", "Joe"));
    assert(clause.conditions[1].type is WhereClause.ConditionType.And);
    assert(clause.conditions[2].test == new FieldComparison("users.surname", "Bloggs"));
    assert(clause.conditions[2].type is WhereClause.ConditionType.And);

    //--------------------------------------------------------------------------
    // or()
    //--------------------------------------------------------------------------
    clause = new WhereClause();
    assert(clause.or("users.age", 25) is clause);
    assert(clause.length == 1);
    assert(clause.conditions[0].test == new FieldComparison("users.age", 25));
    assert(clause.conditions[0].type is WhereClause.ConditionType.Or);

    clause.or(FieldName.parse("users.first_name"), "Joe");
    assert(clause.length == 2);
    assert(clause.conditions[0].test == new FieldComparison("users.age", 25));
    assert(clause.conditions[0].type is WhereClause.ConditionType.Or);
    assert(clause.conditions[1].test == new FieldComparison("users.first_name", "Joe"));
    assert(clause.conditions[1].type is WhereClause.ConditionType.Or);

    clause.or(new FieldComparison("users.surname", "Bloggs"));
    assert(clause.length == 3);
    assert(clause.conditions[0].test == new FieldComparison("users.age", 25));
    assert(clause.conditions[0].type is WhereClause.ConditionType.Or);
    assert(clause.conditions[1].test == new FieldComparison("users.first_name", "Joe"));
    assert(clause.conditions[1].type is WhereClause.ConditionType.Or);
    assert(clause.conditions[2].test == new FieldComparison("users.surname", "Bloggs"));
    assert(clause.conditions[2].type is WhereClause.ConditionType.Or);

    //--------------------------------------------------------------------------
    // toRawSQL()
    //--------------------------------------------------------------------------
    auto quoted    = GeneratorSettings.defaults();
    auto qualified = GeneratorSettings.defaults();
    auto both      = GeneratorSettings.defaults();

    quoted.quoteNames      = true;
    both.quoteNames        = true;
    qualified.qualifyNames = true;
    both.qualifyNames      = true;

    clause = new WhereClause();
    assert(clause.toRawSQL() == "");

    clause.and("users.surname", "Bloggs").and("users.status", "ACTIVE").or("users.age", 21, Operator.GREATER_OR_EQUAL);
    assert(clause.toRawSQL() == "where surname = 'Bloggs' and status = 'ACTIVE' or age >= 21");
    assert(clause.toRawSQL(quoted) == "where \"surname\" = 'Bloggs' and \"status\" = 'ACTIVE' or \"age\" >= 21");
    assert(clause.toRawSQL(qualified) == "where users.surname = 'Bloggs' and users.status = 'ACTIVE' or users.age >= 21");
    assert(clause.toRawSQL(both) == "where \"users\".\"surname\" = 'Bloggs' and \"users\".\"status\" = 'ACTIVE' or \"users\".\"age\" >= 21");

    //--------------------------------------------------------------------------
    // toSQL()
    //--------------------------------------------------------------------------
    auto state = GeneratorState();

    clause = new WhereClause();
    assert(clause.toSQL(state) == "");
    assert(state.length == 0);

    clause.and("users.surname", "Bloggs").and("users.status", "ACTIVE").or("users.age", 21, Operator.GREATER_OR_EQUAL);
    assert(clause.toSQL(state) == "where surname = $1 and status = $2 or age >= $3");
    assert(state.length == 3);
    assert(state.values[0].get!string() == "Bloggs");
    assert(state.values[1].get!string() == "ACTIVE");
    assert(state.values[2].get!int() == 21);

    state = GeneratorState();
    assert(clause.toSQL(state, quoted) == "where \"surname\" = $1 and \"status\" = $2 or \"age\" >= $3");
    assert(state.length == 3);
    assert(state.values[0].get!string() == "Bloggs");
    assert(state.values[1].get!string() == "ACTIVE");
    assert(state.values[2].get!int() == 21);

    state = GeneratorState();
    assert(clause.toSQL(state, qualified) == "where users.surname = $1 and users.status = $2 or users.age >= $3");
    assert(state.length == 3);
    assert(state.values[0].get!string() == "Bloggs");
    assert(state.values[1].get!string() == "ACTIVE");
    assert(state.values[2].get!int() == 21);

    state = GeneratorState();
    assert(clause.toSQL(state, both) == "where \"users\".\"surname\" = $1 and \"users\".\"status\" = $2 or \"users\".\"age\" >= $3");
    assert(state.length == 3);
    assert(state.values[0].get!string() == "Bloggs");
    assert(state.values[1].get!string() == "ACTIVE");
    assert(state.values[2].get!int() == 21);
}