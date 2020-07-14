module sqlist.exceptions;

/**
 * Base exception class to be used by library specific exceptions.
 */
class SQListException : Exception {
    /**
     * Constructor.
     */
    this(string message, string file=__FILE__, ulong line=__LINE__, Throwable nextInChain=null) {
        super(message, file, line, nextInChain);
    }
}
