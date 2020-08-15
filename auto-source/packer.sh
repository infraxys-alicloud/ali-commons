function ensure_packer() {
  PACKER_VERSION="${PACKER_VERSION:-"1.6.0"}";
  export PACKER="/usr/local/bin/packer-$PACKER_VERSION";
  if [ -f "$filename" ]; then
    log_info "Using Packer version $PACKER_VERSION.";
  else
    log_info "Installing Packer version $PACKER_VERSION";
    curl -sSLo "/tmp/packer.zip" https://releases.hashicorp.com/packer/$PACKER_VERSION/packer_${PACKER_VERSION}_linux_amd64.zip;
    cd /tmp && unzip packer.zip;
    mv packer $PACKER
    rm -f packer.zip;
    chmod u+x "$PACKER";
  fi;
}

function run_aliyun_packer() {
	local packer_directory ami_name_prefix ami_description source_image vpc_name ssh_username="root" \
	    ssh_bastion_username ssh_bastion_private_key_file security_group_name vswitch_name aliyun_region aliyun_profile \
	    instance_type packer_json_file;
	import_args "$@";
	check_required_arguments "run_aliyun_packer" packer_directory ami_name_prefix ami_description vpc_name \
	    bastion_name ssh_bastion_username ssh_bastion_private_key_file security_group_name vswitch_name aliyun_region \
	    source_image aliyun_profile instance_type ssh_username packer_json_file;

	local ssh_bastion_host vpc_id;

	ensure_packer;

    get_aliyun_vpc_id --vpc_name "$vpc_name" --region "$aliyun_region" --target_variable_name vpc_id;
    get_aliyun_security_group_id --vpc_id "$vpc_id" --security_group_name $security_group_name --target_variable_name security_group_id;
    get_aliyun_vswitch_id --vpc_id "$vpc_id" --vswitch_name $vswitch_name --target_variable_name vswitch_id;
    get_aliyun_instance_public_ip --vpc_id "$vpc_id" --instance_name "$bastion_name" --target_variable_name ssh_bastion_host;

    log_info "Initializing Packer environment.";
    export vpc_id security_group_id vswitch_id ssh_bastion_host ssh_bastion_private_key_file ssh_bastion_username ssh_username \
        ami_name_prefix ami_description;

    log_info "Using vpc '$vpc_id', security group '$security_group_id', vswitch '$vswitch_id' and bastion host '$ssh_bastion_host'.";

    export packer_tmp_dir="/tmp/packer$$";
    export packer_target_dir="/tmp/packer$$";
    mkdir $packer_tmp_dir;

    if [ -d "$packer_directory/provisioner" ]; then
      cp -R $packer_directory/provisioner/* $packer_tmp_dir;
    fi;

    run_or_source_files --directory "$packer_directory" --filename_pattern 'init*';

    if [ -f "$INSTANCE_DIR/$packer_json_file" ]; then
        local json_filename="$INSTANCE_DIR/$packer_json_file";
        log_info "Using $packer_json_file from the packet.";
        cat "$json_filename"
    else
        local json_filename="$packer_directory/$packer_json_file";
        log_info "Packet doesn't contain a file name '$packer_json_file', so using $json_filename instead";
        [[ ! -f "$json_filename" ]] && log_error "File '$json_filename' must exist." && exit 1;
    fi;

    extra_packer_options="";
    if [ "$debug_mode" == "1" ]; then
        extra_packer_options="-debug";
        export PACKER_LOG=1;
    fi;

    [[ "$do_encrypt_boot" == "1" ]] && export encrypt_boot="true" || export encrypt_boot="false";

    oldpwd="$(pwd)";

    cd $packer_tmp_dir


    $PACKER build $extra_packer_options -machine-readable $json_filename | tee result.out

    grep 'artifact,0,id' result.out | cut -d, -f6 | cut -d: -f2
    ami_id="$(grep 'artifact,0,id' result.out | cut -d, -f6 | cut -d: -f2)";

    echo "--------- ami: --$ami_id-- --------";
    cd $oldpwd;
}

