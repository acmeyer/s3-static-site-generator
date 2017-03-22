# S3 Static Website Generator

The S3 Static Website Generator is a script to set up hosting a secure and scalable website on Amazon's AWS S3.

## Why

Websites are needed for just about everything these days. The problem is hosting a simple, secure, and scalable website is not as cheap and easy as it should be.

Amazon's AWS S3 service enables you to host a website that's cheap and scales well, but configuring this yourself is still not that simple. You still need to be familiar with AWS and know about provisioning SSL certificates and DNS hosting, and even if you are familiar, you still have to manually do it each time you want to host a new website.

The S3 Static Website Generator was made to make launching a secure and scalable website on S3 as simple as possible. Running the script will handle everything from setting up your DNS, providing your site a SSL certificate, and creating a S3 bucket for your website's code.

## How to use

First, you'll need an AWS account. If you don't already have one, you can sign up for one [here](https://aws.amazon.com/).

This script also assumes you have created an IAM user with admin access permissions ([here's how to do this](https://docs.aws.amazon.com/lambda/latest/dg/setting-up.html)) and have stored that user's credentials locally under the `~/.aws` directory or have set those credentials as environment variables ([read more here](https://docs.aws.amazon.com/sdk-for-ruby/v2/developer-guide/setup-config.html)).

Second, you'll have to have Ruby 2.0 or higher installed on your machine ([how to install Ruby](https://www.ruby-lang.org/en/documentation/installation/)).

Once you have AWS and Ruby set up, all you have to do is clone this repository:

`git clone git@github.com:acmeyer/s3-static-site-generator.git`

go into the directory:

`cd s3-static-site-generator`

install the AWS SDK (if you don't already have it installed):

`gem install aws-sdk`

and run the script (replace *yourdomain.com* below with your domain name):

`ruby create_site.rb yourdomain.com`

That's it!

The script will run and let you know it's progress. It can take up to 20 minutes to complete. Go grab yourself a much deserved coffee!

When it's finished, it will print the url of your site, the S3 bucket to upload your website code to, and the name servers to point your DNS to. You'll have to point your DNS name servers to these name servers in order to see your site when accessing it's url. This also may take some time before you can access your site.

<!-- ## How to Remove

If you would like to remove your website from S3, all you have to do is run the following script (again, replace *yourdomain.com* with the domain of the S3 website you want to remove):

`ruby remove_site.rb yourdomain.com` -->

## Contributing

- Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet
- Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it
- Fork the project
- Start a feature/bugfix branch
- Commit and push until you are happy with your contribution

## TODOs

- [ ] Add script to remove site
- [ ] Handle S3 bucket names not available
- [ ] Handle non-root domain name
- [ ] Handle script errors
- [ ] Handle multiple runs on same domain name
- [ ] Add automatic uploading of website code


## License

Released under the MIT License. See http://opensource.org/licenses/MIT for more information.

## Help

If you need help with this script [send me an email](mailto:acomeyer@gmail.com). I'll try my best to help you out.
