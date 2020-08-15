#if ($require_confirmation == "1")
	#set ($skip_action_creation = true)
#end

#[[
cd "$TERRAFORM_TEMP_DIR";
terraform_apply;
]]#