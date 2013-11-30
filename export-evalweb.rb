#!/usr/bin/ruby
# encoding: UTF-8
# Ubuntu: sudo apt-get install rubygem libxslt1-dev && sudo gem install mechanize
require 'rubygems'
require 'mechanize'

cached = Dir.glob 'cache/address/*'
columns = ['address_id', 'address', 'usage', 'owners', 'value', 'previous_value']

File.open("evaluations.tsv", 'w:UTF-8') do |csv|
  csv.write(columns.join("\t"))
  csv.write("\n")
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

    owners = page.search("//tr[td/font[contains(., 'Nom :')]]/td[2]//font").map(&:text).join(" | ")

    data = [address_id, address, usage, owners, value, previous_value]

    csv.write(data.join("\t"))
    csv.write("\n")
  end
end
