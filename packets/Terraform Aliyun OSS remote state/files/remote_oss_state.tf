terraform {
  backend "oss" {
    profile = "$instance.getAttribute("aliyun_profile_name")"
    bucket = "$instance.getAttribute("state_bucket")"
    prefix   = "$instance.getAttribute("state_prefix")"
    key   = "$instance.getAttribute("state_key")"
    region = "$instance.getAttribute("state_region")"
  }
}