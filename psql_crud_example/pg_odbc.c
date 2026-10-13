
#include <stdio.h>
#include <string.h>
#include <sql.h>
#include <sqlext.h>

static char pg_last_error[512] = "";

static void save_odbc_error(
    SQLSMALLINT handle_type,
    SQLHANDLE handle
)
{
    SQLCHAR state[6] = {0};
    SQLINTEGER native_error = 0;
    SQLCHAR message[450] = {0};
    SQLSMALLINT message_length = 0;

    SQLRETURN rc = SQLGetDiagRec(
        handle_type, handle, 1,
        state, &native_error,
        message, sizeof(message),
        &message_length
    );

    if (SQL_SUCCEEDED(rc)) {
        snprintf(pg_last_error, sizeof(pg_last_error),
                 "[%.5s] %s", state, (char *)message);
    } else {
        snprintf(pg_last_error, sizeof(pg_last_error),
                 "No ODBC diagnostic available.");
    }
}

int pg_get_last_error(char *output, int capacity)
{
    if (capacity <= 0)
        return 1;

    snprintf(output, (size_t)capacity, "%s", pg_last_error);
    return 0;
}

int pg_get_employee(
    const char *employee_id,
    char *name_out,
    char *salary_out
)
{
    SQLHENV env = SQL_NULL_HENV;
    SQLHDBC dbc = SQL_NULL_HDBC;
    SQLHSTMT stmt = SQL_NULL_HSTMT;
    SQLRETURN rc;
    SQLCHAR name_buffer[31] = {0};
    SQLCHAR salary_buffer[32] = {0};
    SQLLEN name_length = 0;
    SQLLEN salary_length = 0;
    SQLLEN id_length = SQL_NTS;
    int result = 1;

    name_out[0] = '\0';
    salary_out[0] = '\0';

    rc = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLSetEnvAttr(
        env, SQL_ATTR_ODBC_VERSION,
        (SQLPOINTER)SQL_OV_ODBC3, 0
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLConnect(
        dbc,
        (SQLCHAR *)"COBOL_PG", SQL_NTS,
        (SQLCHAR *)"cobol_user", SQL_NTS,
        (SQLCHAR *)"cobol_dev_password", SQL_NTS
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLPrepare(
        stmt,
        (SQLCHAR *)
        "SELECT employee_name, salary "
        "FROM employees WHERE employee_id = ?",
        SQL_NTS
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLBindParameter(
        stmt, 1, SQL_PARAM_INPUT,
        SQL_C_CHAR, SQL_CHAR,
        5, 0, (SQLPOINTER)employee_id,
        5, &id_length
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLExecute(stmt);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLFetch(stmt);
    if (rc == SQL_NO_DATA) {
        result = 2;
        goto cleanup;
    }
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLGetData(
        stmt, 1, SQL_C_CHAR,
        name_buffer, sizeof(name_buffer),
        &name_length
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLGetData(
        stmt, 2, SQL_C_CHAR,
        salary_buffer, sizeof(salary_buffer),
        &salary_length
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    strncpy(name_out, (const char *)name_buffer, 30);
    name_out[30] = '\0';

    strncpy(salary_out, (const char *)salary_buffer, 31);
    salary_out[31] = '\0';

    result = 0;

cleanup:
    if (stmt != SQL_NULL_HSTMT)
        SQLFreeHandle(SQL_HANDLE_STMT, stmt);

    if (dbc != SQL_NULL_HDBC) {
        SQLDisconnect(dbc);
        SQLFreeHandle(SQL_HANDLE_DBC, dbc);
    }

    if (env != SQL_NULL_HENV)
        SQLFreeHandle(SQL_HANDLE_ENV, env);

    return result;
}

int pg_test_connection(void)
{
    SQLHENV env = SQL_NULL_HENV;
    SQLHDBC dbc = SQL_NULL_HDBC;
    SQLRETURN rc;
    int result = 1;

    rc = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLSetEnvAttr(
        env, SQL_ATTR_ODBC_VERSION,
        (SQLPOINTER)SQL_OV_ODBC3, 0
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLConnect(
        dbc,
        (SQLCHAR *)"COBOL_PG", SQL_NTS,
        (SQLCHAR *)"cobol_user", SQL_NTS,
        (SQLCHAR *)"cobol_dev_password", SQL_NTS
    );

    if (SQL_SUCCEEDED(rc))
        result = 0;

cleanup:
    if (dbc != SQL_NULL_HDBC) {
        if (result == 0)
            SQLDisconnect(dbc);
        SQLFreeHandle(SQL_HANDLE_DBC, dbc);
    }

    if (env != SQL_NULL_HENV)
        SQLFreeHandle(SQL_HANDLE_ENV, env);

    return result;
}


int pg_insert_employee(
    const char *employee_id,
    const char *employee_name,
    const char *salary
)
{
    pg_last_error[0] = '\0';

    SQLHENV env = SQL_NULL_HENV;
    SQLHDBC dbc = SQL_NULL_HDBC;
    SQLHSTMT stmt = SQL_NULL_HSTMT;
    SQLRETURN rc;
    SQLCHAR id[6] = {0};
    SQLCHAR name[31] = {0};
    SQLCHAR pay[13] = {0};
    SQLLEN id_len = SQL_NTS;
    SQLLEN name_len = SQL_NTS;
    SQLLEN pay_len = SQL_NTS;
    int connected = 0;
    int result = 1;

    /* Copy fixed-width COBOL fields and trim trailing spaces. */
    memcpy(id, employee_id, 5);
    memcpy(name, employee_name, 30);
    memcpy(pay, salary, 12);

    id[5] = '\0';
    name[30] = '\0';
    pay[12] = '\0';

    for (int i = 4; i >= 0 && id[i] == ' '; i--)
        id[i] = '\0';

    for (int i = 29; i >= 0 && name[i] == ' '; i--)
        name[i] = '\0';

    for (int i = 11; i >= 0 && pay[i] == ' '; i--)
        pay[i] = '\0';

    rc = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLSetEnvAttr(
        env, SQL_ATTR_ODBC_VERSION,
        (SQLPOINTER)SQL_OV_ODBC3, 0
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLConnect(
        dbc,
        (SQLCHAR *)"COBOL_PG", SQL_NTS,
        (SQLCHAR *)"cobol_user", SQL_NTS,
        (SQLCHAR *)"cobol_dev_password", SQL_NTS
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    connected = 1;

    rc = SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLPrepare(
        stmt,
        (SQLCHAR *)
        "INSERT INTO employees "
        "(employee_id, employee_name, salary) "
        "VALUES (?, ?, CAST(? AS NUMERIC))",
        SQL_NTS
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLBindParameter(
        stmt, 1, SQL_PARAM_INPUT,
        SQL_C_CHAR, SQL_CHAR,
        5, 0, id, sizeof(id), &id_len
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLBindParameter(
        stmt, 2, SQL_PARAM_INPUT,
        SQL_C_CHAR, SQL_VARCHAR,
        30, 0, name, sizeof(name), &name_len
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLBindParameter(
        stmt, 3, SQL_PARAM_INPUT,
        SQL_C_CHAR, SQL_VARCHAR,
        12, 0, pay, sizeof(pay), &pay_len
    );
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLExecute(stmt);
    if (SQL_SUCCEEDED(rc)) {
    result = 0;
    } else {
        save_odbc_error(SQL_HANDLE_STMT, stmt);
        goto cleanup;
    }

cleanup:
    if (stmt != SQL_NULL_HSTMT)
        SQLFreeHandle(SQL_HANDLE_STMT, stmt);

    if (connected)
        SQLDisconnect(dbc);

    if (dbc != SQL_NULL_HDBC)
        SQLFreeHandle(SQL_HANDLE_DBC, dbc);

    if (env != SQL_NULL_HENV)
        SQLFreeHandle(SQL_HANDLE_ENV, env);

    return result;
}

int pg_update_salary(const char *employee_id, const char *salary)
{
    pg_last_error[0] = '\0';

    SQLHENV env = SQL_NULL_HENV;
    SQLHDBC dbc = SQL_NULL_HDBC;
    SQLHSTMT stmt = SQL_NULL_HSTMT;
    SQLRETURN rc;
    SQLCHAR id[6] = {0};
    SQLCHAR pay[13] = {0};
    SQLLEN id_len = SQL_NTS;
    SQLLEN pay_len = SQL_NTS;
    int connected = 0;
    int result = 1;
    
    memcpy(id, employee_id, 5);
    memcpy(pay, salary, 12);
    id[5] = '\0';
    pay[12] = '\0';

    for (int i = 4; i >= 0 && id[i] == ' '; i--)
        id[i] = '\0';

    for (int i = 11; i >= 0 && pay[i] == ' '; i--)
        pay[i] = '\0';

    rc = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLSetEnvAttr(env, SQL_ATTR_ODBC_VERSION,
                       (SQLPOINTER)SQL_OV_ODBC3, 0);
    if (!SQL_SUCCEEDED(rc)) {
        save_odbc_error(SQL_HANDLE_ENV, env);
        goto cleanup;
    }

    rc = SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc);
    if (!SQL_SUCCEEDED(rc)) {
        save_odbc_error(SQL_HANDLE_ENV, env);
        goto cleanup;
    }

    rc = SQLConnect(dbc,
        (SQLCHAR *)"COBOL_PG", SQL_NTS,
        (SQLCHAR *)"cobol_user", SQL_NTS,
        (SQLCHAR *)"cobol_dev_password", SQL_NTS);

    if (!SQL_SUCCEEDED(rc)) {
        save_odbc_error(SQL_HANDLE_DBC, dbc);
        goto cleanup;
    }

    connected = 1;

    rc = SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt);
    if (!SQL_SUCCEEDED(rc)) {
        save_odbc_error(SQL_HANDLE_DBC, dbc);
        goto cleanup;
    }

    rc = SQLPrepare(stmt,
        (SQLCHAR *)"UPDATE employees SET salary = "
                   "CAST(? AS NUMERIC) WHERE employee_id = ?",
        SQL_NTS);
    if (!SQL_SUCCEEDED(rc)) {
        save_odbc_error(SQL_HANDLE_STMT, stmt);
        goto cleanup;
    }

    rc = SQLBindParameter(stmt, 1, SQL_PARAM_INPUT,
        SQL_C_CHAR, SQL_VARCHAR, 12, 0,
        pay, sizeof(pay), &pay_len);
    if (!SQL_SUCCEEDED(rc)) {
        save_odbc_error(SQL_HANDLE_STMT, stmt);
        goto cleanup;
    }

    rc = SQLBindParameter(stmt, 2, SQL_PARAM_INPUT,
        SQL_C_CHAR, SQL_CHAR, 5, 0,
        id, sizeof(id), &id_len);
    if (!SQL_SUCCEEDED(rc)) {
        save_odbc_error(SQL_HANDLE_STMT, stmt);
        goto cleanup;
    }

    rc = SQLExecute(stmt);
    if (rc == SQL_NO_DATA) {
        result = 2;
        goto cleanup;
    }

    if (!SQL_SUCCEEDED(rc)) {
        save_odbc_error(SQL_HANDLE_STMT, stmt);
        goto cleanup;
    }

    SQLLEN affected = 0;
    rc = SQLRowCount(stmt, &affected);
    if (SQL_SUCCEEDED(rc) && affected > 0)
        result = 0;
    else
        result = 2;

cleanup:
    if (stmt != SQL_NULL_HSTMT)
        SQLFreeHandle(SQL_HANDLE_STMT, stmt);

    if (connected)
        SQLDisconnect(dbc);

    if (dbc != SQL_NULL_HDBC)
        SQLFreeHandle(SQL_HANDLE_DBC, dbc);

    if (env != SQL_NULL_HENV)
        SQLFreeHandle(SQL_HANDLE_ENV, env);

    return result;
}

int pg_delete_employee(const char *employee_id)
{
    pg_last_error[0] = '\0';

    SQLHENV env = SQL_NULL_HENV;
    SQLHDBC dbc = SQL_NULL_HDBC;
    SQLHSTMT stmt = SQL_NULL_HSTMT;
    SQLRETURN rc;
    SQLCHAR id[6] = {0};
    SQLLEN id_len = SQL_NTS;
    SQLLEN affected = 0;
    int connected = 0;
    int result = 1;

    memcpy(id, employee_id, 5);
    id[5] = '\0';

    for (int i = 4; i >= 0 && id[i] == ' '; i--)
        id[i] = '\0';

    rc = SQLAllocHandle(SQL_HANDLE_ENV, SQL_NULL_HANDLE, &env);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLSetEnvAttr(env, SQL_ATTR_ODBC_VERSION,
                       (SQLPOINTER)SQL_OV_ODBC3, 0);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLAllocHandle(SQL_HANDLE_DBC, env, &dbc);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLConnect(dbc,
        (SQLCHAR *)"COBOL_PG", SQL_NTS,
        (SQLCHAR *)"cobol_user", SQL_NTS,
        (SQLCHAR *)"cobol_dev_password", SQL_NTS);

    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    connected = 1;

    rc = SQLAllocHandle(SQL_HANDLE_STMT, dbc, &stmt);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLPrepare(stmt,
        (SQLCHAR *)"DELETE FROM employees WHERE employee_id = ?",
        SQL_NTS);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLBindParameter(stmt, 1, SQL_PARAM_INPUT,
        SQL_C_CHAR, SQL_CHAR, 5, 0,
        id, sizeof(id), &id_len);
    if (!SQL_SUCCEEDED(rc))
        goto cleanup;

    rc = SQLExecute(stmt);
    if (rc == SQL_NO_DATA) {
        result = 2;
        goto cleanup;
    }

    if (!SQL_SUCCEEDED(rc)) {
        save_odbc_error(SQL_HANDLE_STMT, stmt);
        goto cleanup;
    }

    rc = SQLRowCount(stmt, &affected);
    if (SQL_SUCCEEDED(rc) && affected > 0)
        result = 0;
    else
        result = 2;

cleanup:
    if (stmt != SQL_NULL_HSTMT)
        SQLFreeHandle(SQL_HANDLE_STMT, stmt);

    if (connected)
        SQLDisconnect(dbc);

    if (dbc != SQL_NULL_HDBC)
        SQLFreeHandle(SQL_HANDLE_DBC, dbc);

    if (env != SQL_NULL_HENV)
        SQLFreeHandle(SQL_HANDLE_ENV, env);

    return result;
}

int pg_get_odbc_error(
    SQLSMALLINT handle_type,
    SQLHANDLE handle,
    char *message_out,
    SQLSMALLINT message_capacity
)
{
    SQLCHAR sql_state[6] = {0};
    SQLINTEGER native_error = 0;
    SQLCHAR message[512] = {0};
    SQLSMALLINT message_length = 0;

    if (message_capacity <= 0)
        return 1;

    message_out[0] = '\0';

    SQLRETURN rc = SQLGetDiagRec(
        handle_type,
        handle,
        1,
        sql_state,
        &native_error,
        message,
        sizeof(message),
        &message_length
    );

    if (!SQL_SUCCEEDED(rc))
        return 1;

    snprintf(
        message_out,
        (size_t)message_capacity,
        "[%.5s] %s",
        sql_state,
        (const char *)message
    );

    return 0;
}

