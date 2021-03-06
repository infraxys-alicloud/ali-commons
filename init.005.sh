export ALIYUN_COMMONS_MODULE_DIR="$(pwd)";
export PYTHONPATH="$(pwd)/python:$PYTHONPATH";

if [ "$cloud_provider" == "ALIYUN" ]; then
    pip install aliyun-python-sdk-core-v3 # Install the Alibaba Cloud SDK for Python core library.
    pip install aliyun-python-sdk-ecs
    pip install aliyun-python-sdk-vpc
    #pip install aliyun-python-sdk-rds
fi;

function set_alicloud_env() {
    export function_name="set_alicloud_env" var_prefix alicloud_region;
    import_args "$@";
    check_required_arguments "$function_name" var_prefix alicloud_region;

    log_info "Setting AliCloud environment to variables '${var_prefix}_ALICLOUD_ACCESS_KEY', '${var_prefix}_ALICLOUD_SECRET_KEY' and '${var_prefix}_ALICLOUD_REGION'.";


    local var_alicloud_region="${var_prefix}ALICLOUD_REGION";
    local var_alicloud_access_key="${var_prefix}ALICLOUD_ACCESS_KEY";

    export ALICLOUD_REGION="$alicloud_region";
    export ALICLOUD_ACCESS_KEY="${!var_alicloud_access_key}";
    export ALICLOUD_SECRET_KEY="${!var_alicloud_secret_key}";

    [[  -z "$ALICLOUD_ACCESS_KEY" || -z "$ALICLOUD_SECRET_KEY" ]] && \
        log_fatal "AliCloud environment could not be configured because not all required variables exist: $var_alicloud_access_key and $var_alicloud_secret_key.";
}

if [ -n "$alicloud_key_var_prefix" ]; then
  set_alicloud_env --var_prefix "$alicloud_key_var_prefix" --alicloud_region "$alicloud_region";
else
  log_info "Not setting Aliyun environment automatically because variable 'alicloud_key_var_prefix' is not set."
fi;
