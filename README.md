# sqlist

A library written in D to programmatically generate SQL code.

I created this library for my own personal use because I was fed up with
working with SQL strings embedded in code. The code is provided as-is with
no guarantees. What it is not...

 * It's not an ORM. It will generate SQL code, it's not going to run it
   against a database for you.
 * It's not guaranteed to generate SQL that is compliant with your RDBMS. I
   use Postgres and this currently meets my needs.

## Example Usage

Here is a short example of how you might use it...

```D
import std.algorithm;
import std.array;
import std.conv;
import std.datetime;
import std.stdio;
import std.string;
import derelict.pq.pq;
import sqlist;

void main()
{
    auto databaseURI = "postgres://user_name:password@host:port/database";

    // Load Postgres and get a connection.
    DerelictPQ.load();
    auto connection = PQconnectdb(databaseURI.toStringz());
    scope(exit) PQfinish(connection);

    // Insert a record into a users table.
    auto insert = new Insert("users");
    insert.set("email", "nobody@nowhere.com");
    insert.set("first_name", "Joe");
    insert.set("last_name", "Bloggs");
    insert.set("age", to!string(25));
    insert.set("created_at", new SQLFunction("now"));
    insert.set("updated_at", new SQLFunction("now"));
    insert.returning("id");

    auto      output     = insert.toSQL();
    uint[]    oids       = new uint[output.data.length];
    int[]     lengths    = new int[output.data.length];
    int[]     formats    = new int[output.data.length];
    ubyte*[]  parameters = new ubyte*[output.data.length];

    writeln("SQL: ", output.sql, "\nValues:\n", output.data.map!(e => e.get!(string)).array.join("\n  "));
    for(auto i = 0; i < output.data.length; i++) {
        lengths[i]    = to!int(output.data[i].length);
        parameters[i] = cast(ubyte*)output.data[i].get!string().toStringz();
    }

    auto insertResult = PQexecParams(connection,
                                     output.sql.toStringz(),
                                     to!int(parameters.length),
                                     oids.ptr,
                                     cast(const(ubyte*)*)parameters.ptr,
                                     lengths.ptr,
                                     formats.ptr,
                                     0);
    scope(exit) PQclear(insertResult);
    if(PQresultStatus(insertResult) != PGRES_TUPLES_OK) {
        throw(new Exception(format("Failed to insert record. Cause: %s", PQresultErrorMessage(insertResult).fromStringz())));
    }
    auto recordId = to!long(fromStringz(cast(char*)PQgetvalue(insertResult, 0, 0)));

    // Fetch the record back using it's id.
    auto query     = new Query("users");
    auto functions = [new SQLFunction("to_char"),
                      new SQLFunction("to_char")];

    functions[0].add(FieldName.parse("created_at"));
    functions[0].add("YYYY-Mon-DD HH24:MI:SS.US");
    functions[1].add(FieldName.parse("updated_at"));
    functions[1].add("YYYY-Mon-DD HH24:MI:SS.US");

    query.select("email", "first_name", "last_name", "age");
    query.select(functions[0], functions[1]);
    query.where.and("id", to!string(recordId));
    output = query.toSQL();

    oids       = new uint[output.data.length];
    lengths    = new int[output.data.length];
    formats    = new int[output.data.length];
    parameters = new ubyte*[output.data.length];

    writeln("SQL: ", output.sql, "\nValues:\n", output.data.map!(e => e.get!(string)).array.join("\n  "));
    for(auto i = 0; i < output.data.length; i++) {
        lengths[i]    = to!int(output.data[i].length);
        parameters[i] = cast(ubyte*)output.data[i].get!string().toStringz();
    }

    auto queryResult = PQexecParams(connection,
                                    output.sql.toStringz(),
                                    to!int(parameters.length),
                                    oids.ptr,
                                    cast(const(ubyte*)*)parameters.ptr,
                                    lengths.ptr,
                                    formats.ptr,
                                    0);
    scope(exit) PQclear(queryResult);
    scope(exit) PQclear(queryResult);
    if(PQresultStatus(queryResult) != PGRES_TUPLES_OK) {
        throw(new Exception(format("Failed to retrieve record. Cause: %s", PQresultErrorMessage(queryResult).fromStringz())));
    }

    auto email     = fromStringz(cast(char*)PQgetvalue(queryResult, 0, 0));
    auto firstName = fromStringz(cast(char*)PQgetvalue(queryResult, 0, 1));
    auto lastName  = fromStringz(cast(char*)PQgetvalue(queryResult, 0, 2));
    auto age       = to!long(fromStringz(cast(char*)PQgetvalue(queryResult, 0, 3)));
    auto createdAt = SysTime.fromSimpleString(fromStringz(cast(char*)PQgetvalue(queryResult, 0, 4)));
    auto updatedAt = SysTime.fromSimpleString(fromStringz(cast(char*)PQgetvalue(queryResult, 0, 5)));

    writeln("User Details...",
            "  Email:      ", email,
            "  Name:       ", firstName, " ", lastName,
            "  Age:        ", age,
            "  Created At: ", createdAt,
            "  Updated At: ", updatedAt);
}
```