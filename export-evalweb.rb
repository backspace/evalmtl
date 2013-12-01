#!/usr/bin/ruby
# encoding: UTF-8

require 'rubygems'
require 'bundler/setup'

Bundler.require(:default)

require './lib/export'

DataMapper.auto_migrate!

cached = Dir.glob 'cache/address/*'
columns = ['address_id', 'address', 'usage', 'owners', 'value', 'previous_value']

cached.each_with_index do |filename, index|
  address_id = filename.split("/").last
  page_content = File.read(filename)
  puts "Working on address with ID #{address_id} #{index} of #{cached.length}"

  page_content.force_encoding('utf-8')
  page = Nokogiri::HTML::Document.parse(page_content, encoding='UTF-8')

  address = page.search("//tr[td/font[contains(., 'Adresse :')]]/td[2]//font").text.strip
  usage = page.search("//tr[td/font[contains(., 'Utilisation prédominante :')]]/td[2]//font").text.strip

  value = page.search("//tr[td/font[contains(., 'immeuble :')]]/td[2]//font").text.strip.gsub(" ", "").to_i
  previous_value = page.search("//tr[td/font[contains(., 'immeuble au')]]/td[2]//font").text.strip.gsub(" ", "").to_i

  owners = page.search("//tr[td/font[contains(., 'Nom :')]]/td[2]//font").map(&:text)

  unit = Unit.create(
    evalweb_id: address_id,
    address: address,
    usage: Usage.first_or_create(name: usage),
    owners: owners.map{|owner_string| Owner.first_or_create(name: owner_string)},
    value: value,
    previous_value: previous_value
  )
end
