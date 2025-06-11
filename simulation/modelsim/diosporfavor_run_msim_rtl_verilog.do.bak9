transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -sv -work work +incdir+D:/Arqui2/sis {D:/Arqui2/sis/PE_SW.sv}
vlog -sv -work work +incdir+D:/Arqui2/sis {D:/Arqui2/sis/SystolicArray8x8.sv}

vlog -sv -work work +incdir+D:/Arqui2/sis {D:/Arqui2/sis/tb_systolic8x8.sv}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  tb_systolic8x8

add wave *
view structure
view signals
run -all
