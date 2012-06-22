require 'nokogiri'
require 'open-uri'
require 'csv'

class Knight

  PAGES = 81

  BASE_URL = "http://newschallenge.tumblr.com/page"  

  QUESTION_0 = /1\..*What do you propose to do\? *(\[?\(?20 words\]?\)?)?/
  QUESTION_1 = /2\..*How will your project make data more useful\? *(\[?\(?50 words\]?\)?)?/
  QUESTION_2 = /3\..*How is your project different from what already exists\? *(\[?\(?30 words\]?\)?)?/
  QUESTION_3 = /4\..*Why will it work\? *(\[?\(?100 words\]?\)?)?/
  QUESTION_4 = /5\..*Who is working on it\? *(\[?\(?100 words\]?\)?)?/
  QUESTION_5 = /6\..*What part of the project have you already built\? *(\[100 words\])?/
  QUESTION_6 = /7\..*How would you use News Challenge funds?\? *(\[?\(?50 words\]?\)?)?/
  QUESTION_7 = /8\..*How would you sustain the project after the funding expires\? *(\[?\(?50 words\]?\)?)?/

  REQUESTED_AMOUNT = /Requested amount:/
  COMPLETION_TIME = /Expected number of months to complete project:/
  TOTAL_COST = /Total Project Cost:/
  NAME = /Name:/
  TWITTER = /Twitter:/
  EMAIL_ADDRESS = /Email address \[optional\]:/
  ORGANIZATION = /Organization:/
  CITY = /City:/
  COUNTRY = /Country:/
  HOW = /How did you learn about the contest\?/

  @@questions = Hash.new

  def initialize
    @@questions["question_0"] = {"question_regex" => QUESTION_0}
    @@questions["question_1"] = {"question_regex" => QUESTION_1}
    @@questions["question_2"] = {"question_regex" => QUESTION_2}
    @@questions["question_3"] = {"question_regex" => QUESTION_3}
    @@questions["question_4"] = {"question_regex" => QUESTION_4}
    @@questions["question_5"] = {"question_regex" => QUESTION_5}
    @@questions["question_6"] = {"question_regex" => QUESTION_6}
    @@questions["question_7"] = {"question_regex" => QUESTION_7}
  end

  def parse_entries    
    entries = []
    page_counter = 0

    CSV.open("/tmp/knight-entries.csv", "wb") do |csv|

      csv << ["title",
              "url",
              "amount",
              "answer_0",
              "answer_1",
              "answer_2",
              "answer_3",
              "answer_4",
              "answer_5",
              "answer_6",
              "answer_7"
              ]

      # entries are paginated
      while page_counter < PAGES do

        url = "#{BASE_URL}/#{page_counter}"
        puts "#{url}"

        doc = Nokogiri::HTML(open(url))

        # 9 entries per page
        doc.css('div.postbox').each do |post|

          # each entry submission is a link on the page
          post.css('h2 a').each_with_index do |link, index|
            puts "============================="

            entry_url = link.attribute('href').to_s
            puts "Entry: #{entry_url}"
            title = link.content

            # The first entry on each page is from Knight
            unless entry_url.include? "/post/24130238607/knight-news-challenge-data-is-now-open"
              entry = parse_entry(entry_url)
              entry["title"] = title
              entry["url"] = entry_url
              entries << entry
              csv << [entry["title"],
                      entry["url"],
                      entry["amount"],
                      entry["answer_0"],
                      entry["answer_1"],
                      entry["answer_2"],
                      entry["answer_3"],
                      entry["answer_4"],
                      entry["answer_5"],
                      entry["answer_6"],
                      entry["answer_7"]
                      ]
            end

          end
        end
        page_counter += 1
      end
      puts "Number of entries: #{entries.length}"
    end
  end

  # returns an entry from the url
  def parse_entry(url)
    doc = Nokogiri::HTML(open(url))
      
      entry = Hash.new
      # puts ">>> parsing entry"

      # lets go get the entry details
      entry_doc = Nokogiri::HTML(open(url))
      entry_details = entry_doc.css('div.single')

      entry_text = entry_details.text
      entry_text.gsub!(/\n+/, " ")
      entry_text = entry_text.split.join(' ')

      question_count = 0
      while question_count < 8 do
        question_key = "question_#{question_count}"
        puts ">>> Question #{question_key}"
        next_index = question_count+1
        next_question_key = "question_#{next_index}"

        begin
          # use the question regular expressions
          entry_text =~ @@questions[question_key]["question_regex"]          
          answer_start = $~.end(0)

          unless question_count == 7
            entry_text =~ @@questions[next_question_key]["question_regex"]
            answer_end = $~.begin(0)-1
          else
            entry_text =~ REQUESTED_AMOUNT
            answer_end = $~.begin(0)-1
          end

          answer = entry_text[answer_start..answer_end]
          answer = answer.squeeze(" ").strip

          answer_key = "answer_#{question_count}"
          entry[answer_key] = answer
          # puts "#{answer}"
        rescue Exception => e  
          puts "!!! ERROR #{e.message}"
        end

        question_count += 1
        # puts "----"
      end

      begin
        entry_text =~ REQUESTED_AMOUNT
        requested_amount_start = $~.end(0)

        entry_text =~ COMPLETION_TIME
        requested_amount_end = $~.begin(0)-1

        requested_amount = entry_text[requested_amount_start..requested_amount_end]
        requested_amount.strip!
        unless requested_amount.empty?
          entry["amount"] = requested_amount.split("\n").first.gsub(/\$|,|USD||k||M|\./, "").to_i
          puts ">>> REQUESTED AMOUNT: #{entry["amount"]}"
        end

        # # Extract meaning from the text
        # json = Calais.enlighten(content: document.extracted_text,
        #                         content_type: :raw,
        #                         output_format: :json,
        #                         license_id: Constants::OPEN_CALAIS_API_KEY)

        # puts json

      rescue Exception => e  
        puts "!!! ERROR #{e.message}"
      end

    return entry
  end
end