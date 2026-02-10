# gummy/sql — SQL helpers for safe quoting and condition building.
#
# Provides identifier validation, operator whitelisting, and
# value quoting to prevent SQL injection.

use "str"
use "conv"
use "re"

# Validate a SQL identifier (table name, column name).
# Only allows [a-zA-Z_][a-zA-Z0-9_]*.
def validate_ident(name, context)
  if !re.match('^[a-zA-Z_][a-zA-Z0-9_]*$', name)
    raise("gummy: invalid " + context + ": " + name)
  end
  return name
end

# Validate a SQL operator.
Valid_ops = ["=", "!=", "<>", "<", ">", "<=", ">=", "LIKE", "NOT LIKE", "IS", "IS NOT"]

# Validate a SQL comparison operator.
# Only allows: =, !=, <>, <, >, <=, >=, LIKE, NOT LIKE, IS, IS NOT.
def validate_op(op)
  uop = str.upper(op)
  for valid in Valid_ops
    if uop == valid
      return op
    end
  end
  raise("gummy: invalid operator: " + op)
end

# Safely quote a value for SQL embedding.
def quote(val)
  if val == nil
    return "NULL"
  end
  t = type_of(val)
  if t == "Integer" || t == "Float"
    return conv.to_s(val)
  end
  if t == "Boolean"
    if val
      return "1"
    end
    return "0"
  end
  s = conv.to_s(val)
  s = str.replace(s, "'", "''")
  return "'" + s + "'"
end

# Escape a string for use inside SQL string literals (e.g. FTS5 function args).
def escape_string(val)
  return str.replace(val, "'", "''")
end

# Build a WHERE clause from a hash of conditions.
# Keys can include operators: {"age >=" => 18, name: "Alice"}
# Multiple conditions are AND'd.
def build_where(conditions)
  parts = []
  for key, val in conditions
    if str.contains(key, " ")
      tokens = str.split(key, " ")
      col = validate_ident(tokens[0], "column")
      op = validate_op(tokens[1])
      parts = append(parts, col + " " + op + " " + quote(val))
    else
      validate_ident(key, "column")
      parts = append(parts, key + " = " + quote(val))
    end
  end
  return str.join(parts, " AND ")
end
