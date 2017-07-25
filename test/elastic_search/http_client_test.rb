
require File.expand_path("../../test_helper", __FILE__)

class ElasticSearch::HTTPClientTest < ElasticSearch::TestCase
  [:get, :put, :delete, :post].each do |method|
    define_method :"test_#{method}" do
      stub_request(method, "http://localhost/path").with(body: "body", query: { key: "value" }).to_return(body: "success")

      assert_equal "success", ElasticSearch::HTTPClient.send(method, "http://localhost/path", body: "body", params: { key: "value" }).body.to_s
    end
  end

  def test_headers
    stub_request(:get, "http://localhost/path").with(headers: { "X-Key" => "Value" }).to_return(body: "success")

    assert_equal "success", ElasticSearch::HTTPClient.headers("X-Key" => "Value").get("http://localhost/path").body.to_s
  end

  def test_connection_error
    stub_request(:get, "http://localhost/path").to_raise(HTTP::ConnectionError)

    assert_raises ElasticSearch::ConnectionError do
      ElasticSearch::HTTPClient.get("http://localhost/path")
    end
  end

  def test_response_error
    stub_request(:get, "http://localhost/path").to_return(status: 500)

    assert_raises ElasticSearch::ResponseError do
      ElasticSearch::HTTPClient.get("http://localhost/path")
    end
  end
end

