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
  c.switch [:s, :sum]

  c.desc "List all swing markets"
  c.command :all do |all|
    all.action do |global_options,options,args|
      markets = JSON.parse(RestClient.get("https://projects.propublica.org/free-the-files/markets.json"))
      rows = []
      markets.each do |m|
        if m["market"]["freed_ct"] > 0
          percent_freed = m["market"]["filings_ct"] / m["market"]["freed_ct"]
        else
          percent_freed = 0
        end
        rows.push([m["market"]["slug"], m["market"]["titleized_name"], percent_freed])
      end

      puts Terminal::Table.new :headings => ["slug", "market", "percent freed"], :rows => rows
    end
  end

  c.desc "Get details for a market by slug"
  c.action do |global_options,options,args|
    help_now!('A slug is required to get market info.  Try running "influence markets all" for a list of markets') if args.empty?

    rows = []
    market = JSON.parse(RestClient.get("https://projects.propublica.org/free-the-files/markets/#{args.first}.json"))
    market["market"]["stations"].each do |station|
      filings_string = ""

      if options[:sum]
        pacs = station["freed_files"].map { |p| p["filing"]["committee"]["name"] }.uniq
        pac_totals = []
        pacs.each do |pac|
          pac_total = 0
          station["freed_files"].each do |file|
            pac_total += file["filing"]["gross_amount"] if pac == file["filing"]["committee"]["name"]
          end
          pac_totals.push(pac_total)
        end

        pacs.each_with_index do |pac, index|
          filings_string.concat("#{pac} (#{currencify(pac_totals[index])})\n")
        end
      else
        station["freed_files"].each do |file|
          filings_string.concat("#{file["filing"]["committee"]["name"]} (#{currencify(file["filing"]["gross_amount"])})\n")
        end
      end

      rows << [station["callsign"], filings_string]
    end
    puts Terminal::Table.new :title => "#{market["market"]["name"]} Filings", :headings => ["callsign","filing Totals"], :rows => rows
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
