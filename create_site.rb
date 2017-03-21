require 'aws-sdk'
require 'json'

route53 = Aws::Route53::Client.new()
acm = Aws::ACM::Client.new()
s3 = Aws::S3::Client.new()
cloudfront = Aws::CloudFront::Client.new()

# For waiting
def loading(times)
  pinwheel = %w{| / - \\}
  times.times do
    print "\b" + pinwheel.rotate!.first
    sleep(0.1)
  end
end

# Get domain name from passed in arguments
domain_name = ARGV[0]

# 1) CREATE HOSTED ZONE FOR DOMAIN
# ======================================
# - Create a Route 53 hosted zone
puts "Creating DNS hosted zone..."
hosted_zone_resp = route53.create_hosted_zone({
  name: domain_name,
  caller_reference: Time.now().to_i.to_s,
})
hosted_zone_id = hosted_zone_resp.hosted_zone.id
name_servers = hosted_zone_resp.delegation_set.name_servers
puts "Finished creating DNS hosted zone."
puts "--------------------------------"

# 2) CONFIGURE CERTIFICATES
# ======================================
# - Create certificates to use for Cloudfront distributions
# - Should be set for root and wildcard domains for https
puts "Creating SSL certificate..."
certificate_resp = acm.request_certificate({
  domain_name: domain_name,
  subject_alternative_names: ["*.#{domain_name}"]
})
certificate_arn = certificate_resp.certificate_arn
puts "Finished creating certificate."
puts "--------------------------------"

# Wait until certificate has been approved before continuing to other steps
puts "Waiting for certificate verification (check your email)..."
certificate_status = ""
while certificate_status != "ISSUED"
  # poll every 15 seconds
  sleep(15)
  status_resp = acm.describe_certificate({
    certificate_arn: certificate_arn
  })
  certificate_status = status_resp.certificate.status
end
puts "Certificate verified."
puts "--------------------------------"

# 3) CONFIGURE S3
# ======================================
# - Create S3 buckets
# - Create a bucket for root domain for code w/ index.html as index doc
# - Create a bucket for www domain that is a redirect to root domain bucket
puts "Creating S3 buckets..."
s3.create_bucket({
  bucket: domain_name
})
s3.put_bucket_website({
  bucket: domain_name,
  website_configuration: { # required
    index_document: {
      suffix: "index.html",
    },
  },
})
s3.create_bucket({
  bucket: "www.#{domain_name}"
})
s3.put_bucket_website({
  bucket: "www.#{domain_name}",
  website_configuration: { # required
    redirect_all_requests_to: {
      host_name: domain_name, # required
      protocol: "https", # accepts http, https
    },
  }
})
puts "Finished creating buckets."
puts "--------------------------------"

# 4) CONFIGURE CLOUDFRONT
# ======================================
# - Create two cloudfront distributions for S3 buckets
# - www domain distribution should point to the S3 root bucket (endpoint url)
#   and have no origin root
# - Root domain distribution should point to the S3 root domain bucket and have origin set to index.html
# - both should redirect http to https
puts "Creating CloudFront distributions..."
cloudfront_root_domain_resp = cloudfront.create_distribution({
  distribution_config: { # required
    caller_reference: Time.now.to_i.to_s, # required
    aliases: {
      quantity: 1, # required
      items: [domain_name],
    },
    default_root_object: "index.html",
    origins: { # required
      quantity: 1, # required
      items: [
        {
          id: "S3-Website-#{domain_name}", # required
          domain_name: "#{domain_name}.s3.amazonaws.com", # required
          s3_origin_config: {
            origin_access_identity: "", # required
          },
        },
      ],
    },
    default_cache_behavior: { # required
      target_origin_id: "S3-Website-#{domain_name}", # required, must match origin id from above
      forwarded_values: { # required
        query_string: false, # required
        cookies: { # required
          forward: "none", # required, accepts none, whitelist, all
        },
      },
      trusted_signers: { # required
        enabled: false, # required
        quantity: 0, # required
      },
      viewer_protocol_policy: "redirect-to-https", # required, accepts allow-all, https-only, redirect-to-https
      min_ttl: 1, # required
      allowed_methods: {
        quantity: 2, # required
        items: ["GET", "HEAD"], # required, accepts GET, HEAD, POST, PUT, PATCH, OPTIONS, DELETE
        cached_methods: {
          quantity: 2, # required
          items: ["GET", "HEAD"], # required, accepts GET, HEAD, POST, PUT, PATCH, OPTIONS, DELETE
        },
      },
    },
    comment: "", # required
    price_class: "PriceClass_All", # accepts PriceClass_100, PriceClass_200, PriceClass_All
    enabled: true, # required
    viewer_certificate: {
      cloud_front_default_certificate: false,
      acm_certificate_arn: certificate_arn,
      ssl_support_method: "sni-only", # accepts sni-only, vip
      minimum_protocol_version: "TLSv1", # accepts SSLv3, TLSv1
      certificate_source: "acm", # accepts cloudfront, iam, acm
    },
    http_version: "http2", # accepts http1.1, http2
    is_ipv6_enabled: true,
  },
})
root_distribution_url = cloudfront_root_domain_resp.distribution.domain_name
cloudfront_www_domain_resp = cloudfront.create_distribution({
  distribution_config: { # required
    caller_reference: Time.now.to_i.to_s, # required
    aliases: {
      quantity: 1, # required
      items: ["www.#{domain_name}"],
    },
    default_root_object: "",
    origins: { # required
      quantity: 1, # required
      items: [
        {
          id: "S3-Website-www.#{domain_name}", # required
          domain_name: "www.#{domain_name}.s3.amazonaws.com", # required
          s3_origin_config: {
            origin_access_identity: "", # required
          },
        },
      ],
    },
    default_cache_behavior: { # required
      target_origin_id: "S3-Website-www.#{domain_name}", # required, must match origin id from above
      forwarded_values: { # required
        query_string: false, # required
        cookies: { # required
          forward: "none", # required, accepts none, whitelist, all
        },
      },
      trusted_signers: { # required
        enabled: false, # required
        quantity: 0, # required
      },
      viewer_protocol_policy: "redirect-to-https", # required, accepts allow-all, https-only, redirect-to-https
      min_ttl: 1, # required
      allowed_methods: {
        quantity: 2, # required
        items: ["GET", "HEAD"], # required, accepts GET, HEAD, POST, PUT, PATCH, OPTIONS, DELETE
        cached_methods: {
          quantity: 2, # required
          items: ["GET", "HEAD"], # required, accepts GET, HEAD, POST, PUT, PATCH, OPTIONS, DELETE
        },
      },
    },
    comment: "", # required
    price_class: "PriceClass_All", # accepts PriceClass_100, PriceClass_200, PriceClass_All
    enabled: true, # required
    viewer_certificate: {
      cloud_front_default_certificate: false,
      acm_certificate_arn: certificate_arn,
      ssl_support_method: "sni-only", # accepts sni-only, vip
      minimum_protocol_version: "TLSv1", # accepts SSLv3, TLSv1
      certificate_source: "acm", # accepts cloudfront, iam, acm
    },
    http_version: "http2", # accepts http1.1, http2
    is_ipv6_enabled: true,
  },
})
www_distribution_url = cloudfront_www_domain_resp.distribution.domain_name
puts "Finished creating distributions."
puts "--------------------------------"
print "Deploying distributions, this may take awhile (around 15 minutes)...."
cloudfront.wait_until(:distribution_deployed, id: cloudfront_root_domain_resp.distribution.id) do |w|
  w.before_wait do |attempts, response|
    loading 1000
  end
end
cloudfront.wait_until(:distribution_deployed, id: cloudfront_www_domain_resp.distribution.id) do |w|
  w.before_wait do |attempts, response|
    loading 1000
  end
end
puts "\nDistributions deployed."
puts "--------------------------------"

# 5) CONFIGURE DNS
# ======================================
# - Create DNS settings for domain
# - Create CNAME record for www subdomain and point it to the www distribution
# - Create A record as alias fro root domain and point it to the root distribution
puts "Configuring DNS..."
route53.change_resource_record_sets({
  change_batch: {
    changes: [
      {
        action: "CREATE",
        resource_record_set: {
          alias_target: {
            dns_name: root_distribution_url,
            evaluate_target_health: false,
            hosted_zone_id: hosted_zone_id,
          },
          name: domain_name,
          type: "A",
        },
      },
      {
        action: "CREATE",
        resource_record_set: {
          name: "www.#{domain_name}",
          resource_records: [
            {
              value: www_distribution_url,
            },
          ],
          ttl: 60,
          type: "CNAME",
        },
      },
    ],
    comment: "",
  },
  hosted_zone_id: hosted_zone_id,
})
puts "Finished configuration."
puts "--------------------------------"

puts "\n\n\n"
puts "Finished setting up S3 static website hosting"
puts "============================================="
puts "Domain name: #{domain_name}"
puts "Url: https://#{domain_name}"
puts "S3 bucket: s3://#{domain_name}"
puts "Name servers:"
name_servers.map { |server| puts "#{server}\n" }
puts "\n\n\n"
