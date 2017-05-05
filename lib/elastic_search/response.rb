
module ElasticSearch
  # The ElasticSearch::Response class wraps a raw ElasticSearch response and
  # decorates it with methods for aggregations, hits, records, pagination, etc.

  class Response
    attr_accessor :relation, :response

    # @api private
    #
    # Initializes a new response object for the provided relation and raw
    # ElasticSearch response.

    def initialize(relation, response)
      self.relation = relation
      self.response = response
    end

    # Returns the raw response, ie a hash derived from the ElasticSearch JSON
    # response.
    #
    # @example
    #   CommentIndex.search("hello world").raw_response
    #   # => {"took"=>3, "timed_out"=>false, "_shards"=>"..."}
    #
    # @return [Hash] The raw response hash

    def raw_response
      response
    end

    # Returns the total number of results.
    #
    # @example
    #   CommentIndex.search("hello world").total_entries
    #   # => 13
    #
    # @return [Fixnum] The total number of results

    def total_entries
      hits["total"]
    end

    # Returns the current page number, useful for pagination.
    #
    # @example
    #   CommentIndex.search("hello world").paginate(page: 10).current_page
    #   # => 10
    #
    # @return [Fixnum] The current page number

    def current_page
      1 + (relation.offset_value / relation.limit_value.to_f).ceil
    end

    # Returns the number of total pages for the current pagination settings, ie
    # per page/limit settings.
    #
    # @example
    #   CommentIndex.search("hello world").paginate(per_page: 60).total_pages
    #   # => 5
    #
    # @return [Fixnum] The total number of pages

    def total_pages
      [(total_entries / relation.limit_value.to_f).ceil, 1].max
    end

    # Returns the previous page number or nil if no previous page exists, ie if
    # the current page is the first page.
    #
    # @example
    #   CommentIndex.search("hello world").paginate(page: 2).previous_page
    #   # => 1
    #
    #   CommentIndex.search("hello world").paginate(page: 1).previous_page
    #   # => nil
    #
    # @return [Fixnum, nil] The previous page number

    def previous_page
      return nil if current_page <= 1
      return total_pages if current_page > total_pages

      current_page - 1
    end

    # Returns the next page number or nil if there is no next page, ie the
    # current page is the last page.
    #
    # @example
    #   CommentIndex.search("hello world").paginate(page: 2).next_page
    #   # => 3
    #
    # @return [Fixnum, nil] The next page number

    def next_page
      return nil if current_page >= total_pages
      return 1 if current_page < 1

      return current_page + 1
    end

    # Returns the results, ie hits, wrapped in a ElasticSearch::Result object
    # which basically is a Hashie::Mash. Check out the Hashie docs for further
    # details.
    #
    # @example
    #   CommentIndex.search("hello world").results
    #   # => [#<ElasticSearch::Result ...>, ...]
    #
    # @return [Array] An array of results

    def results
      @results ||= hits["hits"].map { |hit| Result.new hit["_source"].merge(hit["highlight"] ? { highlight: hit["highlight"] } : {}) }
    end

    # Returns the named sugggetion, if a name is specified or alle suggestions.
    #
    # @example
    #   query = CommentIndex.suggest(:suggestion, text: "helo", term: { field: "message" })
    #   query.suggestions # => {"suggestion"=>[{"text"=>...}, ...]}
    #
    # @example Named suggestions
    #   query = CommentIndex.suggest(:suggestion, text: "helo", term: { field: "message" })
    #   query.suggestions(:sugestion).first["text"] # => "hello"
    #
    # @return [Hash, Array] The named suggestion or all suggestions

    def suggestions(name = nil)
      if name
        response["suggest"][name.to_s].first["options"]
      else
        response["suggest"]
      end
    end

    # Returns the hits returned by ElasticSearch.
    #
    # @example
    #   CommentIndex.search("hello world").hits
    #   # => {"total"=>3, "max_score"=>2.34, "hits"=>[{...}, ...]}
    #
    # @return [Hash] The hits returned by ElasticSearch

    def hits
      response["hits"]
    end

    # Returns the scroll id returned by ElasticSearch, that can be used in the
    # following request to fetch the next batch of records.
    #
    # @example
    #   CommentIndex.scroll(timeout: "1m").scroll_id #=> "cXVlcnlUaGVuRmV0Y2..."
    #
    # @return [String] The scroll id returned by ElasticSearch

    def scroll_id
      response["_scroll_id"]
    end

    # Returns the database records, usually ActiveRecord objects, depending on
    # the ORM you're using. The records are sorted using the order returned by
    # ElasticSearch.
    #
    # @example
    #   CommentIndex.search("hello world").records # => [#<Comment ...>, ...]
    #
    # @return [Array] An array of database records

    def records(options = {})
      @records ||= begin
        sort_map = ids.each_with_index.each_with_object({}) { |(id, index), hash| hash[id.to_s] = index }

        scope.to_a.sort_by { |record| sort_map[relation.target.record_id(record).to_s] }
      end
    end

    # Builds and returns a scope for the array of ids in the current result set
    # returned by ElasticSearch, including the eager load, preload and includes
    # associations, if specified. A scope is eg an ActiveRecord::Relation,
    # depending on the ORM you're using.
    #
    # @example
    #   CommentIndex.preload(:user).scope # => #<Comment::ActiveRecord_Relation:0x0...>
    #
    # @return The scope for the array of ids in the current result set

    def scope
      res = relation.target.fetch_records(ids)

      res = res.includes(*relation.includes_values) if relation.includes_values
      res = res.eager_load(*relation.eager_load_values) if relation.eager_load_values
      res = res.preload(*relation.preload_values) if relation.preload_values

      res
    end

    # Returns the array of ids returned by ElasticSearch for the current result
    # set, ie the ids listed in the hits section of the response.
    #
    # @example
    #   CommentIndex.match_all.ids # => [20341, 12942, ...]
    #
    # @return The array of ids in the current result set

    def ids
      @ids ||= hits["hits"].map { |hit| hit["_id"] }
    end

    delegate :size, :count, :length, :to => :ids

    # Returns the response time in milliseconds of ElasticSearch specified in
    # the took info of the response.
    #
    # @example
    #   CommentIndex.match_all.took # => 6
    #
    # @return [Fixnum] The ElasticSearch response time in milliseconds

    def took
      response["took"]
    end

    # Returns a single or all aggregations returned by ElasticSearch, depending
    # on whether or not a name is specified. If no name is specified, the raw
    # aggregation hash is simply returned. Contrary, if a name is specified,
    # only this aggregation is returned. Moreover, if a name is specified and
    # the aggregation includes a buckets section, a post-processed aggregation
    # hash is returned.
    #
    # @example All aggregations
    #   CommentIndex.aggregate(:user_id).aggregations
    #   # => {"user_id"=>{..., "buckets"=>[{"key"=>4922, "doc_count"=>1129}, ...]}
    #
    # @example Specific and post-processed aggregations
    #   CommentIndex.aggregate(:user_id).aggregations(:user_id)
    #   # => {4922=>1129, ...}
    #
    # @return [Hash] Specific or all aggregations returned by ElasticSearch

    def aggregations(name = nil)
      return response["aggregations"] || {} unless name

      @aggregations ||= {}

      key = name.to_s

      return @aggregations[key] if @aggregations.key?(key)

      @aggregations[key] =
        if response["aggregations"].blank? || response["aggregations"][key].blank?
          Result.new
        elsif response["aggregations"][key]["buckets"].is_a?(Array)
          response["aggregations"][key]["buckets"].each_with_object({}) { |bucket, hash| hash[bucket["key"]] = Result.new(bucket) }
        elsif response["aggregations"][key]["buckets"].is_a?(Hash)
          Result.new response["aggregations"][key]["buckets"]
        else
          Result.new response["aggregations"][key]
        end
    end
  end
end

