module Bench::Commands
  alias Command = DynamicCommand | StaticCommand
  alias Mapping = Hash(String, String)

  class Context
    RAND_INT = "__rand_int__"
    EPOCH    = "__epoch__"
    RESULT   = "__result__"

    delegate keys, to: @map
    
    def initialize(@map : Mapping = Mapping.new, keyspace : Int32? = nil)
      @map[RAND_INT] = keyspace.to_s if keyspace
    end

    def copy(map : Mapping)
      self.class.new(@map.merge(map))
    end

    def apply(s : String)
      @map.each do |(key, val)|
        case key
        when RAND_INT
          s = s.gsub(RAND_INT) { rand_int(val.to_i) }
        when EPOCH
          s = s.gsub(EPOCH) { Time.now.epoch.to_s }
        else
          s = s.gsub(key, val.to_s)
        end
      end
      return s
    end

    # calculate random number less than num with zero padding
    private def rand_int(num)
      # num : 1_000_000
      # min : 0000000
      # max : 9999999
      size = (num - 1).to_s.size
      "%0#{size}d" % rand(num)
    end
  end
  
  module Core
    protected abstract def raws : Array(String)
    protected abstract def feed : Array(String)

    def name
      raws.first
    end

    def to_s(io : IO)
      io << ([name.upcase] + raws[1..-1]).join(" ")
    end
  end
    
  record StaticCommand, raws : Array(String) do
    include Core

    def feed : Array(String)
      raws
    end
  end

  record DynamicCommand, raws : Array(String), ctx : Context do
    include Core

    def feed : Array(String)
      [name] + raws[1..-1].map{|s| ctx.apply(s)}
    end
  end

  def self.parse(str, ctx : Context)
    str.split(",").map{|s|
      args = s.strip.split(/\s+/)
      if str =~ /(#{ctx.keys.join("|")})/
        DynamicCommand.new(args, ctx)
      else
        StaticCommand.new(args)
      end
    }
  end
end
