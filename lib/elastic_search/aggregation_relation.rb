
module ElasticSearch
  # The ElasticSearch::AggregationRelation class puts together everything
  # required to use the ElasticSearch aggregation framework via mixins and
  # adds a method to convert it to a hash format to be used in the request.

  class AggregationRelation
    include ElasticSearch::FilterableRelation
    include ElasticSearch::AggregatableRelation

    # @api private
    #
    # Converts the aggregation to a hash format that can be used in the request.
    #
    # @return [Hash] A hash version of the aggregation

    def to_hash
      res = {}
      res[:aggregations] = aggregation_values if aggregation_values.present?

      if must_values || must_not_values || should_values || filter_values
        if ElasticSearch.version.to_i >= 2
          res[:filter] = {
            bool: {}.
              merge(must_values ? { must: must_values } : {}).
              merge(must_not_values ? { must_not: must_not_values } : {}).
              merge(should_values ? { should: should_values } : {}).
              merge(filter_values ? { filter: filter_values } : {})
          }
        else
          filters = (filter_values || []) + (must_not_values || []).map { |must_not_value| { not: must_not_value } }

          queries = {}.
            merge(must_values ? { must: must_values } : {}).
            merge(should_values ? { should: should_values } : {})

          filters_and_queries = filters + (queries.size > 0 ? [bool: queries] : [])

          res[:filter] = filters_and_queries.size > 1 ? { and: filters_and_queries } : filters_and_queries.first
        end
      end

      res
    end

    # @api private
    #
    # Simply dups the object for api compatability.
    #
    # @return [ElasticSearch::AggregationRelation] The dupped object

    def fresh
      dup
    end
  end
end

