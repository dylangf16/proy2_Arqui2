`timescale 1ns/1ps

interface avl_sdram_if
  #( parameter ADDR_WIDTH  = 25,
     parameter DATA_WIDTH  = 16,
     parameter BE_WIDTH    = DATA_WIDTH/8 )
  ( input  logic              clk,
    input  logic              reset_n );

  // Señales Avalon–MM Master → Slave
  logic [ADDR_WIDTH-1:0]      address;
  logic [BE_WIDTH-1:0]        byteenable_n;
  logic                       chipselect;
  logic                       read_n;
  logic                       write_n;
  logic [DATA_WIDTH-1:0]      writedata;

  // Señales Slave → Master
  logic [DATA_WIDTH-1:0]      readdata;
  logic                       readdatavalid;
  logic                       waitrequest;

  // Escritura con bucle acotado (usando solo asignaciones blocking)
  task automatic write(
    input  logic [ADDR_WIDTH-1:0]  addr,
    input  logic [DATA_WIDTH-1:0]  data
  );
    integer i;
    // Inicio de la transferencia
    @(posedge clk);
    address      = addr;
    byteenable_n = '0;        // habilita todos los bytes
    chipselect   = 1;
    writedata    = data;
    write_n      = 0;
    read_n       = 1;

    @(posedge clk);
    write_n      = 1;

    // Espera bounded-handshake (hasta 128 ciclos) usando bloque for
    write_wait_loop: for (i = 0; i < 128; i = i + 1) begin
      @(posedge clk);
      if (!waitrequest) disable write_wait_loop;
    end

    chipselect = 0;
  endtask

  // Lectura con bucle acotado (asignaciones blocking)
  task automatic read(
    input  logic [ADDR_WIDTH-1:0]  addr,
    output logic [DATA_WIDTH-1:0]  data
  );
    integer i;
    // Inicio de la transferencia
    @(posedge clk);
    address      = addr;
    byteenable_n = '0;
    chipselect   = 1;
    read_n       = 0;
    write_n      = 1;

    @(posedge clk);
    read_n       = 1;

    // Espera bounded-handshake (hasta 128 ciclos)
    read_wait_loop: for (i = 0; i < 128; i = i + 1) begin
      @(posedge clk);
      if (readdatavalid) disable read_wait_loop;
    end

    data = readdata;
    chipselect = 0;
  endtask

  // Modport para señales de master
  modport master (
    input  readdata,
    input  readdatavalid,
    input  waitrequest,
    output address,
    output byteenable_n,
    output chipselect,
    output read_n,
    output write_n,
    output writedata
  );

endinterface
