
require File.expand_path("../test_helper", __FILE__)

class ElasticSearchTest < ElasticSearch::TestCase
  def test_msearch
    ProductIndex.import create(:product)
    CommentIndex.import create(:comment)

    responses = ElasticSearch.msearch([ProductIndex.match_all, CommentIndex.match_all])

    assert_equal 2, responses.size
    assert_equal 1, responses[0].total_entries
    assert_equal 1, responses[1].total_entries
  end

  def test_post
    assert ElasticSearch.aliases(actions: [
      add: { index: "products", alias: "alias1" }
    ])

    assert ElasticSearch.aliases(actions: [
      remove: { index: "products", alias: "alias1" }
    ])
  end
end

