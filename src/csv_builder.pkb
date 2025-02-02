create or replace package body csv_builder AS

    -- Types, from "Oracle Build-in Data Types" in the SQL language reference
    VARCHAR2_TYPE                       constant number := 1;
    NUMBER_TYPE                         constant number := 2;
    LONG_TYPE                           constant number := 8;
    DATE_TYPE                           constant number := 12;
    BINARY_FLOAT_TYPE                   constant number := 100;
    BINARY_DOUBLE_TYPE                  constant number := 101;
    TIMESTAMP_TYPE                      constant number := 180;
    TIMESTAMP_WITH_TZ_TYPE              constant number := 181;
    TIMESTAMP_WITH_LOCAL_TZ_TYPE        constant number := 231;
    INTERVAL_YM_TYPE                    constant number := 182;
    INTERVAL_DS_TYPE                    constant number := 183;
    RAW_TYPE                            constant number := 23;
    LONG_RAW_TYPE                       constant number := 24;
    ROWID_TYPE                          constant number := 69;
    UROWID_TYPE                         constant number := 208;
    CHAR_TYPE                           constant number := 96;
    CLOB_TYPE                           constant number := 112;
    BLOB_TYPE                           constant number := 113;
    BFILE_TYPE                          constant number := 114;
    JSON_TYPE                           constant number := 119;
    BOOLEAN_TYPE                        constant number := 252;
    VECTOR_TYPE                         constant number := 127;


    -- Wraps a column value with the quote character, possibly escaping it
    function wrap_column( p_col in clob, p_quote_char in varchar2, p_escape_char in varchar, p_quote_strings in boolean ) return clob is
        l_returnval                     clob;
    begin
        if p_quote_strings then
            l_returnval := p_quote_char || 
                replace( p_col, p_quote_char, p_escape_char || p_quote_char ) ||
                p_quote_char;
        else
            l_returnval := p_col;
        end if;
        return l_returnval;
    end wrap_column;


    -- Generate CSV data from a SQL query
    function query_to_csv(
          p_query in clob
        , p_delimiter in varchar2 default ','
        , p_quote_char in varchar2 default '"'
        , p_escape_char in varchar2 default '"'
        , p_include_headers in boolean default true
        , p_quote_strings in boolean default true
        , p_quote_dates in boolean default true
        , p_end_of_line in varchar2 default chr(13) || chr(10)
    ) return clob is
        c                               number;
        l_col_cnt                       integer;
        l_desc                          dbms_sql.desc_tab2;
        l_csv                           clob;
        l_first_col                     boolean;
        l_dummy                         integer;

        l_number                        number;
        l_varchar                       varchar2(4000);
        l_date                          date;
        l_timestamp                     timestamp;
        l_timestamp_tz                  timestamp with time zone;
        l_clob                          clob;

        -- not handling (yet?)
        /*
        blob
        nested table
        raw
        bfile
        interval
        long
        rowid
        json vector
        */

    begin
        c := dbms_sql.open_cursor();
        dbms_sql.parse(
              c => c
            , statement => p_query
            , language_flag => dbms_sql.NATIVE
        );
        dbms_sql.describe_columns2(
            c => c
            , col_cnt => l_col_cnt
            , desc_t => l_desc
        );
        l_first_col := true;
        for i in 1..l_col_cnt loop
            case 
                when l_desc(i).col_type = VARCHAR2_TYPE or l_desc(i).col_type = CHAR_TYPE
                    then dbms_sql.define_column( c, i, l_varchar, l_desc(i).col_max_len );
                when l_desc(i).col_type = NUMBER_TYPE or l_desc(i).col_type = BINARY_FLOAT_TYPE 
                        or l_desc(i).col_type = BINARY_DOUBLE_TYPE
                    then dbms_sql.define_column( c, i, l_number );
                when l_desc(i).col_type = DATE_TYPE
                    then dbms_sql.define_column( c, i, l_date );
                when l_desc(i).col_type = TIMESTAMP_TYPE
                    then dbms_sql.define_column( c, i, l_timestamp );
                when l_desc(i).col_type = TIMESTAMP_WITH_TZ_TYPE 
                        or l_desc(i).col_type = TIMESTAMP_WITH_LOCAL_TZ_TYPE
                    then dbms_sql.define_column( c, i, l_timestamp_tz );
                when l_desc(i).col_type = CLOB_TYPE
                    then dbms_sql.define_column( c, i, l_clob );
                else
                    raise_application_error( -20001, 'Unsupported SQL type ' || to_char( l_desc(i).col_type ));
            end case;

            -- Build the header row as we go
            if p_include_headers then
                l_csv := l_csv || 
                    case l_first_col when true then null else p_delimiter end ||
                    wrap_column( l_desc(i).col_name, p_quote_char, p_escape_char, p_quote_strings );
            end if;
            l_first_col := false;
        end loop;
        if p_include_headers then
            l_csv := l_csv || p_end_of_line;
        end if;

        -- This loops one row at a time, might be faster if selecting into arrays
        l_dummy := dbms_sql.execute( c );
        loop
            exit when dbms_sql.fetch_rows( c ) != 1;
            l_first_col := true;
            for i in 1..l_col_cnt loop
            l_csv := l_csv || case l_first_col when true then null else p_delimiter end;
                case 
                    when l_desc(i).col_type = VARCHAR2_TYPE or l_desc(i).col_type = CHAR_TYPE
                        then dbms_sql.column_value( c, i, l_varchar );
                        l_csv := l_csv || wrap_column( l_varchar, p_quote_char, p_escape_char, p_quote_strings);
                    when l_desc(i).col_type = NUMBER_TYPE or l_desc(i).col_type = BINARY_FLOAT_TYPE 
                            or l_desc(i).col_type = BINARY_DOUBLE_TYPE
                        then dbms_sql.column_value( c, i, l_number );
                        l_csv := l_csv || wrap_column( to_char( l_number ), p_quote_char, p_escape_char, false );
                    when l_desc(i).col_type = DATE_TYPE
                        then dbms_sql.column_value( c, i, l_date );
                        l_csv := l_csv || wrap_column( to_char( l_date ), p_quote_char, p_escape_char, p_quote_strings);
                    when l_desc(i).col_type = TIMESTAMP_TYPE
                        then dbms_sql.column_value( c, i, l_timestamp );
                        l_csv := l_csv || wrap_column( to_char( l_timestamp ), p_quote_char, p_escape_char, p_quote_strings);
                    when l_desc(i).col_type = TIMESTAMP_WITH_TZ_TYPE 
                            or l_desc(i).col_type = TIMESTAMP_WITH_LOCAL_TZ_TYPE
                        then dbms_sql.column_value( c, i, l_timestamp_tz );
                        l_csv := l_csv || wrap_column( to_char( l_timestamp_tz ), p_quote_char, p_escape_char, p_quote_strings);
                    when l_desc(i).col_type = CLOB_TYPE
                        then dbms_sql.column_value( c, i, l_clob );
                        l_csv := l_csv || wrap_column( l_clob, p_quote_char, p_escape_char, p_quote_strings);
                    else
                        raise_application_error( -20001, 'Unsupported SQL type ' || to_char( l_desc(i).col_type ));
                end case;
                l_first_col := false;
            end loop;
            l_csv := l_csv || p_end_of_line;
        end loop;
        dbms_sql.close_cursor( c );
        return l_csv;

    exception when others then
        if c is not null then 
            dbms_sql.close_cursor( c );
        end if;
        raise;
    end query_to_csv;
end csv_builder;
/
