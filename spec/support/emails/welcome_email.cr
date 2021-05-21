class WelcomeEmail < BaseEmail
  def initialize(@name : String, @email_address : String)
  end

  from "no-reply@example.tld"
  to @email_address
  subject "Welcome, #{@name}!"

  def text_body : String
    <<-TEXT
    Welcome
    TEXT
  end
end
