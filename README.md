# Gummy — A simple ORM for Rugo.

Gummy wraps the sqlite module with a clean, expressive API for
defining models and performing CRUD operations. Models return
smart records that can save and delete themselves.

Getting started:

```ruby
require "github.com/rubiojr/gummy" with db

conn = db.open(":memory:")
Users = conn.model("users", {name: "text", email: "text", age: "integer"})

alice = Users.insert({name: "Alice", email: "alice@example.com", age: 30})
puts alice.name

alice.name = "Alicia"
alice.save()

adults = Users.where({"age >=" => 18})
Users.each(fn(u) puts u.name end)

conn.close()
```

Full text search:

```ruby
Articles = conn.model("articles", {title: "text", body: "text"})
Articles.searchable(["title", "body"])
results = Articles.search("rugo", {highlight: ["<b>", "</b>"]})
```
