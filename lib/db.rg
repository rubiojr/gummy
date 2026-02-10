# gummy/db — Database handle, model factory, CRUD operations.
#
# The db module is the core of Gummy. It provides:
#
# - db.open(path) — open a database, returns a connection handle
# - conn.model(name, columns) — define a model, returns a model handle
# - conn.tx(fn) — run a transaction
# - conn.close() — close the database
#
# Model handles provide:
#
# - Model.insert(attrs) — insert a record, returns it with .id
# - Model.find(id) — find by id, returns record or nil
# - Model.all() — all records
# - Model.where(conditions) — filtered records (hash conditions)
# - Model.first(conditions) — first match or nil
# - Model.count(conditions) — count records (pass nil for all)
# - Model.pluck(column) — array of values from one column
# - Model.exists(conditions) — true if any match
# - Model.each(fn) — iterate with lambda
# - Model.map(fn) — transform with lambda
# - Model.destroy(conditions) — delete matching records
# - Model.update_all(conditions, attrs) — bulk update
# - Model.searchable(columns) — enable FTS5 (see fts module)
# - Model.search(query, opts) — full text search (see fts module)
#
# Records returned by insert/find/all/where/first have:
#
# - record.save() — persist field changes back to the database
# - record.delete() — remove the record from the database
#
# Hash conditions use the key for column and operator:
#
#   {name: "Alice"}           — name = 'Alice'
#   {"age >=" => 18}          — age >= 18
#   {"email LIKE" => "%@x.com"} — email LIKE '%@x.com'
#   {name: "Alice", "age >=" => 18} — AND'd together

use "sqlite"
use "str"
use "conv"
require "sql"
require "fts"

# Open a database and return a connection handle.
# Enables WAL mode, foreign keys, and a 5s busy timeout.
# The handle has .model(), .tx(), and .close() methods.
def open(path)
  conn = sqlite.open(path)
  sqlite.exec(conn, "PRAGMA journal_mode=WAL")
  sqlite.exec(conn, "PRAGMA foreign_keys=ON")
  sqlite.exec(conn, "PRAGMA busy_timeout=5000")

  handle = {}

  handle["model"] = fn(name, columns)
    return _make_model(conn, name, columns)
  end

  handle["tx"] = fn(callback)
    sqlite.exec(conn, "BEGIN")
    result = try callback() or err
      sqlite.exec(conn, "ROLLBACK")
      raise("gummy: transaction failed: " + err)
    end
    sqlite.exec(conn, "COMMIT")
    return result
  end

  handle["close"] = fn()
    sqlite.close(conn)
  end

  return handle
end

# --- model factory ---

def _make_model(conn, name, columns)
  col_defs = []
  col_names = []
  for key, val in columns
    col_defs = append(col_defs, key + " " + str.upper(val))
    col_names = append(col_names, key)
  end

  create_sql = "CREATE TABLE IF NOT EXISTS " + name + " (id INTEGER PRIMARY KEY"
  for c in col_defs
    create_sql = create_sql + ", " + c
  end
  create_sql = create_sql + ")"
  sqlite.exec(conn, create_sql)

  model = {}
  model["__conn__"] = conn
  model["__table__"] = name
  model["__columns__"] = col_names

  model["insert"] = fn(attrs)
    return _insert(conn, name, attrs)
  end

  model["find"] = fn(id)
    return _find(conn, name, id)
  end

  model["all"] = fn()
    return _all(conn, name)
  end

  model["where"] = fn(conditions)
    return _where(conn, name, conditions)
  end

  model["first"] = fn(conditions)
    return _first(conn, name, conditions)
  end

  model["count"] = fn(conditions)
    return _count(conn, name, conditions)
  end

  model["pluck"] = fn(column)
    return _pluck(conn, name, column)
  end

  model["exists"] = fn(conditions)
    return _count(conn, name, conditions) > 0
  end

  model["each"] = fn(callback)
    rows = _all(conn, name)
    for row in rows
      callback(row)
    end
  end

  model["map"] = fn(callback)
    rows = _all(conn, name)
    result = []
    for row in rows
      result = append(result, callback(row))
    end
    return result
  end

  model["destroy"] = fn(conditions)
    clause = sql.build_where(conditions)
    return sqlite.exec(conn, "DELETE FROM " + name + " WHERE " + clause)
  end

  model["update_all"] = fn(conditions, attrs)
    sets = []
    for key, val in attrs
      sql.validate_ident(key, "column")
      sets = append(sets, key + " = " + sql.quote(val))
    end
    clause = sql.build_where(conditions)
    return sqlite.exec(conn, "UPDATE " + name + " SET " + str.join(sets, ", ") + " WHERE " + clause)
  end

  model["searchable"] = fn(columns)
    model["__fts_columns__"] = columns
    fts.enable(model)
    model["search"] = fn(query, opts)
      return fts.search(model, query, opts)
    end
  end

  return model
end

# Attach save() and delete() closures to a database row.
# Returns the row hash with .save() and .delete() methods.
def make_record(conn, table, row)
  row["save"] = fn()
    id = row["id"]
    sets = []
    for key, val in row
      if key != "id" && key != "save" && key != "delete" && key != "rank" && key != "snippet" && !str.starts_with(key, "hl_")
        sets = append(sets, key + " = " + sql.quote(val))
      end
    end
    s = "UPDATE " + table + " SET " + str.join(sets, ", ") + " WHERE id = " + conv.to_s(id)
    return sqlite.exec(conn, s)
  end

  row["delete"] = fn()
    return sqlite.exec(conn, "DELETE FROM " + table + " WHERE id = ?", row["id"])
  end

  return row
end

# --- CRUD ---

def _insert(conn, table, attrs)
  names = []
  values = []
  for key, val in attrs
    sql.validate_ident(key, "column")
    names = append(names, key)
    values = append(values, sql.quote(val))
  end
  s = "INSERT INTO " + table + " (" + str.join(names, ", ") + ") VALUES (" + str.join(values, ", ") + ")"
  sqlite.exec(conn, s)
  id = sqlite.query_val(conn, "SELECT last_insert_rowid()")
  row = sqlite.query_row(conn, "SELECT * FROM " + table + " WHERE id = ?", id)
  return make_record(conn, table, row)
end

def _find(conn, table, id)
  row = sqlite.query_row(conn, "SELECT * FROM " + table + " WHERE id = ?", id)
  if row == nil
    return nil
  end
  return make_record(conn, table, row)
end

def _all(conn, table)
  rows = sqlite.query(conn, "SELECT * FROM " + table)
  result = []
  for row in rows
    result = append(result, make_record(conn, table, row))
  end
  return result
end

def _where(conn, table, conditions)
  clause = sql.build_where(conditions)
  rows = sqlite.query(conn, "SELECT * FROM " + table + " WHERE " + clause)
  result = []
  for row in rows
    result = append(result, make_record(conn, table, row))
  end
  return result
end

def _first(conn, table, conditions)
  clause = sql.build_where(conditions)
  row = sqlite.query_row(conn, "SELECT * FROM " + table + " WHERE " + clause + " LIMIT 1")
  if row == nil
    return nil
  end
  return make_record(conn, table, row)
end

def _count(conn, table, conditions)
  if conditions == nil
    return sqlite.query_val(conn, "SELECT COUNT(*) FROM " + table)
  end
  clause = sql.build_where(conditions)
  return sqlite.query_val(conn, "SELECT COUNT(*) FROM " + table + " WHERE " + clause)
end

def _pluck(conn, table, column)
  sql.validate_ident(column, "column")
  rows = sqlite.query(conn, "SELECT " + column + " FROM " + table)
  result = []
  for row in rows
    result = append(result, row[column])
  end
  return result
end
