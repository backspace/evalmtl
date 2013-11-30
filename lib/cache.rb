require 'dbm'

class ScrapeCache
  def initialize
    @databases = Hash.new do |dbs, namespace|
      if namespace == "address"
        FileCache.new(namespace)
      elsif namespace == "street"
        SlashConvertingFileCache.new(namespace)
      else
        DBM.open(namespace)
      end
    end
  end
  def put(namespace, key, value)
    if value.nil?
      puts "NULL PUT: #{key}"
    elsif (value.include?("Votre session n'est pas valide"))
      puts "INVALID PUT: #{key}"
    else
      @databases[namespace][key] = value.encode('utf-8')
    end
  end
  def get(namespace, key)
    value = validate @databases[namespace][key.to_s]
  end
  def validate(value)
    if (!value.nil? && value.include?("Votre session n'est pas valide"))
      puts "INVALID CACHE: #{key}"
      nil
    elsif value.nil?
      nil
    else
      value.force_encoding('utf-8')
    end
  end
  def include?(namespace, key)
    @databases[namespace].has_key?(key)
  end
end

class FileCache
  def initialize(namespace)
    @namespace = namespace
    FileUtils.mkdir_p(@namespace) unless File.directory?(@namespace)
  end

  def [](key)
    if include?(key)
      File.read(path(key))
    else
      nil
    end
  end

  def []=(key, value)
    File.open(path(key), 'w') {|f| f.write(value) }
  end

  def include?(key)
    File.exists?(path(key))
  end

  def has_key?(key)
    include?(key)
  end

  protected
  def filename(key)
    key
  end

  def path(key)
    "cache/#{@namespace}/#{filename(key)}"
  end
end

class SlashConvertingFileCache < FileCache
  protected
  def filename(key)
    key.gsub("/", "_")
  end
end
