transcript on
if {[file exists rtl_work]} {
	vdel -lib rtl_work -all
}
vlib rtl_work
vmap work rtl_work

vlog -sv -work work +incdir+D:/Arqui2/proy2_Arqui2/FlujoRealista {D:/Arqui2/proy2_Arqui2/FlujoRealista/PE_SO.sv}

vlog -sv -work work +incdir+D:/Arqui2/proy2_Arqui2/Pruebas {D:/Arqui2/proy2_Arqui2/Pruebas/PE_SO_tb.sv}

vsim -t 1ps -L altera_ver -L lpm_ver -L sgate_ver -L altera_mf_ver -L altera_lnsim_ver -L cyclonev_ver -L cyclonev_hssi_ver -L cyclonev_pcie_hip_ver -L rtl_work -L work -voptargs="+acc"  PE_SO_tb

add wave *
view structure
view signals
run -all
