#if ($enable_destroy == "0")
	#set ($skip_action_creation = true)
#end

#[[
cd "$TERRAFORM_TEMP_DIR";

terraform_plan_destroy_confirm_apply;
]]#