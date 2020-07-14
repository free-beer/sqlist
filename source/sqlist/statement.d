module sqlist.statement;

import std.typecons : Tuple;
import std.variant : Variant;
import sqlist;

/**
 * An alias for the output type used by the toSQL() functions.
 */
alias SQLOutput = Tuple!(Variant[], "data", string, "sql");

interface Statement : SQLGenerator {
    /**
     * Returns the name of the primary table in the statement. For selects this
     * will be the first table in the from list. For inserts, updates and
     * deletes this will be the name of the target table.
     */
    @property string baseTableName() const;

    /**
     * Returns the names of all tables involved in the statement. The base table
     * name will be first in this list.
     */
    @property string[] tableNames() const;

    /**
     * Generates the SQL relating to a Statement and returns a tuple containing
     * the SQL code and the associated values.
     */
    SQLOutput toSQL() const;

    /**
     * Generates the SQL relating to a Statement and returns a tuple containing
     * the SQL code and the associated values.
     */
    SQLOutput toSQL(ref GeneratorSettings settings) const;
}
