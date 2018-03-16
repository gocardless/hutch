source 'https://rubygems.org'

ruby RUBY_VERSION

gemspec

group :development do
  gem "rake"
  gem "guard", "~> 2.14", platform: :mri_23
  gem "guard-rspec", "~> 4.7", platform: :mri_23

  gem "yard", "~> 0.9"
  gem 'kramdown', "> 0", platform: :jruby
  gem "redcarpet", "> 0", platform: :mri
  gem "github-markup", "> 0"
end

group :development, :test do
  gem "rspec", "~> 3.5"
  gem "simplecov", "~> 0.12"

  gem "sentry-raven"
  gem "honeybadger"
  gem "coveralls", "~> 0.7.2", require: false
  gem "newrelic_rpm"
  gem "airbrake", "~> 7.0"
  gem "opbeat", "~> 3.0.9"
end

group :development, :darwin do
  gem "rb-fsevent", "~> 0.9"
  gem "growl", "~> 1.0.3"
end
