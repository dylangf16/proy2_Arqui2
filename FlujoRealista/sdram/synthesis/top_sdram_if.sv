`timescale 1ns/1ps

module top_sdram_if (
  input  logic           clk_clk,
  input  logic           reset_reset_n,

  // Pines físicos hacia la SDRAM (conduit “wire_*”)
  output logic [12:0]    wire_addr,
  output logic [1:0]     wire_ba,
  output logic           wire_cas_n,
  output logic           wire_cke,
  output logic           wire_cs_n,
  inout  logic [15:0]    wire_dq,
  output logic [1:0]     wire_dqm,
  output logic           wire_ras_n,
  output logic           wire_we_n
);

  // 1) Instanciamos la interfaz Avalon–MM
  avl_sdram_if sdram_if (
    .clk     (clk_clk),
    .reset_n (reset_reset_n)
  );

  // 2) Instanciamos el controlador SDRAM
  sdram dut (
    .clk_clk             (clk_clk),
    .reset_reset_n       (reset_reset_n),

    // Avalon–MM slave
    .sdram_address       (sdram_if.address),
    .sdram_byteenable_n  (sdram_if.byteenable_n),
    .sdram_chipselect    (sdram_if.chipselect),
    .sdram_read_n        (sdram_if.read_n),
    .sdram_write_n       (sdram_if.write_n),
    .sdram_writedata     (sdram_if.writedata),
    .sdram_readdata      (sdram_if.readdata),
    .sdram_readdatavalid (sdram_if.readdatavalid),
    .sdram_waitrequest   (sdram_if.waitrequest),

    // Conduit hacia SDRAM física
    .wire_addr           (wire_addr),
    .wire_ba             (wire_ba),
    .wire_cas_n          (wire_cas_n),
    .wire_cke            (wire_cke),
    .wire_cs_n           (wire_cs_n),
    .wire_dq             (wire_dq),
    .wire_dqm            (wire_dqm),
    .wire_ras_n          (wire_ras_n),
    .wire_we_n           (wire_we_n)
  );

  // Señal para capturar el dato leído
  logic [15:0] rdata;

  // 3) Test sencillo de lectura/escritura
  initial begin
    // Limpio la interfaz
    sdram_if.chipselect   = 0;
    sdram_if.read_n       = 1;
    sdram_if.write_n      = 1;
    sdram_if.address      = '0;
    sdram_if.byteenable_n = ~'0;

    // Espero a salir de reset
    @(posedge clk_clk);
    wait (reset_reset_n);

    // Lectura en 0x000100
    sdram_if.read(25'h000100, rdata);
    $display("Dato leído de 0x000100 = %h", rdata);

    // Escritura en 0x000100
    sdram_if.write(25'h000100, 16'hABCD);
    $display("Escrito 0xABCD en 0x000100");

    #100 $finish;
  end

endmodule
