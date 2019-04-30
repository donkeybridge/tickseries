require 'yaml'
require 'date'
require 'csv'
require 'bigdecimal'

# The module proveds TickSeries::Tick and TickSeries::Series
module TickSeries

  # TickSeries::Series provides a TimeSeries (aka TickSeries) based on single Ticks (aka Measurements)
  # 
  class Series

    attr_reader :date, :ticks

    # TickSeries::CONFIGFILEPATH 
    CONFIGFILEPATH = "~/.config/ez"
    # TickSeries::CONFIGFILE basically contains the location of tickfiles as well as the location of symbol / contract information
    #
    CONFIGFILE = "#{CONFIGFILEPATH}/tickseries.conf"

    # Helper method the read the config file
    def self.get_config
      begin 
        return YAML.load(File.read("#{`echo $HOME`.chomp}/.config/ez/tickseries.yml"))
      rescue Errno::ENOENT
        return {}
      end
    end

    # Helper method the read the symbol config
    def get_symbol_config
      begin 
        return YAML.load(File.read("#{@symbolspath}/#{@symbol}.yml"))
      #rescue Errno::ENOENT
      #  return {}
      end
    end

    # Creates a new instance of TickSeries::Series. Accepts optionshash.
    #
    # @param opts [Hash]
    def initialize(opts = {})

      # Reading configfile and setting provided instance variables
      `mkdir -p #{CONFIGFILEPATH} > /dev/null`
      @config = Series.get_config
      [:tickfilepath, :symbolspath].each do |param| 
        from_conf = @config[param.to_s] || @config[param]
        from_opts = opts[param]
        instance_variable_set("@#{param.to_s}", from_opts || from_conf)
      end
      p self.instance_variables

      # Reading symbolconfig and providing instance variables
      @symbol = opts[:symbol] 
      unless @symbol.nil? 
        @symbol = @symbol.upcase
        @symbolconfig = self.get_symbol_config
        p @symbolconfig
        [:symbol, :ticksize].each do |param|
          from_conf = @config[param.to_s] || @config[param]
          from_opts = opts[param]
          instance_variable_set("@#{param.to_s}", from_opts || from_conf)
        end
      end
      @date ||= Date.today
      @ticks  = [] 
    end

    # Receptor from Enumerable#to_series
    def self.from_enumerable(arr)
      t = Series.new
      arr.each{|x| t.add(x)}
      t
    end

    # TickSeries::Series.load opens a 'tickfile' containing data saved as CSV. 
    def self.load(opts = {})
      begin
        config = Series.get_config
      rescue Errno::ENOENT
        config = {}
      end
      symbol = opts[:symbol]
      file   = opts[:file] 
      unless file.nil?
        *path, filename = file.split('/') 
        if path.empty?
          path = config[:tickfilepath] || config["tickfilepath"]
        else 
          path  = File.absolute_path(path.join('/'))
        end
        raise "Cannot guess tickfilepath from #{file}, please provide in #{CONFIGFILE}" if path.nil?

        filetype = opts[:filetype] || filename.split('.').last
      end
      raise ArgumentError, "Cannot guess filetype for loading Timeseries from file #{path}/#{filename}" if filetype.nil? 
      raise ArgumentError, "Seems provided file for loading timeseries does not exist #{path}/#{filename}" unless File.file?("#{path}/#{filename}")

      series = Series.new( symbol: opts[:symbol]) 

      case filetype.downcase
      when 'csv'
        CSV.parse(`cat #{path}/#{filename} #{symbol.nil? ? "" : "| grep -i #{symbol}"}`).sort_by{|x| x[1] }.each{|x| series.add x}
      else
        raise(ArgumentError, "Unsupported filetype '.#{filetype}'")
      end
      series
    end
    
    # TickSeries::Series#add adds an element to series. 
    #
    # element can be provided as TimeSeries::Tick, or as Hash or Array, that sufficises format requirements.
    def add(element)
      @ticks << ((element.is_a? Tick) ? element : Tick.new(element))
    end

    # @!visibility private
    def map(&block);              @ticks.map             {|x|   block.call(x)}                       ;end
    # @!visibility private
    def each(&block);             @ticks.each            {|x|   block.call(x)}                       ;end
    # @!visibility private
    def each_with_index(&block);  @ticks.each_with_index {|x,i| block.call(x,i)}                     ;end
    # @!visibility private
    def select(&block);           @ticks.select          {|x|   block.call(x)}                       ;end
    # @!visibility private
    def reduce(c = 0, &block);    @ticks.reduce(c)       {|x,i| block.call(x,i)}                     ;end

    # @!visibility private
    def inspect
      "<#TimeSeries::Series:0x#{self.object_id.to_s(16)} ticks: #{@ticks.size}, #{"symbol: #{@symbol}, " if @symbol}ticksize: #{@ticksize}, date: #{@date}>"
    end
  end

  # TimeSeries::Series is the second part of the module. It contains a single measurement ("Messpunkt") of the series. 
  class Tick
    attr_reader :t, :m0, :m1, :m2, m:3

    # The constructor is build as flexible as I was able to. It accepts 
    # * a Hash containing < :t | :time | :timestamp > with an integer or string value required in seconds or milliseconds
    #          containing < :m | :measurement | :price > with a Numeric value (can also be given as string)
    #          arbitrary information like or symbol, volume or peak information.
    # * an Array that sufficises the expected order: < [ symbol,] timestamp, measure, frequency / volume, peak information >
    def initialize(*args, &block)
      raise ArgumentError, "Creating ticks without arguments is not supported" if args.empty?
      opts = args[0] if args[0].is_a? Hash
      args = args[0] if args[0].is_a? Array
      if opts.nil?
        prefix = 0 
        begin # if symbol is given on args[0], the Integer() will raise
          timestamp = Integer(args[0]) 
        rescue
          prefix = 1
          timestamp = Integer(args[1])
        end
        opts = {t: timestamp, 
                m0: args[prefix + 1], 
                m1: args[prefix + 2], 
                m2: args[prefix + 3],
                m3: args[prefix + 4]}
      end
      @t  =  opts[:t] || opts[:time] || opts[:timestamp]
      case @t
      when *[Date, DateTime, Time]
        @t = @t.to_time.to_i
      when *[Integer, Float, BigDecimal]
        @t = Integer(@t)
      when String
        failed = false
        begin;            @t = DateTime.parse(@t).to_time.to_i * 1000; rescue; failed = true; end
        if failed; begin; @t = Integer(@t); failed = false;            rescue; failed = true; end; end
        raise ArgumentError, "Could not get Timestamp from given String #{@t}" if failed
      else
        raise ArgumentError, "Tick.new cannot continue without timestamp given as t:, time: timestamp: or within array."
      end
      if @t < 500000000000 # Tue, 05 Nov 1985 00:53:20 GMT in ms
        # assume it was provided as second_based timestamp
        @t *= 1000
      end
      raise ArgumentError, "Invalid timestamp, too small: #{@t} < 500000000000" if @t < 500000000000
      @m  =  opts[:m] || opts[:measurement]
      @m  =  BigDecimal(@m,8) unless @m.nil?
      @v  =  opts[:v] || opts[:vol]
      @v  =  @v.to_i unless @v.nil?
      # :peak should only be set for peaks pointing out a deviation > 5 * @ticksize
      @p  =  opts[:p] || opts[:peak] 
      @p  =  @p.to_i unless @p.nil?
    end
 

    # Convenient way to create a string representation of tick.
    def to_s
      "#{@t},#{@m.to_f},#{@v},#{@p}"
    end

    # TickSeries::Tick#human_time returns the time converted to a human readable format
    #
    # @param with_date [Boolean] whether or not to include Date information (default: false)
    def human_time(with_date = false)
      t = Time.at(@t / 1000)
      t.strftime("#{ "%Y-%m-%d " if with_date }%H:%M:%S")
    end
  end
end

# Reopens enumerable to allow retransport into Series
# @!visibility private
module Enumerable
  # @!visibility private 
  def to_series
    TickSeries::Series.from_enumerable(self)
  end
end
