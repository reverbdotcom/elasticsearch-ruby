require 'test_helper'

class Elasticsearch2::Transport::ClientIntegrationTest < Elasticsearch2::Test::IntegrationTestCase
  startup do
    Elasticsearch2::Extensions::Test::Cluster.start(nodes: 2) if ENV['SERVER'] and not Elasticsearch2::Extensions::Test::Cluster.running?
  end

  shutdown do
    Elasticsearch2::Extensions::Test::Cluster.stop if ENV['SERVER'] and Elasticsearch2::Extensions::Test::Cluster.running?
  end

  context "Transport" do
    setup do
      @port = (ENV['TEST_CLUSTER_PORT'] || 9250).to_i
      begin; Object.send(:remove_const, :Patron);   rescue NameError; end
    end

    should "allow to customize the Faraday adapter" do
      require 'typhoeus'
      require 'typhoeus/adapters/faraday'

      transport = Elasticsearch2::Transport::Transport::HTTP::Faraday.new \
        :hosts => [ { :host => 'localhost', :port => @port } ] do |f|
          f.response :logger
          f.adapter  :typhoeus
        end

      client = Elasticsearch2::Transport::Client.new transport: transport
      client.perform_request 'GET', ''
    end

    should "allow to define connection parameters and pass them" do
      transport = Elasticsearch2::Transport::Transport::HTTP::Faraday.new \
                    :hosts => [ { :host => 'localhost', :port => @port } ],
                    :options => { :transport_options => {
                                    :params => { :format => 'yaml' }
                                  }
                                }

      client = Elasticsearch2::Transport::Client.new transport: transport
      response = client.perform_request 'GET', ''

      assert response.body.start_with?("---\n"), "Response body should be YAML: #{response.body.inspect}"
    end

    should "use the Curb client" do
      require 'curb'
      require 'elasticsearch2/transport/transport/http/curb'

      transport = Elasticsearch2::Transport::Transport::HTTP::Curb.new \
        :hosts => [ { :host => 'localhost', :port => @port } ] do |curl|
          curl.verbose = true
        end

      client = Elasticsearch2::Transport::Client.new transport: transport
      client.perform_request 'GET', ''
    end unless JRUBY

    should "deserialize JSON responses in the Curb client" do
      require 'curb'
      require 'elasticsearch2/transport/transport/http/curb'

      transport = Elasticsearch2::Transport::Transport::HTTP::Curb.new \
        :hosts => [ { :host => 'localhost', :port => @port } ] do |curl|
          curl.verbose = true
        end

      client = Elasticsearch2::Transport::Client.new transport: transport
      response = client.perform_request 'GET', ''

      assert_respond_to(response.body, :to_hash)
      assert_not_nil response.body['name']
      assert_equal 'application/json', response.headers['content-type']
    end unless JRUBY
  end

end
