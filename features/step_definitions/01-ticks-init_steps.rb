require './lib/tickseries.rb'
include TickSeries

When "creating a tick without parameters it should raise ArgumentError" do 
  expect { Tick.new }.to raise_error(ArgumentError)
end

When /^creating a tick with '([^']*)' it should result in (\S*) and (\S*)$/ do |params, timestamp, measurement| 
  eval "@tick = Tick.new(#{params})"
  expect(@tick.t).to eq(Integer(timestamp))
  expect(@tick.m).to eq(BigDecimal(measurement,8))
end
