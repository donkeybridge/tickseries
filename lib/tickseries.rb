require 'yaml'
require 'date'
require 'csv'
require 'bigdecimal'

module TickSeries

  class Series

    attr_reader :date, :ticks

    CONFIGFILEPATH = "~/.config/ez"
    `mkdir -p #{CONFIGFILEPATH}` 
    CONFIGFILE = "#{CONFIGFILEPATH}/tickseries.conf"

    def self.get_config
      YAML.load(File.read("#{`echo $HOME`.chomp}/.config/ez/tickseries.yml"))
    end

    def initialize(opts = {})
      begin
        puts "#{`echo $HOME`.chomp}/.config/ez/tickseries.yml"
        @config = Series.get_config
      rescue Errno::ENOENT
        @config = {}
      end
      [:tickfilepath, :contract].each do |param| 
        from_conf = @config[param.to_s] || @config[param]
        from_opts = opts[param]
        instance_variable_set("@#{param.to_s}", from_opts || from_conf)
      end
      @date ||= Date.today
      @ticks  = [] 
    end

    def self.load(opts = {})
      begin
        config = Series.get_config
      rescue Errno::ENOENT
        config = {}
      end
      contract = opts[:contract]
      file   = opts[:file] 
      puts config
      unless file.nil?
        *path, filename = file.split('/') 
        p path
        if path.empty?
          path = config[:tickfilepath] || config["tickfilepath"]
          puts "from cofnig #{path}"
        else 
          path  = File.absolute_path(path.join('/'))
          puts "from abs #{path}"
        end
        raise "Cannot guess tickfilepath from #{file}, please provide in #{CONFIGFILE}" if path.nil?

        filetype = opts[:filetype] || filename.split('.').last
      end
      raise ArgumentError, "Cannot guess filetype for loading Timeseries from file #{path}/#{filename}" if filetype.nil? 
      raise ArgumentError, "Seems provided file for loading timeseries does not exist #{path}/#{filename}" unless File.file?("#{path}/#{filename}")

      series = Series.new( contract: opts[:contract]) 

      case filetype.downcase
      when 'csv'
        CSV.parse(`cat #{path}/#{filename} #{contract.nil? ? "" : "| grep -i #{contract}"}`).sort_by{|x| x[1] }.each{|x| series.add x}
      else
        raise(ArgumentError, "Unsupported filetype '.#{filetype}'")
      end
      series
    end

    def add(arg)
      @ticks << ((arg.is_a? Tick) ? arg : Tick.new(arg))
    end

    def map(&block);              @ticks.map             {|x|   block.call(x)}                       ;end
    def each(&block);             @ticks.each            {|x|   block.call(x)}                       ;end
    def each_with_index(&block);  @ticks.each_with_index {|x,i| block.call(x,i)}                     ;end
    def select(&block);           @ticks.select          {|x|   block.call(x)}                       ;end
    def reduce(c = 0, &block);    @ticks.reduce(c)       {|x,i| block.call(x,i)}                     ;end

  end

  class Tick

      attr_reader :t, :p, :v, :k
      def initialize(*args, &block)
        raise ArgumentError, "Creating ticks without arguments is not supported" if args.empty?
        opts = args[0] if args[0].is_a? Hash
        args = args[0] if args[0].is_a? Array
        if opts.nil?
          prefix = 0 
          begin # if contract is given on args[0], the Integer() will raise
            timestamp = Integer(args[0]) 
          rescue
            prefix = 1
            timestamp = Integer(args[1])
          end
          opts = {t: timestamp, 
                  p: args[prefix + 1], 
                  v: args[prefix + 2], 
                  k: args[prefix + 3]}
        end
        @v  =  opts[:v] || opts[:vol]
        @v  =  @v.to_i unless @v.nil?
        @p  =  opts[:p] || opts[:price] 
        @p  =  BigDecimal(@p,8) unless @p.nil?
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
          raise ArgumentError, "Tick.new cannot continue without timestamp given as t:, time: or timestamp:."
        end
        if @t < 500000000000 # Tue, 05 Nov 1985 00:53:20 GMT in ms
          # assume it was provided as second_base timestamp
          @t *= 1000
        end
        raise ArgumentError, "Invalid timestamp, too small: #{@t} < 500000000000" if @t < 500000000000
        @k  =  opts[:k] || opts[:peak] 
        @k  =  @k.to_i unless @k.nil?
      end

      def to_s
        "#{@t},#{@p.to_f},#{@v},#{@k}"
      end

      def human_time(with_date = false)
        t = Time.at(@t / 1000)
        t.strftime("#{ "%Y-%m-%d " if with_date }%H:%M:%S")
      end
  end
end
