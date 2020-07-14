module sqlist.sql_generator;

import std.algorithm : map;
import std.array : array;
import std.typecons : Tuple;
import std.variant : Variant;
import sqlist;

/**
 * A structure that provides configuration settings that can be passed to a
 * SQLGenerator to control elements of how it generates code.
 */
struct GeneratorSettings {
    /**
     * Constructor that creates a GeneratorSettings object from another one.
     */
    this(GeneratorSettings source) {
        qualifyNames = source.qualifyNames;
        quoteNames   = source.quoteNames;
    }

    /**
     * Generates a default set of settings.
     */
    static GeneratorSettings defaults() {
        GeneratorSettings settings;
        return(settings);
    }

    bool qualifyNames;
    bool quoteNames;
}

/**
 * A data structure used to maintain state during the production of SQL code
 * by a SQLGenerator.
 */
struct GeneratorState {
    /**
     * Property getter for the number of values currently held by the state.
     */
    @property size_t length() const {
        return(_values.length);
    }

    /**
     * Property getter for the list of values maintained by the state. Note
     * that the value returned are copies of those held within the state.
     */
    @property Variant[] values() const {
        return(_values.map!(e => e.value).array);
    }

    /**
     * This function adds a value to the list maintained by the state.
     */
    void add(T)(T value) {
        _values ~= new BaseSQLValue(value);
    }

    private BaseSQLValue[] _values;
}

/**
 * The SQLGenerator interface defines a set of functions to be implemented by
 * all entities that will be called upon to generate SQL code.
 */
interface SQLGenerator {
    /**
     * Generates SQL code and inlines any data values that are part of that
     * code. Code is generated with a default set of configuration settings.
     */
    string toRawSQL() const;

    /**
     * Generates SQL code and inlines any data values that are part of that
     * code. Code is generated with a specified set of configuration settings.
     */
    string toRawSQL(GeneratorSettings settings) const;

    /**
     * Generates SQL code and returns the code plus a collection of the data
     * values needed to run the code. Values are replaced inline in the code
     * with number placeholders (e.g. $1, $2 etc.). Code is generated with a
     * default set of configuration settings.
     */
    string toSQL(ref GeneratorState state) const;

    /**
     * Generates SQL code and returns the code plus a collection of the data
     * values needed to run the code. Values are replaced inline in the code
     * with number placeholders (e.g. $1, $2 etc.). Code is generated with a
     * specified set of configuration settings.
     */
    string toSQL(ref GeneratorState state, GeneratorSettings settings) const;
}

//==============================================================================
// Unit Tests
//==============================================================================
unittest {
    import std.exception;
    import std.stdio;

    writeln("  Running unit tests for the ", __FILE__, " file.");

    //##########################################################################
    // GeneratorState
    //##########################################################################
    auto state = GeneratorState();
    assert(state.length == 0);
    assert(state.values == []);

    state.add(1234);
    assert(state.length == 1);
    state.add("Text.");
    assert(state.length == 2);

    assert(state.values[0].get!int() == 1234);
    assert(state.values[1].get!string() == "Text.");

    //##########################################################################
    // GeneratorSettings
    //##########################################################################
    auto settings = GeneratorSettings.defaults();

    assert(!settings.qualifyNames);
    assert(!settings.quoteNames);

    settings.qualifyNames = true;
    settings.quoteNames = true;
    auto copy = GeneratorSettings(settings);
    assert(settings.qualifyNames);
    assert(settings.quoteNames);
}