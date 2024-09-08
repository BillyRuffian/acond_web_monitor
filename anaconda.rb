require 'bundler/setup'
Bundler.require(:default)

require 'digest'
require 'logger'

class Anaconda
  HOST = ENV.fetch('ACOND_HOST').freeze
  USER = ENV.fetch('ACOND_USER').freeze
  PASS = ENV.fetch('ACOND_PASS').freeze

  ATTRIBUTES = {
    average_temperature: '__TDE3BFC02_REAL_.1f',
    outside_temperature: '__T033A2538_REAL_.1f',
    flow_temperature: '__T9E13248E_REAL_.1f',
    return_temperature: '__T50A32455_REAL_.1f',
    water_temperature: '__T881A25AA_REAL_.1f',
    room_temperature: '__T46AA2571_REAL_.1f',

    circulation_pump: '__T6F64FA70_BOOL_i',
    compressor: '__T61E4AC91_BOOL_i',
    fan: '__TF4B3F468_BOOL_i',
    primary_pump: '__T2BA2EA36_BOOL_i',
    defrost: '__T880DC46F_BOOL_i',
    bivalent: '__TD3998BF7_BOOL_i',
    water_heating: '__T80F610D7_BOOL_i'
  }.freeze

  KELVIN = 273.15
  CARNOT_EFFICIENCY = 0.5

  attr_reader :agent

  ATTRIBUTES.keys.each do |attribute|
    define_method(attribute) do
      value_for(attribute)
    end
  end

  def initialize
    @agent = Mechanize.new
    @agent.log = Logger.new('mechanize.log')
  end

  def login
    agent.post('LOGIN.XML', {'USER' => USER, 'PASS' => password})
  end

  def reload
    agent.get(HOST) unless agent.page
    login unless agent.page.uri.path == '/PAGE115.XML'

    agent.get(agent.page.uri)
  end

  def password
    Digest::SHA1.hexdigest("#{cookie.value}#{PASS}")
  end

  def cookie
    agent.cookies.find { |c| c.name == 'SoftPLC' }
  end

  def value_for(attribute)
    node = agent.page.at("//INPUT[@NAME=\"#{ATTRIBUTES[attribute]}\"]")
    return 0 unless node

    case node['NAME']
    when /_REAL_/
      node['VALUE'].to_f
    when /_BOOL_/
      node['VALUE'].to_i == 1
    else
      raise "Unknown attribute type: #{node['NAME']}"
    end
  end

  def cop
    return nil unless compressor

    ((flow_temperature + KELVIN) / (flow_temperature - outside_temperature)) * CARNOT_EFFICIENCY
  end
end

anaconda = Anaconda.new

loop do
  anaconda.reload
  puts "#{anaconda.room_temperature} #{anaconda.outside_temperature} #{anaconda.compressor ? '*' : '.' } #{anaconda.cop}"
  sleep 10
end
