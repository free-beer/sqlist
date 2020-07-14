module sqlist.sql_field;

import sqlist;

/**
 * This interface is meant as as way of flagging something as being returned
 * from a SQL statement. This might be the fields in a select or returning
 * clause for example. Generally this will be field names but it can also
 * include function calls.
 */
interface SQLField : SQLGenerator {
    final string toSQL() const {
        auto settings = GeneratorSettings.defaults();
        return(toSQL(settings));
    }

    /**
     * Generate the SQL for a field given a set of preferences.
     */
    string toSQL(ref GeneratorSettings settings) const;
}
