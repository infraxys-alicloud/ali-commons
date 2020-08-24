function ensure_aliyun() {
    local aliyun_version;
    import_args "$@";
    check_required_arguments "ensure_aliyun" aliyun_version;

    local ALIYUN="aliyun-$aliyun_version";
    if [ $(which "$ALIYUN") ]; then
        log_info "Aliyun version $aliyun_version is already installed at $(which $ALIYUN).";
    else
        log_info "Aliyun version $aliyun_version not available. Installing it now in the project cache.";
        curl -sL -o /tmp/aliyun.zip https://aliyuncli.alicdn.com/aliyun-cli-linux-${aliyun_version}-amd64.tgz
        cd /tmp;
        tar -xzf aliyun.zip;
        chmod u+x aliyun;
        mv aliyun "/cache/project/bin/$ALIYUN";
        rm -f aliyun.zip;
        cd ->/dev/null;
        log_info "Aliyun $aliyun_version is available at $(which $ALIYUN)";
    fi;
}

function set_aliyun_profile() {
    local profile_name;
    import_args "$@";
    check_required_arguments "set_aliyun_profile" profile_name;

    if [ ! -f ~/.aliyun/config.json ]; then
        local variable_file="/tmp/infraxys/variables/ALIYUN-CONFIG/ALIYUN-CONFIG";
        if [ ! -f "$variable_file" ]; then
            # file should have been loaded automatically alreday by this script (see below)
            log_fatal "$variable_file not found. It's required so it can be copied to ~/.aliyun/config.json.";
        fi;
    fi;
    ensure_aliyun --aliyun_version "3.0.46";
    export ALIYUN="aliyun-3.0.46";
    log_info "Using Aliyun binary $(which $ALIYUN).";
    log_info "Setting Aliyun profile to $profile_name.";
    $ALIYUN configure set $profile_name;
}

aliyun_variable_file="/tmp/infraxys/variables/ALIYUN-CONFIG/ALIYUN-CONFIG";
if [ -f "$aliyun_variable_file" ]; then
    log_info "Using $aliyun_variable_file as the Aliyun profile file"
    mkdir -p ~/.aliyun;
    cp "$aliyun_variable_file" ~/.aliyun/config.json;
fi;