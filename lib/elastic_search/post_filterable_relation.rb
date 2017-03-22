
module ElasticSearch
  # The ElasticSearch::PostFilterableRelation mixin provides chainable methods
  # like #post_where, #post_exists, #post_range, etc to add and apply search
  # filters after aggregations have already been calculated.
  #
  # @example
  #   query = ProductIndex.search("harry potter")
  #
  #   query = query.aggregate(price_ranges: {
  #     range: {
  #       field: "price",
  #       ranges: [
  #         { key: "range1", from: 0,  to: 20 },
  #         { key: "range2", from: 20, to: 50 },
  #         { key: "range3", from: 50, to: 100 }
  #       ]
  #     }
  #   })
  #
  #   query = query.post_where(price: 20 ... 50)

  module PostFilterableRelation
    def self.included(base)
      base.class_eval do
        attr_accessor :post_filter_values
      end
    end

    # Adds post filters to your relation for the supplied hash composed of
    # field-to-filter mappings which specify terms, term or range filters,
    # depending on the type of the respective hash value, namely array, range
    # or scalar type like Fixnum, String, etc.
    #
    # @example Array values
    #   query = CommentIndex.aggregate("...")
    #   query = query.post_where(id: [1, 2, 3], state: ["approved", "declined"])
    #
    # @example Range values
    #   query = CommentIndex.aggregate("...")
    #   query = query.post_where(created_at: Time.parse("2016-01-01") .. Time.parse("2017-01-01"))
    #
    # @example Scalar types
    #   query = CommentIndex.aggregate("...")
    #   query = query.post_where(id: 1, message: "hello world")
    #
    # @return [ElasticSearch::Relation] A newly created extended relation

    def post_where(hash)
      fresh.tap do |relation|
        relation.post_filter_values = (post_filter_values || []) + hash.collect do |key, value|
          if value.is_a?(Array)
            { terms: { key => value } }
          elsif value.is_a?(Range)
            { range: { key => { gte: value.min, lte: value.max } } }
          else
            { term: { key => value } }
          end
        end
      end
    end

    def post_where_not(hash)
      fresh.tap do |relation|
        relation.post_filter_values = (post_filter_values || []) + hash.collect do |key, value|
          if value.is_a?(Array)
            { not: { terms: { key => value } } }
          elsif value.is_a?(Range)
            { not: { range: { key => { gte: value.min, lte: value.max } } } }
          else
            { not: { term: { key => value } } }
          end
        end
      end
    end

    def post_filter(*args)
      fresh.tap do |relation|
        relation.post_filter_values = (post_filter_values || []) + args
      end
    end

    def post_range(field, options = {})
      post_filter range: { field => options }
    end

    def post_exists(field)
      post_filter exists: { field: field }
    end

    def post_exists_not(field)
      post_filter bool: { must_not: { exists: { field: field }}}
    end
  end
end

