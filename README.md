# TickSeries

TickSeries is a Ruby module including the classes
* Tick
* Series

It's purpose is to build a robust layer to working with single-valued timeseries.

## Description

Description pending (as are tests).

## Basic usage

    > series = Series.load(file: "ticks-2019-04-01", symbol: "Voltage")
    > series.select {|x| x.p > 5.1 }.each {|x| p x} 



