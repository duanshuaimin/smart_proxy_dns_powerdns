require 'test_helper'

require 'ipaddr'
require 'net/http'

class DnsPowerdnsIntegrationTest < Test::Unit::TestCase

  def test_forward_dns
    data = {'fqdn' => fqdn, 'value' => ip, 'type' => 'A'}
    type = Resolv::DNS::Resource::IN::A
    expected = type.new(Resolv::IPv4.create(data['value']))

    test_scenario(data, data['fqdn'], type, expected)
  end

  def test_reverse_dns
    data = {'fqdn' => fqdn, 'value' => IPAddr.new(ip).reverse, 'type' => 'PTR'}
    type = Resolv::DNS::Resource::IN::PTR
    expected = type.new(Resolv::DNS::Name.create(data['fqdn'] + '.'))

    test_scenario(data, data['value'], type, expected)
  end

  private

  def test_scenario(data, name, type, expected)
    uri = URI(smart_proxy_url)

    Net::HTTP.start(uri.host, uri.port) do |http|
      request = Net::HTTP::Post.new(smart_proxy_url + 'dns/')
      request.form_data = data
      response = http.request request
      assert_equal(200, response.code.to_i)

      assert_equal([expected], resolver.getresources(name, type))

      request = Net::HTTP::Delete.new(smart_proxy_url + 'dns/' + name)
      response = http.request request
      assert_equal(200, response.code.to_i)

      assert(purge_cache name)

      assert_equal([], resolver.getresources(name, type))
    end
  end

  def resolver
    Resolv::DNS.new(:nameserver_port => [['127.0.0.1', 5300]])
  end

  def smart_proxy_url
    'http://localhost:8000/'
  end

  def fqdn
    set = ('a' .. 'z').to_a + ('0' .. '9').to_a
    10.times.collect {|i| set[rand(set.size)] }.join + '.example.com'
  end

  def ip
    IPAddr.new(rand(2 ** 32), Socket::AF_INET).to_s
  end

  def purge_cache name
    %x{#{ENV['PDNS_CONTROL'] || "pdns_control"} purge "#{name}"}
    $? == 0
  end
end
