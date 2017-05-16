
# ElasticSearch

[![Build Status](https://secure.travis-ci.org/mrkamel/elastic_search.png?branch=master)](http://travis-ci.org/mrkamel/elastic_search)

Using ElasticSearch it is dead-simple to create index classes that correspond
to ElasticSearch indices and to query these indices using a chainable, concise
yet powerful DSL.

```ruby
CommentIndex.search("hello world", default_field: "title").where(visible: true).aggregate(:user_id).sort(id: "desc")

CommentIndex.aggregate(:user_id) do |aggregation|
  aggregation.aggregate(histogram: { date_histogram: { field: "created_at", interval: "month" }})
end

CommentIndex.range(:created_at, gt: Date.today - 1.week, lt: Date.today).where(state: ["approved", "pending"])
```

## Reference Docs

See [http://www.rubydoc.info/github/mrkamel/elastic_search](http://www.rubydoc.info/github/mrkamel/elastic_search)

## Non-ActiveRecord models

The ElasticSearch gem ships with built-in support for ActiveRecord models, but
using non-ActiveRecord models is very easy. The model must implement a
`find_each` class method and the Index class needs to implement
`Index.record_id` and `Index.fetch_records`. The default implementations for
the index class are as follows:

```ruby
class MyIndex
  include ElasticSearch::Index

  def self.record_id(object)
    object.id
  end

  def self.fetch_records(ids)
    model.where(id: ids)
  end
end
```

Thus, simply add your custom implementation of those methods that work with
whatever ORM you use.

## TODO

1. Remove ActiveSupport dependencies

* `Hash#except` (can probably be removed)
* `Module#delegate`
* `Object#present?`
* `Object#blank?`

2. Add convenience mixin for re-indexing ActiveRecord models on callbacks

3. Documentation

4. Switch to httpary or http-rb and use custom exceptions

5. First class support for `nested`, `has_parent` and `has_child` queries

6. Support collapse

