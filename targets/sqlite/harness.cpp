#include <cstddef>
#include <cstdint>
#include <cstdlib>
#include <cstring>

#include <sqlite3.h>

#ifndef SQLITE_PREPARE_PERSISTENT
#define SQLITE_PREPARE_PERSISTENT 0
#endif

static bool env_enabled(const char* name) {
    const char* v = std::getenv(name);
    return v &&
           (std::strcmp(v, "1") == 0 ||
            std::strcmp(v, "true") == 0 ||
            std::strcmp(v, "TRUE") == 0);
}

static bool contains_demo_trigger(const char* buf) {
    return std::strstr(buf, "CRASHME") != nullptr;
}

static void trigger_demo_asan_use_after_free() {
    char* p = static_cast<char*>(std::malloc(8));
    if (!p) return;

    std::memset(p, 'A', 8);
    std::free(p);

    volatile char* vp = p;
    *vp = 'X';
}

static void exec_script(sqlite3* db, const char* sql) {
    char* err = nullptr;
    sqlite3_exec(db, sql, nullptr, nullptr, &err);
    if (err) {
        sqlite3_free(err);
    }
}

static int prepare_stmt(sqlite3* db, const char* sql, sqlite3_stmt** stmt, const char** next) {
#if defined(SQLITE_VERSION_NUMBER) && SQLITE_VERSION_NUMBER >= 3020000
    return sqlite3_prepare_v3(
        db,
        sql,
        -1,
        SQLITE_PREPARE_PERSISTENT,
        stmt,
        next
    );
#else
    return sqlite3_prepare_v2(
        db,
        sql,
        -1,
        stmt,
        next
    );
#endif
}

static void exercise_prepared_statements(sqlite3* db, const char* sql) {
    const char* tail = sql;
    int budget = 64;

    while (*tail && budget-- > 0) {
        sqlite3_stmt* stmt = nullptr;
        const char* next = nullptr;

        int rc = prepare_stmt(db, tail, &stmt, &next);

        if (rc != SQLITE_OK) {
            break;
        }

        if (!stmt) {
            if (!next || next == tail) {
                break;
            }
            tail = next;
            continue;
        }

        int step_budget = 16;
        while (step_budget-- > 0) {
            rc = sqlite3_step(stmt);
            if (rc == SQLITE_ROW) {
                int cols = sqlite3_column_count(stmt);
                for (int i = 0; i < cols; ++i) {
                    (void)sqlite3_column_type(stmt, i);
                    (void)sqlite3_column_bytes(stmt, i);
                    (void)sqlite3_column_int64(stmt, i);
                    (void)sqlite3_column_double(stmt, i);
                    (void)sqlite3_column_text(stmt, i);
                    (void)sqlite3_column_blob(stmt, i);
                }
                continue;
            }
            break;
        }

        sqlite3_finalize(stmt);

        if (!next || next == tail) {
            break;
        }
        tail = next;
    }
}

static void exercise_backup(sqlite3* src_db) {
    sqlite3* dst_db = nullptr;
    if (sqlite3_open(":memory:", &dst_db) != SQLITE_OK) {
        if (dst_db) sqlite3_close(dst_db);
        return;
    }

    sqlite3_backup* backup = sqlite3_backup_init(dst_db, "main", src_db, "main");
    if (backup) {
        sqlite3_backup_step(backup, -1);
        sqlite3_backup_finish(backup);
    }

    sqlite3_close(dst_db);
}

static void exercise_serialize(sqlite3* db) {
#if defined(SQLITE_VERSION_NUMBER) && SQLITE_VERSION_NUMBER >= 3019000
    sqlite3_int64 out_size = 0;
    unsigned char* image = sqlite3_serialize(db, "main", &out_size, 0);
    if (image) {
        sqlite3_free(image);
    }
#else
    (void)db;
#endif
}

static void configure_db(sqlite3* db) {
#ifdef SQLITE_DBCONFIG_DEFENSIVE
    sqlite3_db_config(db, SQLITE_DBCONFIG_DEFENSIVE, 1, nullptr);
#endif

#ifdef SQLITE_DBCONFIG_ENABLE_TRIGGER
    sqlite3_db_config(db, SQLITE_DBCONFIG_ENABLE_TRIGGER, 1, nullptr);
#endif

#ifdef SQLITE_DBCONFIG_ENABLE_VIEW
    sqlite3_db_config(db, SQLITE_DBCONFIG_ENABLE_VIEW, 1, nullptr);
#endif

    sqlite3_limit(db, SQLITE_LIMIT_SQL_LENGTH, 1 << 20);
    sqlite3_limit(db, SQLITE_LIMIT_EXPR_DEPTH, 200);
    sqlite3_limit(db, SQLITE_LIMIT_COMPOUND_SELECT, 50);
}

static void prime_db(sqlite3* db) {
    exec_script(db, "PRAGMA foreign_keys=ON;");
    exec_script(db, "PRAGMA journal_mode=OFF;");
    exec_script(db, "PRAGMA synchronous=OFF;");
    exec_script(db, "CREATE TABLE IF NOT EXISTS fuzz(a, b, c);");
    exec_script(db, "CREATE TEMP TABLE IF NOT EXISTS temp_fuzz(x);");
}

extern "C" int LLVMFuzzerTestOneInput(const uint8_t* data, size_t size) {
    if (size == 0 || size > 65536) {
        return 0;
    }

    char* buf = static_cast<char*>(std::malloc(size + 1));
    if (!buf) {
        return 0;
    }

    std::memcpy(buf, data, size);
    buf[size] = '\0';

    if (env_enabled("FUZZPIPE_DEMO_CRASH") && contains_demo_trigger(buf)) {
        trigger_demo_asan_use_after_free();
        std::free(buf);
        return 0;
    }

    sqlite3* db = nullptr;
    if (sqlite3_open(":memory:", &db) != SQLITE_OK) {
        if (db) sqlite3_close(db);
        std::free(buf);
        return 0;
    }

    configure_db(db);
    prime_db(db);

    (void)sqlite3_complete(buf);
    exec_script(db, buf);
    exercise_prepared_statements(db, buf);
    exercise_backup(db);
    exercise_serialize(db);

    sqlite3_close(db);

    sqlite3* db2 = nullptr;
    if (sqlite3_open(":memory:", &db2) == SQLITE_OK) {
        configure_db(db2);
        prime_db(db2);
        exec_script(db2, buf);
        exercise_prepared_statements(db2, buf);
        sqlite3_close(db2);
    }

    std::free(buf);
    return 0;
}
