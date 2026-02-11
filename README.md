# Gummy 🐻

A tiny ORM with a big heart — for [Rugo](https://github.com/rubiojr/rugo).

Gummy wraps SQLite with a clean, expressive API. Define models, insert records, query with conditions — and get back smart objects that can save and delete themselves. No SQL strings, no ceremony.

## Quick taste

```ruby
require "github.com/rubiojr/gummy" with db

conn = db.open(":memory:")
Users = conn.model("users", {name: "text", email: "text", age: "integer"})

alice = Users.insert({name: "Alice", email: "alice@example.com", age: 30})
puts alice.name    # Alice

alice.name = "Alicia"
alice.save()       # persisted ✓
```

## Query like you think

```ruby
adults = Users.where({"age >=" => 18})
alice  = Users.first({name: "Alice"})
emails = Users.pluck("email")
count  = Users.tally(nil)

Users.for_each(fn(u) puts u.name end)
```

Hash conditions keep things readable — the key carries both the column and the operator:

```ruby
Users.where({"age >=" => 18})                   # age >= 18
Users.where({"email LIKE" => "%@example.com"})   # pattern match
Users.where({name: "Alice", "age >=" => 18})     # AND'd together
```

## Full text search

Built on SQLite FTS5 — just tell Gummy which columns to index:

```ruby
Articles = conn.model("articles", {title: "text", body: "text"})
Articles.searchable(["title", "body"])

results = Articles.search("rugo")
results = Articles.search("rugo", {highlight: ["<b>", "</b>"]})
```

## The full toolkit

| Method | What it does |
|--------|-------------|
| `Model.insert(attrs)` | Insert a record, get it back with `.id` |
| `Model.get(id)` | Find by id (or `nil`) |
| `Model.list()` | All records |
| `Model.where(conditions)` | Filtered records |
| `Model.first(conditions)` | First match (or `nil`) |
| `Model.tally(conditions)` | Count records (`nil` for all) |
| `Model.pluck(column)` | Array of values from one column |
| `Model.exists(conditions)` | `true` if any match |
| `Model.for_each(fn)` | Iterate with a lambda |
| `Model.collect(fn)` | Transform with a lambda |
| `Model.destroy(conditions)` | Delete matching records |
| `Model.update_all(conditions, attrs)` | Bulk update |
| `record.save()` | Persist field changes |
| `record.delete()` | Remove from database |

## Install

```
rugo get github.com/rubiojr/gummy
```
