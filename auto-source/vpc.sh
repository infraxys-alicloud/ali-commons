function generate_ssh_config_for_aliyun_vpc() {
  local function_name="generate_ssh_config_for_aliyun_vpc" vpc_name profile_name name_list_json_file="/tmp/servers.json";
  import_args "$@";
  check_required_arguments "$function_name" vpc_name profile_name;
  log_info "Generating SSH configuration for Aliyun VPC $vpc_name, profile $profile_name into ~/.ssh/generated.d/$vpc_name.";
  $ALIYUN_COMMONS_MODULE_DIR/utils/generate_aliyun_vpc_ssh_config.py "$profile_name" "$vpc_name" ~/.ssh/generated.d/$vpc_name "$name_list_json_file";
  log_info "--- ~/.ssh/generated.d/$vpc_name:"
  cat ~/.ssh/generated.d/$vpc_name
}

# Get the json for the vpc with name = argument 'vpc_name'
#   if the <vpc_name> was already retrieved, then get the json from the cached variable
#   otherwise get the json using the Aliyun CLI and cache the result
# Call this function with argument 'target_variable_name' to avoid the need of running it in a sub-shell.
function get_aliyun_vpc() {
    local vpc_name target_variable_name fail_if_not_found="true" region;
    import_args "$@";
    check_required_arguments "get_aliyun_vpc" vpc_name target_variable_name region;

    cache_variable_name="aliyun_vpc_json_${vpc_name//[-.]/_}";
    local cached_value="${!cache_variable_name}";

    if [ -n "$cached_value" ]; then
        local _get_vpc="$cached_value";
        log_debug "Retrieved Aliyun VPC config for '$vpc_name' from cache.";
    else
        log_info "Retrieving Aliyun VPC '$vpc_name'.";
        local _get_vpc="$($ALIYUN ecs DescribeVpcs --PageSize 50 --RegionId "$region" | jq -r '.Vpcs .Vpc [] | select(.VpcName == "'$vpc_name'")')";
    fi;

    if [ -z "$_get_vpc" -a "$fail_if_not_found" == "true" ]; then
        log_fatal "No Aliyun VPC with name '$vpc_name' found. This is normal in case the environment was not yet created.";
    fi;
    eval "$cache_variable_name='$_get_vpc'";
    eval "$target_variable_name='$_get_vpc'";
}

function get_aliyun_instance() {
    local vpc_id target_variable_name fail_if_not_found="true" instance_name;
    import_args "$@";
    check_required_arguments "get_aliyun_instance" vpc_id instance_name target_variable_name;

    log_info "Retrieving Aliyun instance '$instance_name' from VPC '$vpc_id'.";
    local _get_instance="$($ALIYUN ecs DescribeInstances --VpcId $vpc_id --InstanceName "$instance_name" | jq -r '.Instances .Instance[0]')";

    if [ -z "$_get_instance" -a "$fail_if_not_found" == "true" ]; then
        log_fatal "No Aliyun instance '$instance_name' found.";
    fi;

    eval "$target_variable_name='$_get_instance'";
}

function get_aliyun_vpc_id() {
    local vpc_name target_variable_name fail_if_not_found="true" region;
    import_args "$@";
    check_required_arguments "get_aliyun_vpc_id" vpc_name region target_variable_name;

    local _get_vpc_id;
    get_aliyun_vpc --region "$region" --vpc_name "$vpc_name" --target_variable_name "_get_vpc_id" --fail_if_not_found "$fail_if_not_found";

    if [ -n "$_get_vpc_id" ]; then
        _get_vpc_id="$(echo "$_get_vpc_id" | jq -r ".VpcId")";
    fi;

    eval "$target_variable_name='$_get_vpc_id'";
}

function get_aliyun_security_group_id() {
    local vpc_id security_group_name target_variable_name fail_if_not_found="true";
    import_args "$@";
    check_required_arguments "get_aliyun_security_group_id" vpc_id target_variable_name security_group_name;

    log_info "Retrieving security group '$security_group_name' from VPC '$vpc_id'.";
    local sg_json="$($ALIYUN ecs DescribeSecurityGroups --SecurityGroupName "$security_group_name" --VpcId $vpc_id | jq -r '.SecurityGroups .SecurityGroup[0]')";
    if [ -n "$sg_json" -a "$sg_json" != "null" ]; then
        local sg_id="$(echo "$sg_json" | jq -r '.SecurityGroupId')"
    else
        if [ "$fail_if_not_found" == "true" ]; then
            log_fatal "No Aliyun security group with name '$security_group_name' found.";
        fi;
        local sg_id="";
    fi;

    eval "$target_variable_name='$sg_id'";
}

function get_aliyun_vswitch_id() {
    local vpc_id vswitch_name target_variable_name fail_if_not_found="true";
    import_args "$@";
    check_required_arguments "get_aliyun_vwitch_id" vpc_id target_variable_name vswitch_name;

    log_info "Retrieving VSwitch '$vswitch_name' from VPC '$vpc_id'.";
    local switch_json="$($ALIYUN ecs DescribeVSwitches --PageSize 50 --VpcId $vpc_id | jq -r '.VSwitches .VSwitch [] | select(.VSwitchName == "'$vswitch_name'")')";

    if [ -n "$switch_json" -a "$switch_json" != "null" ]; then
        local switch_id="$(echo "$switch_json" | jq -r '.VSwitchId')"
    else
        if [ "$fail_if_not_found" == "true" ]; then
            log_fatal "No Aliyun vswitch '$vswitch_name' found.";
        fi;
        local switch_id="";
    fi;

    eval "$target_variable_name='$switch_id'";
}

function get_aliyun_instance_public_ip() {
    local vpc_id instance_name target_variable_name fail_if_not_found="true";
    import_args "$@";
    check_required_arguments "get_aliyun_instance_public_ip" vpc_id target_variable_name instance_name;

    local _instance_json;
    get_aliyun_instance --vpc_id "$vpc_id" --instance_name "$instance_name" --target_variable_name "_instance_json" \
        --fail_if_not_found "$fail_if_not_found";

    log_info "Retrieving public IP of instance '$instance_name' from VPC '$vpc_id'.";
    if [ -n "$_instance_json" -a "$_instance_json" != "null" ]; then
        local instance_ip="$(echo "$_instance_json" | jq -r '.PublicIpAddress .IpAddress[0]')"
    else
        if [ "$fail_if_not_found" == "true" ]; then
            log_fatal "No Aliyun instance '$instance_name' found in VPC '$vpc_id'.";
        fi;
        local instance_ip="";
    fi;

    eval "$target_variable_name='$instance_ip'";
}