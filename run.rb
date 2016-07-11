require 'bundler/setup'
require 'yahoo_weatherman'
require 'artoo'
require 'gmail'
require 'highline/import'
require 'rainbow'

connection :firmata, :adaptor => :firmata, :port => '/dev/cu.usbmodem1411' 

device :board, :driver => :device_info
device :led13, :driver => :led, :pin => 13 # led indicator for: good
device :led12, :driver => :led, :pin => 12 # led indicator for: okay
device :led11, :driver => :led, :pin => 11 # led indicator for: bad
device :led10, :driver => :led, :pin => 10 # gmail notifier
device :button, driver: :button, pin: 5, interval: 0.01

# Get user information
account = ask("Enter your Gmail account name: ") { |q| q.echo = true }
password = ask("Enter your Gmail password: ") { |q| q.echo = false }
zip = ask("Enter your zipcode: ") { |q| q.echo = true }

# Retrieve Gmail account and set initial unread count
gmail = Gmail.connect(account, password)
prev_unread = gmail.inbox.count(:unread)

# Retrieve weather information for desired zipcode
client = Weatherman::Client.new
response = client.lookup_by_location(zip)

# Arrays of weather conditions based on Yahoo Weather API's condition codes
good = ['31', '32', '33', '34']
okay = ['19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '36', '44']
bad = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '35', '37', '38', '39', '40', '41', '42' '43', '45', '46','47']
unavail = ['3200']


# Start artoo work loop
work do
  
  # Turns off Gmail notification light  
  on button, :push    => proc { led10.on }
  on button, :release => proc { led10.off }  
  
  every 10.second do

### Gmail notification indicator ###

    # Turns off Gmail notification light  
    # on button, :push    => proc { led10.on }
    # on button, :release => proc { led10.off }  

    # Checks to see if any new emails have been received
    unread = gmail.inbox.count(:unread)
    puts "Unread e-mails".bright.color(:white).background(:red) + " #{unread}"

    # When a new email is received, LED turns on if it was off and blinks 5 times  
    if unread > prev_unread
      led10.on if led10.off?
      if led10.on?
        10.times do 
          led10.on? ? led10.off : led10.on
          sleep 0.5
        end
      end
    end

    # Sets the email count to current count
    prev_unread = unread

### Weather indicator ###

    # Checks for updated weather conditions
    response = client.lookup_by_location(zip)
    code = response.condition['code'].to_s

    # Uses yahoo weather condition code to determine condition
    if good.any? {|condition| code.include? condition }
      current = "good"
    elsif okay.any? {|condition| code.include? condition }
      current = "okay"
    elsif bad.any? {|condition| code.include? condition } 
      current = "bad"
    else
      current = "unavailable"
    end

    # Green LEDS = good weather, Blue LEDS = okay weather, Red LEDS = bad weather
    if current == "good"
      color = Rainbow(current).bright.green
      led13.on if led13.off?
      led12.off if led12.on?
      led11.off if led11.on?
    elsif current == "okay"
      color = Rainbow(current).bright.blue
      led12.on if led12.off?
      led13.off if led13.on?
      led11.off if led11.on?
    elsif current == "bad"
      color = Rainbow(current).bright.red
      led11.on if led11.off?
      led13.off if led13.on?
      led12.off if led12.on?
    else 
      led13.off if led13.on?
      led12.off if led12.on?
      led11.off if led11.on?
    end

    fahrenheit = (response.condition['temp'] * 9/5 + 32).round


print <<"OUTPUT"
Current weather conditions for #{response.location['city']},#{response.location['region']} are #{color}:
#{Rainbow(fahrenheit).bright} degrees
#{response.condition['text']}

OUTPUT

  end
end