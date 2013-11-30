#!/usr/bin/ruby
# Ubuntu: sudo apt-get install rubygem libxslt1-dev && sudo gem install mechanize
require 'rubygems'
require 'mechanize'
require './lib/cache.rb'

class EvalWebAgent
  def initialize
    @agent = Mechanize.new
    @agent.default_encoding = 'iso-8859-1'
    @agent.force_default_encoding = true
    weird_page = @agent.get('http://evalweb.ville.montreal.qc.ca/')
    @search_page = weird_page.meta_refresh[0].click
  end
  def perform_request
    tries = 0
    begin
      page = yield
      if (!page.nil? && page.body.include?("Votre session n'est pas valide"))
        puts "ERROR: Session expired!"
        # start new session and trigger a retry
        initialize
        raise "Session expired"
      end
      page
    rescue Exception => e
      tries += 1
      # Check for body of page from Net::HTTPInternalServerError
      if (e.page && e.page.body.include?("Requested operation requires a current record"))
        puts "Missing from remote database!"
      else
        puts "RETRY #{tries} " + e.to_s
        retry if tries <= 1
        puts "ERROR (tried #{tries})"
      end
      nil
    end
  end
  def search_street(search_term)
    perform_request do
      @search_page.forms.first['text1'] = search_term
      cookie = Mechanize::Cookie.new('nom_rue', search_term)
      cookie.domain = "evalweb.ville.montreal.qc.ca"
      cookie.path = "/"
      @agent.cookie_jar.add(@agent.history.last.uri, cookie)
      @search_page.forms.first.click_button
    end
  end
  def get_street(street_id)
    perform_request do
      @agent.get("RechAdresse.ASP?IdAdrr=" + street_id)
    end
  end
  def get_evaluation(id_uef)
    perform_request do
      @agent.get("CompteFoncier.ASP?id_uef=" + id_uef)
    end
  end
end

class EvalWebScraper
  def initialize
    @evalweb = EvalWebAgent.new
    @search_term = nil
    @cache = ScrapeCache.new
  end
  def search_street(term)
    # TODO callback for get/cache & parsing
    streets_body = @cache.get('street_search', term)
    if (streets_body.nil?)
      puts "[#{@search_term}] SEARCH streets: #{term}"
      page = @evalweb.search_street(term)
      @cache.put('street_search', term, page.parser.to_s)
      page.parser
    else
      Nokogiri::HTML::Document.parse(streets_body)
    end
  end
  def get_street_page(street_id, street_name)
    street_body = @cache.get('street', street_id)
    if (street_body.nil?)
      puts "[#{@search_term}] GET street: #{street_id} (#{street_name})"
      page = @evalweb.get_street(street_id)
      @cache.put('street', street_id, page.parser.to_s)
      page.parser
    else
      Nokogiri::HTML::Document.parse(street_body)
    end
  end
  def get_address_page(address_id, address_name)
    unless (@cache.include?('address', address_id))
      puts "[#{@search_term}] GET address: #{address_id} (#{address_name})"
      page = @evalweb.get_evaluation(address_id)
      unless (page.nil?)
        @cache.put('address', address_id, page.parser.to_s)
      end
    end
  end
  def state_file
    "state"
  end
  def read_state
    File.open(state_file, 'rb') { |f| f.read.split } if (File.exists?(state_file))
  end
  def write_state(term, street_id)
    File.open(state_file, 'w') do |f|
      f.write("#{term}\t#{street_id}")
    end
  end
  def scrape(start_term = nil, start_street_id = nil)
    (previous_term, previous_street_id) = read_state
    if ((start_term.nil? || start_street_id.nil?) and (!previous_term.nil? && !previous_street_id.nil?))
      puts "Resuming at [#{previous_term}: #{previous_street_id}]"
      start_term ||= previous_term
      start_street_id ||= previous_street_id
    end
    terms = [('aa'..'zz'),('0'..'9')].map{|r|r.map{|v|v}}.flatten
    terms = terms.slice(terms.index(start_term), terms.length) unless (start_term.nil? || terms.index(start_term).nil?)
    terms.each do |term|
      puts "Search term: #{term}"
      @search_term = term
      # The session can expire, so do not cache queries in hope of avoiding that.
      streets_body = @cache.get('street_search', term)
      search_results = search_street(term)
      search_results.css('/html/body/div/div/div/p[6]/select/option').each do |street_option|
        street_id = street_option.attribute('value').value
        # If we haven't reached start_street_id, skip.
        unless start_street_id.nil?
          start_street_id = nil if street_id == start_street_id
          next unless start_street_id.nil?
        end
        write_state(term, street_id)
        street_name = street_option.content.gsub(/\s+/, " ")
        street_page = get_street_page(street_id, street_name)
        street_page.css("option").each do |option|
          address_id = option.attribute('value').value
          address_name = option.content.strip
          begin
            get_address_page(address_id, address_name)
          rescue
            puts "[#{term}] ERROR address: #{address_id} (#{address_name}) " + $!.to_s
          end
        end
      end
    end
  end
end
