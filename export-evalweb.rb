#!/usr/bin/ruby
# encoding: UTF-8
# Ubuntu: sudo apt-get install rubygem libxslt1-dev && sudo gem install mechanize
require 'rubygems'
require 'mechanize'

columns = []

columns[14] = {label: 'adresse', type: :string}
columns[26] = {label: 'utilisation', type: :string}
columns[39] = {label: 'proprietaire', type: :string}
columns[145] = {label: 'valeur_anterieur', type: :integer}
columns[154] = {label: 'valeur', type: :integer}

cached = Dir.glob 'cache/address/*'

File.open("evaluations.tsv", 'w:UTF-8') do |csv|
  csv.write((['evalweb_id'] + columns.compact.map{|c| c[:label]}).join("\t"))
  csv.write("\n")
  cached.each do |filename|
    address_id = filename.split("/").last
    page_content = File.read(filename)
    puts "Working on address with ID #{address_id}"

    page_content.force_encoding('utf-8')
    page = Nokogiri::HTML::Document.parse(page_content, encoding='UTF-8')
    data = page.css("//td").map {|td| td.content.gsub(/\s+/, " ").strip}
    data = data.each_with_index.map { |cell,index|
      if columns[index]
        puts "  (#{columns[index][:label]} #{cell})"
        type = columns[index][:type]
        type == :string ? cell : cell.gsub(',','')
      else
        nil
      end
    }.compact
    data.unshift(address_id)
    csv.write(data.join("\t"))
    csv.write("\n")
  end
end
