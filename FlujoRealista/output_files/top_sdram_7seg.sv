`timescale 1ns/1ps

module top_sdram_7seg (
  input  logic        clk_clk,
  input  logic        reset_reset_n,

  // Conduit SDRAM
  output logic [12:0] wire_addr,
  output logic [1:0]  wire_ba,
  output logic        wire_cas_n,
  output logic        wire_cke,
  output logic        wire_cs_n,
  inout  logic [15:0] wire_dq,
  output logic [1:0]  wire_dqm,
  output logic        wire_ras_n,
  output logic        wire_we_n,

  // Display 7-segmentos (cátodo común)
  output logic        seg_a,
  output logic        seg_b,
  output logic        seg_c,
  output logic        seg_d,
  output logic        seg_e,
  output logic        seg_f,
  output logic        seg_g,
  output logic        digit_sel  // habilita el dígito (0=on)
);

  //------------------------------------------------------------------------------
  // 1) Instanciamos la interfaz Avalon–MM
  //------------------------------------------------------------------------------
  avl_sdram_if sdram_if (
    .clk     (clk_clk),
    .reset_n (reset_reset_n)
  );

  //------------------------------------------------------------------------------
  // 2) Instanciamos el controlador SDRAM
  //------------------------------------------------------------------------------
  sdram dut (
    .clk_clk             (clk_clk),
    .reset_reset_n       (reset_reset_n),
    .sdram_address       (sdram_if.address),
    .sdram_byteenable_n  (sdram_if.byteenable_n),
    .sdram_chipselect    (sdram_if.chipselect),
    .sdram_read_n        (sdram_if.read_n),
    .sdram_write_n       (sdram_if.write_n),
    .sdram_writedata     (sdram_if.writedata),
    .sdram_readdata      (sdram_if.readdata),
    .sdram_readdatavalid (sdram_if.readdatavalid),
    .sdram_waitrequest   (sdram_if.waitrequest),
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

  //------------------------------------------------------------------------------
  // 3) FSM: Escritura, Lectura y Display
  //------------------------------------------------------------------------------
  typedef enum logic [1:0] {IDLE, WRITE, READ, DISPLAY} state_t;
  state_t            state;
  logic [3:0]        digit;
  logic [15:0]       mem_data;
  logic [6:0]        segs;

  // Decodificación de segmentos (a-g)
  always_comb begin
    case (digit)
      4'd0: segs = 7'b0000001;
      4'd1: segs = 7'b1001111;
      4'd2: segs = 7'b0010010;
      4'd3: segs = 7'b0000110;
      4'd4: segs = 7'b1001100;
      4'd5: segs = 7'b0100100;
      4'd6: segs = 7'b0100000;
      4'd7: segs = 7'b0001111;
      4'd8: segs = 7'b0000000;
      4'd9: segs = 7'b0000100;
      default: segs = 7'b1111111;
    endcase
  end

  // Asignación a salidas 7-seg (cátodo común activo en 0)
  assign {seg_a,seg_b,seg_c,seg_d,seg_e,seg_f,seg_g} = segs;
  assign digit_sel = 1'b0;

  // FSM secuencial
  always_ff @(posedge clk_clk or negedge reset_reset_n) begin
    if (!reset_reset_n) begin
      state <= IDLE;
      digit <= 4'd0;
    end else begin
      case (state)
        IDLE: begin
          digit <= 4'd7;        // Número a mostrar
          state <= WRITE;
        end

        WRITE: begin
          sdram_if.write(25'h000100, {12'd0, digit});
          state <= READ;
        end

        READ: begin
          sdram_if.read(25'h000100, mem_data);
          digit <= mem_data[3:0];
          state <= DISPLAY;
        end

        DISPLAY: begin
          state <= DISPLAY;
        end

        default: state <= IDLE;
      endcase
    end
  end

endmodule
