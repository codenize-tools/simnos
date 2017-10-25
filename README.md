# Simnos

Simons is a tool to manage AWS SNS topic.
It defines the state of SNS topic using DSL, and updates SNS topic according to DSL.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'simnos'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install simnos

## Usage

```
export AWS_ACCESS_KEY_ID='...'
export AWS_SECRET_ACCESS_KEY='...'
export AWS_REGION='ap-northeast-1'
simnos -e -f SNSfile  # export SNS topic
vi SNSfile
simnos -a --dry-run
simnos -a             # apply `SNSfile` to SNS
```

## Help

```
Usage: simnos [options]
    -h, --help                       show help
    -v, --debug                      show debug log
    -a, --apply                      apply DSL
    -e, --export                     export to DSL
    -n, --dry-run                    dry run
    -f, --file FILE                  use selected DSL file
    -s, --split                      split export DSL file to 1 per topic
        --no-color
                                     no color
        --with-subscriptions
                                     manage subscriptions
        --secret-provider NAME
                                     use secret value expansion
    -i, --include-names NAMES        include SNS names
    -x, --exclude-names NAMES        exclude SNS names by regex
```

## SNSfile

```ruby
sns "ap-northeast-1" do
  topic "test-topic" do
    display_name "test topic"

    effective_delivery_policy do
      {"http"=>
        {"defaultHealthyRetryPolicy"=>
          {"minDelayTarget"=>20,
           "maxDelayTarget"=>20,
           "numRetries"=>2,
           "numMaxDelayRetries"=>0,
           "numNoDelayRetries"=>0,
           "numMinDelayRetries"=>0,
           "backoffFunction"=>"linear"},
         "disableSubscriptionOverrides"=>false}}
    end

    policy do
      {"Version"=>"2008-10-17",
       "Id"=>"__default_policy_ID",
       "Statement"=>
        [{"Sid"=>"__default_statement_ID",
          "Effect"=>"Allow",
          "Principal"=>{"AWS"=>"*"},
          "Action"=>"SNS:Subscribe",
          "Resource"=>"arn:aws:sns:ap-northeast-1:XXXXXXXXXXXX:test-topic",
          "Condition"=>{"StringEquals"=>{"AWS:SourceOwner"=>"XXXXXXXXXXXX"}}}]}
    end

    subscriptions opt_out: false do
      subscription protocol: "https", endpoint: "https://your.awesome.site/"
      subscription protocol: "email", endpoint: "simnos@example.com"
      subscription protocol: "email-json", endpoint: "simnos@example.com"
      subscription protocol: "sqs", endpoint: "arn:aws:sqs:ap-northeast-1:XXXXXXXXXXXX:test-queue"
    end
  end
end
```

## Use template

```ruby
template "default_policy" do
  policy do
    {"Version"=>"2008-10-17",
     "Id"=>"__default_policy_ID",
     "Statement"=>
      [{"Sid"=>"__default_statement_ID",
        "Effect"=>"Allow",
        "Principal"=>{"AWS"=>"*"},
        "Action"=>"SNS:Subscribe",
        "Resource"=>"arn:aws:sns:ap-northeast-1:XXXXXXXXXXXX:#{context.topic_name}",
        "Condition"=>{"StringEquals"=>{"AWS:SourceOwner"=>"XXXXXXXXXXXX"}}}]}
  end
end

sns "ap-northeast-1" do
  include_template "default_policy", topic_name: "test-topic"
end
```

## Secret provider

If you don't want to commit your Basic authentication password, you can use SecretProvider.
Use --secret-provider option to select provider.(e.g. --secret-provider=vault)
Expression inside `${...}` is passed to provider.

```
    subscriptions do
      subscription protocol: "https", endpoint: "https://user:${password}your.awesome.site/"
    end
```

## Similar tools

* [Codenize.tools](http://codenize.tools/)

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/codenize-tools/simnos.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).

