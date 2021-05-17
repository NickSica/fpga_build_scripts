#!/usr/bin/tclsh

## Step 1: Define input arguments
proc getArgs {args} {
	global opts
	array set opts {partNum {} outDir build top {} constrFile boards/V707/constraints.xdc lang verilog srcDir rtl}
	while {[llength $args]} {
		switch -glob -- [lindex $args 0] {
			-part*   {set args [lassign $args - $opts(partNum)]}
			-out*    {set args [lassign $args - $opts(outDir)]}
			-top*    {set args [lassign $args - $opts(top)]}
			-constr* {set args [lassign $args - $opts(constrFile)]}
			-lang*   {set args [lassign $args - $opts(lang)]}
			-src*    {set args [lassign $args - $opts(srcDir)]}
			default  break
		}
	}
	#puts "opts: [array get opts]"
	#puts "other args: $args"
}

getArgs {*}$argv

file mkdir $opts(outDir)

## Step 2: Setup design sources and constraints
if {$opts(lang) != "verilog" && $opts(lang) != "vhdl" && $opts(lang) != "mixed"} {
	puts "Invalid language: [$opts(lang)]. Exiting."
	exit 1
}

if {$opts(lang) == "verilog" || $opts(lang) == "mixed"} {
	read_verilog -sv [ glob $opts(srcDir)/*.sv ]
}

if {$opts(lang) == "vhdl"} {
	read_vhdl [ glob ./src/*.vhd ]
}

read_xdc $opts(constrFile)

## Step 3: Run synthesis, write design checkpoint, report timing, and utilization estimates
synth_design -top $opts(top) -part $opts(partNum)
write_checkpoint -force $opts(outDir)/post_synth.dcp
report_timing_summary -file $opts(outDir)/post_synth_timing_summary.rpt
report_utilization -file $opts(outDir)/post_synth_util.rpt
# Run custom script to report critical timing paths
reportCriticalPaths $opts(outDir)/post_synth_critpath_report.csv

## Step 4: Run logic optimization, placement and physical logic optimization, write design checkpoint, report utilization and timing estimates
opt_design
reportCriticalPaths $opts(outDir)/post_opt_critpath_report.csv
place_design
report_clock_utilization -file $opts(outDir)/clock_util.rpt
# Optionally run optimization if there are timing violations after the placement
if{[ get_property SLACK [ get_timing_paths -max_paths 1 -nworst 1 -setup ] ] < 0} {
    puts "Found setup timing violations => running physical optimization"
    phys_opt_design
}
write_checkpoint -force $opts(outDir)/post_place.dcp
report_utilization -file $opts(outDir)/post_place_util.rpt
report_timing_summary -file $opts(outDir)/post_place_timing_summary.rpt

## Step 5: Run the router, write the post-route design checkpoint, report the routing status, report timing, power, and DRC, and finally save the Verilog netlist
route_design -directive Explore
write_checkpoint -force $opts(outDir)/post_route.dcp
report_route_status -file $opts(outDir)/post_route_status.rpt
report_timing_summary -file $opts(outDir)/post_route_timing_summary.rpt
report_power -file $opts(outDir)/post_route_power.rpt
report_drc -file $opts(outDir)/post_imp_drc.rpt
write_verilog -sv -force $opts(outDir)/cpu_impl_netlist.sv -mode timesim -sdf_anno true

## Step 6: Generate a bitstream
write_bitstream -force $opts(outDir)/$opts(top).bit
