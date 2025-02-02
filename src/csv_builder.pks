create or replace package csv_builder
authid current_user
is
    /* 
    A package to generate CSV data from a query. The calling user must have execute
    permissons on DBMS_SQL.

    Who     Date        Description
    ------  ----------  ------------------------------------------------
    EAO     2025-02-01  Created

    */


    /**
    Generates CSV data from a query.

    @param p_query The query to execute
    @param p_delimiter Separator between columns
    @param p_quote_char Strings will be surrounded by this character
    @param p_escape_char If column contains the quote character, this will be inserted
    before the quote
    @param p_quote_strings Whether or not to surround strings with the quote character
    @param p_quote_dates Whether or not to surround dates with the quote character
    @param p_end_of_line Character sequence that ends a line, default to Windows style.
    */
    function query_to_csv(
          p_query in clob
        , p_delimiter in varchar2 default ','
        , p_quote_char in varchar2 default '"'
        , p_escape_char in varchar2 default '"'
        , p_include_headers in boolean default true
        , p_quote_strings in boolean default true
        , p_quote_dates in boolean default true
        , p_end_of_line in varchar2 default chr(13) || chr(10)
    ) return clob;

end csv_builder;
/
