set name [current_scope]
set instance $name
append instance "*"
add_wave_divider [current_scope]
add_wave_group [current_scope]
add_wave -into $name $instance
save_wave_config -object [get_wave_configs tb.wcfg] ./waves/

