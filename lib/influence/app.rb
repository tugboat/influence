#!/usr/bin/env ruby
require 'gli'
require 'json'
require 'rest_client'
require 'terminal-table'
require 'pp'

include GLI::App

program_desc "Command Line app for accessing the pro publica free the files project"

desc "Swing State Markets"
command :markets do |c|

  c.desc "Get details for a market by slug"
  c.action do |global_options,options,args|
    rows = []
    market = JSON.parse(RestClient.get("https://projects.propublica.org/free-the-files/markets/#{args.first}.json"))
    market["market"]["stations"].each do |station|
      filings_string = ""
      station["freed_files"].each do |file|
        filings_string.concat("#{file["filing"]["committee"]["name"]} (#{currencify(file["filing"]["gross_amount"])})\n")
      end
      rows << [station["callsign"], filings_string]
    end
    output_table = Terminal::Table.new :title => "#{market["market"]["name"]} Filings", :headings => ["callsign","filing Totals"], :rows => rows
    puts output_table
  end

  c.desc "List all swing markets"
  c.command :all do |all|
    all.action do |global_options,options,args|
      markets = JSON.parse(RestClient.get("https://projects.propublica.org/free-the-files/markets.json"))
      markets.each do |m|
        if m["market"]["freed_ct"] > 0
          percent_freed = m["market"]["filings_ct"] / m["market"]["freed_ct"]
        else
          percent_freed = 0
        end

        puts "#{m["market"]["titleized_name"]} (#{percent_freed}%)"
      end
    end
  end

  
end

# takes a number and options hash and outputs a string in any currency format
def currencify(number, options={})
  # :currency_before => false puts the currency symbol after the number
  # default format: $12,345,678.90
  options = {:currency_symbol => "$", :delimiter => ",", :decimal_symbol => ".", :currency_before => true}.merge(options)

  # split integer and fractional parts 
  int, frac = ("%.2f" % number).split('.')
  # insert the delimiters
  int.gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{options[:delimiter]}")

  if options[:currency_before]
    options[:currency_symbol] + int + options[:decimal_symbol] + frac
  else
    int + options[:decimal_symbol] + frac + options[:currency_symbol]
  end
end
