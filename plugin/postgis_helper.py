import psycopg2
import psycopg2.extras

import re


class PostgisUtils:
    def __init__(self, parent, conString):
        self.parent = parent
        self.conString = conString

    def read_db_schemas(self):
        """Create, open and read schemas from database
        and close connection"""
        conn = None
        schemas = []
        try:
            conn = psycopg2.connect(self.conString)
            cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
            getSchemas = """WITH "names"("name") AS (
                          SELECT n.nspname AS "name"
                            FROM pg_catalog.pg_namespace n
                              WHERE n.nspname !~ '^pg_'
                                AND n.nspname <> 'information_schema'
                        ) SELECT "name",
                          pg_catalog.has_schema_privilege(current_user, "name", 'CREATE') AS "create",
                          pg_catalog.has_schema_privilege(current_user, "name", 'USAGE') AS "usage"
                            FROM "names"
                         where pg_catalog.has_schema_privilege(current_user, "name", 'CREATE') and 
                         pg_catalog.has_schema_privilege(current_user, "name", 'USAGE')
                         order by 1;"""
            cur.execute(getSchemas)
            rows = cur.fetchall()
            for row in rows:
                schemas.append(row["name"])
                # self.parent.plainTextEdit.appendPlainText(
                #     "Schema: {0}\n".format(row["Name"]))
        except (Exception, psycopg2.Error) as error:
            raise ValueError(
                "Error while connecting to PostgreSQL {0}".format(error))
        finally:
            if (conn):
                cur.close()
                conn.close()
            return schemas

    def run_file(self, path):
        conn = None
        try:
            conn = psycopg2.connect(self.conString)
            # make sure other inserts will run if just one fails
            conn.set_isolation_level(psycopg2.extensions.ISOLATION_LEVEL_AUTOCOMMIT)
            cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

            with open(path, "r", encoding='utf-8') as f:
                cnt = f.read()
            if len(cnt) > 1:
                cur.execute(cnt)
                # conn.commit()
        except (Exception, psycopg2.Error) as error:
            raise ValueError(
                "Error while connecting to PostgreSQL {0}".format(error))
        finally:
            if (conn):
                cur.close()
                conn.close()

    def run_query(self, sql, writer=None, no_fetch=False):
        conn = None
        res = None
        try:
            conn = psycopg2.connect(self.conString)
            cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

            if len(sql) > 1:
                cur.execute(sql)
                if writer is not None:
                    for notice in conn.notices:
                        writer(f'NOTICE: {notice}.')
                conn.commit()
                if re.match(r'^SELECT [1-9]+', cur.statusmessage) and no_fetch is False:
                    res = cur.fetchall()
        except (Exception, psycopg2.Error) as error:
            raise ValueError(
                "Error while connecting to PostgreSQL {0}".format(error))
        finally:
            if (conn):
                cur.close()
                conn.close()

        return res

    def run_query_autocommit(self, sql, writer=None):
        conn = None
        res = None
        try:
            conn = psycopg2.connect(self.conString)
            conn.autocommit = True
            cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

            if len(sql) > 1:
                cur.execute(sql)
                if writer is not None:
                    for notice in conn.notices:
                        writer(f'NOTICE: {notice}.')
                if re.match(r'^SELECT [1-9]+', cur.statusmessage):
                    res = cur.fetchall()
        except (Exception, psycopg2.Error) as error:
            raise ValueError(
                "Error while connecting to PostgreSQL {0}".format(error))
        finally:
            if (conn):
                cur.close()
                conn.close()

        return res

    def get_connection(self):
        conn = None
        try:
            conn = psycopg2.connect(self.conString)
            conn.autocommit = True
        except (Exception, psycopg2.Error) as error:
            raise ValueError(
                "Error while connecting to PostgreSQL {0}".format(error))

        return conn

    def run_query_with_conn(self, conn, sql, writer=None, ignore_result=False):
        res = None
        try:
            cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
            if len(sql) > 1:
                cur.execute(sql)
                if writer is not None:
                    for notice in conn.notices:
                        writer(f'NOTICE: {notice}.')
                if re.match(r'^SELECT [1-9]+', cur.statusmessage) and ignore_result is not True:
                    res = cur.fetchall()
        except (Exception, psycopg2.Error) as error:
            raise ValueError(
                "Error while connecting to PostgreSQL {0}".format(error))
        finally:
            if (cur):
                cur.close()

        return res

    def run_file_with_conn(self, conn, path):
        try:
            cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)
            with open(path, "r", encoding='utf-8') as f:
                cnt = f.read()
            if len(cnt) > 1:
                cur.execute(cnt)
                # conn.commit()
        except (Exception, psycopg2.Error) as error:
            raise ValueError(
                "Error while connecting to PostgreSQL {0}".format(error))
        finally:
            if (cur):
                cur.close()