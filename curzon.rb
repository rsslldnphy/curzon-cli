require 'httparty'

module Curzon

  class AuthToken
    def fetch!
      token
    end

    def token
      @token ||= page.lines.find {|line| line.match? /occInititialiseData/ }.gsub /^.*"authToken":"([^"]*)".*$/, '\1'
    end

    def page
      @page ||= HTTParty.get('https://www.curzon.com').body
    end
  end

  class Showtimes
    attr_reader :token, :cinemas, :date
    def initialize(token, cinemas, date = Time.now)
      @token = token
      @cinemas = cinemas
      @date = date
    end

    def fetch!
      showtimes.group_by { |showtime| showtime[:film]['id'] }.map do |(_, times)|
        film = times.first[:film]
        {
          film: film['title']['text'],
          url: "https://www.curzon.com/films/#{film['id']}",
          trailer: film['trailerUrl'],
          times: times
        }
      end
    end

    def showtimes
      @showtimes ||= data['showtimes'].reject {|showtime| showtime['isSoldOut']}.filter_map do |showtime|
        site = sites[showtime['siteId']]
        film = films[showtime['filmId']]
        {
          film: film,
          starts_at: showtime['schedule']['startsAt'],
          site: site,
        }
      end
    end

    def sites
      @sites ||= data['relatedData']['sites'].reduce({}) { |acc, site| acc[site['id']] = site['name']['text']; acc }
    end

    def films
      @films ||= data['relatedData']['films'].reduce({}) {|acc, film| acc[film['id']] = film; acc }
    end

    def data
      @data ||= HTTParty.get(
        "https://vwc.curzon.com/WSVistaWebClient/ocapi/v1/showtimes/by-business-date/#{date.strftime "%Y-%m-%d"}",
        format: :json,
        query: {
          'siteIds' => cinemas,
        },
        headers: { 'accept' => 'application/json', authorization: "Bearer #{token}"}
      )
    end
  end
end

cinemas = ['ALD1', 'SOH1', 'VIC1', 'MAY1', 'HOX1', 'CAM1', 'BLO1']
token = Curzon::AuthToken.new.fetch!
showtimes = Curzon::Showtimes.new(token, cinemas).fetch!

showtimes.sort_by{ |showtime| showtime[:film] }.each do |showtime|
  puts "#{showtime[:film]} #{showtime[:url]}"
  showtime[:times].sort_by{ |time| time[:starts_at] }.each do |times|
    puts " * #{Time.parse(times[:starts_at]).strftime("%H:%M")} - #{times[:site]}"
  end
  puts
end
