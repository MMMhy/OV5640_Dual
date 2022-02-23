/////////////////////////////////////////////////////////////////////////////////
// Module Name   : ddr3_ctrl_2port
// Description   : DDR3��������װ
/////////////////////////////////////////////////////////////////////////////////


module ddr3_ctrl_2port #(
  parameter WR_DDR_ADDR_BEGIN = 0,
  parameter WR_DDR_ADDR_END   = 1024,
  parameter RD_DDR_ADDR_BEGIN = 0,
  parameter RD_DDR_ADDR_END   = 1024
)
(
  //clock reset
  input           ddr3_clk200m  ,
  input           ddr3_rst_n    ,
  output          ddr3_init_done,
  //wr_fifo Interface
  input           wrfifo_clr    ,
  input           wrfifo_clk    ,
  input           wrfifo_wren   ,
  input  [15:0]   wrfifo_din    ,
  output          wrfifo_full   ,
  output [8:0]    wrfifo_wr_cnt ,
  //rd_fifo Interface
  input           rdfifo_clr    ,
  input           rdfifo_clk    ,
  input           rdfifo_rden   ,
  output [15:0]   rdfifo_dout   ,
  output          rdfifo_empty  ,
  output [8:0]    rdfifo_rd_cnt ,
  //DDR3 Interface
  // Inouts
  inout  [15:0]   ddr3_dq       ,
  inout  [1:0]    ddr3_dqs_n    ,
  inout  [1:0]    ddr3_dqs_p    ,
  // Outputs      
  output [13:0]   ddr3_addr     ,
  output [2:0]    ddr3_ba       ,
  output          ddr3_ras_n    ,
  output          ddr3_cas_n    ,
  output          ddr3_we_n     ,
  output          ddr3_reset_n  ,
  output [0:0]    ddr3_ck_p     ,
  output [0:0]    ddr3_ck_n     ,
  output [0:0]    ddr3_cke      ,
  output [0:0]    ddr3_cs_n     ,
  output [1:0]    ddr3_dm       ,
  output [0:0]    ddr3_odt      
);

  wire          wrfifo_rden;
  wire [127:0]  wrfifo_dout;
  wire [5 : 0]  wrfifo_rd_cnt;
  wire          wrfifo_empty;
  wire          wrfifo_wr_rst_busy;
  wire          wrfifo_rd_rst_busy;

  wire          rdfifo_wren;
  wire [127:0]  rdfifo_din;
  wire [5 : 0]  rdfifo_wr_cnt;
  wire          rdfifo_full;
  wire          rdfifo_wr_rst_busy;
  wire          rdfifo_rd_rst_busy;

  wire          ui_clk;
  wire          ui_clk_sync_rst;
  wire          mmcm_locked;
  wire          init_calib_complete;
  reg           wrfifo_clr_sync_ui_clk;
  reg           wr_addr_clr;
  reg           rdfifo_clr_sync_ui_clk;
  reg           rd_addr_clr;

  wire [3:0]    s_axi_awid;
  wire [27:0]   s_axi_awaddr;
  wire [7:0]    s_axi_awlen;
  wire [2:0]    s_axi_awsize;
  wire [1:0]    s_axi_awburst;
  wire [0:0]    s_axi_awlock;
  wire [3:0]    s_axi_awcache;
  wire [2:0]    s_axi_awprot;
  wire [3:0]    s_axi_awqos;
  wire          s_axi_awvalid;
  wire          s_axi_awready;

  wire [127:0]  s_axi_wdata;
  wire [15:0]   s_axi_wstrb;
  wire          s_axi_wlast;
  wire          s_axi_wvalid;
  wire          s_axi_wready;

  wire [3:0]    s_axi_bid;
  wire [1:0]    s_axi_bresp;
  wire          s_axi_bvalid;
  wire          s_axi_bready;

  wire [3:0]    s_axi_arid;
  wire [27:0]   s_axi_araddr;
  wire [7:0]    s_axi_arlen;
  wire [2:0]    s_axi_arsize;
  wire [1:0]    s_axi_arburst;
  wire [0:0]    s_axi_arlock;
  wire [3:0]    s_axi_arcache;
  wire [2:0]    s_axi_arprot;
  wire [3:0]    s_axi_arqos;
  wire          s_axi_arvalid;
  wire          s_axi_arready;

  wire [3:0]    s_axi_rid;
  wire [127:0]  s_axi_rdata;
  wire [1:0]    s_axi_rresp;
  wire          s_axi_rlast;
  wire          s_axi_rvalid;
  wire          s_axi_rready;

  assign ddr3_init_done = mmcm_locked && init_calib_complete;

  wr_ddr3_fifo wr_ddr3_fifo
  (
    .rst           (wrfifo_clr         ), // input  wire rst
    .wr_clk        (wrfifo_clk         ), // input  wire wr_clk
    .rd_clk        (ui_clk             ), // input  wire rd_clk
    .din           (wrfifo_din         ), // input  wire [15 : 0] din
    .wr_en         (wrfifo_wren        ), // input  wire wr_en
    .rd_en         (wrfifo_rden        ), // input  wire rd_en
    .dout          (wrfifo_dout        ), // output wire [127 : 0] dout
    .full          (wrfifo_full        ), // output wire full
    .empty         (wrfifo_empty       ), // output wire empty
    .rd_data_count (wrfifo_rd_cnt      ), // output wire [5 : 0] rd_data_count
    .wr_data_count (wrfifo_wr_cnt      ), // output wire [8 : 0] wr_data_count
    .wr_rst_busy   (wrfifo_wr_rst_busy ), // output wire wr_rst_busy
    .rd_rst_busy   (wrfifo_rd_rst_busy )  // output wire rd_rst_busy
  );

  rd_ddr3_fifo rd_ddr3_fifo
  (
    .rst           (rdfifo_clr         ), // input wire rst
    .wr_clk        (ui_clk             ), // input wire wr_clk
    .rd_clk        (rdfifo_clk         ), // input wire rd_clk
    .din           (rdfifo_din         ), // input wire [127 : 0] din
    .wr_en         (rdfifo_wren        ), // input wire wr_en
    .rd_en         (rdfifo_rden        ), // input wire rd_en
    .dout          (rdfifo_dout        ), // output wire [15 : 0] dout
    .full          (rdfifo_full        ), // output wire full
    .empty         (rdfifo_empty       ), // output wire empty
    .rd_data_count (rdfifo_rd_cnt      ), // output wire [8 : 0] rd_data_count
    .wr_data_count (rdfifo_wr_cnt      ), // output wire [5 : 0] wr_data_count
    .wr_rst_busy   (rdfifo_wr_rst_busy ), // output wire wr_rst_busy
    .rd_rst_busy   (rdfifo_rd_rst_busy )  // output wire rd_rst_busy
  );

  always@(posedge ui_clk)
  begin
    wrfifo_clr_sync_ui_clk <= wrfifo_clr;
    wr_addr_clr <= wrfifo_clr_sync_ui_clk;
  end

  always@(posedge ui_clk)
  begin
    rdfifo_clr_sync_ui_clk <= rdfifo_clr;
    rd_addr_clr <= rdfifo_clr_sync_ui_clk;
  end

  fifo2mig_axi
  #(
    .WR_DDR_ADDR_BEGIN (WR_DDR_ADDR_BEGIN ),
    .WR_DDR_ADDR_END   (WR_DDR_ADDR_END   ),
    .RD_DDR_ADDR_BEGIN (RD_DDR_ADDR_BEGIN ),
    .RD_DDR_ADDR_END   (RD_DDR_ADDR_END   ),

    .AXI_ID            (4'b0000           ),
    .AXI_LEN           (8'd31             )  //axi burst length = 32
  )fifo2mig_axi
  (
    //FIFO Interface ports
    .wr_addr_clr         (wr_addr_clr         ), //1:clear sync ui_clk
    .wr_fifo_rdreq       (wrfifo_rden         ),
    .wr_fifo_rddata      (wrfifo_dout         ),
    .wr_fifo_empty       (wrfifo_empty        ),
    .wr_fifo_rd_cnt      (wrfifo_rd_cnt       ),
    .wr_fifo_rst_busy    (wrfifo_wr_rst_busy | wrfifo_rd_rst_busy),

    .rd_addr_clr         (rd_addr_clr         ), //1:clear sync ui_clk
    .rd_fifo_wrreq       (rdfifo_wren         ),
    .rd_fifo_wrdata      (rdfifo_din          ),
    .rd_fifo_alfull      (rdfifo_full         ),
    .rd_fifo_wr_cnt      (rdfifo_wr_cnt       ),
    .rd_fifo_rst_busy    (rdfifo_wr_rst_busy | rdfifo_rd_rst_busy),
    // Application interface ports
    .ui_clk              (ui_clk              ),
    .ui_clk_sync_rst     (ui_clk_sync_rst     ),
    .mmcm_locked         (mmcm_locked         ),
    .init_calib_complete (init_calib_complete ),
    // Slave Interface Write Address Ports
    .m_axi_awid          (s_axi_awid          ),
    .m_axi_awaddr        (s_axi_awaddr        ),
    .m_axi_awlen         (s_axi_awlen         ),
    .m_axi_awsize        (s_axi_awsize        ),
    .m_axi_awburst       (s_axi_awburst       ),
    .m_axi_awlock        (s_axi_awlock        ),
    .m_axi_awcache       (s_axi_awcache       ),
    .m_axi_awprot        (s_axi_awprot        ),
    .m_axi_awqos         (s_axi_awqos         ),
    .m_axi_awvalid       (s_axi_awvalid       ),
    .m_axi_awready       (s_axi_awready       ),
    // Slave Interface Write Data Ports
    .m_axi_wdata         (s_axi_wdata         ),
    .m_axi_wstrb         (s_axi_wstrb         ),
    .m_axi_wlast         (s_axi_wlast         ),
    .m_axi_wvalid        (s_axi_wvalid        ),
    .m_axi_wready        (s_axi_wready        ),
    // Slave Interface Write Response Ports
    .m_axi_bid           (s_axi_bid           ),
    .m_axi_bresp         (s_axi_bresp         ),
    .m_axi_bvalid        (s_axi_bvalid        ),
    .m_axi_bready        (s_axi_bready        ),
    // Slave Interface Read Address Ports
    .m_axi_arid          (s_axi_arid          ),
    .m_axi_araddr        (s_axi_araddr        ),
    .m_axi_arlen         (s_axi_arlen         ),
    .m_axi_arsize        (s_axi_arsize        ),
    .m_axi_arburst       (s_axi_arburst       ),
    .m_axi_arlock        (s_axi_arlock        ),
    .m_axi_arcache       (s_axi_arcache       ),
    .m_axi_arprot        (s_axi_arprot        ),
    .m_axi_arqos         (s_axi_arqos         ),
    .m_axi_arvalid       (s_axi_arvalid       ),
    .m_axi_arready       (s_axi_arready       ),
    // Slave Interface Read Data Ports
    .m_axi_rid           (s_axi_rid           ),
    .m_axi_rdata         (s_axi_rdata         ),
    .m_axi_rresp         (s_axi_rresp         ),
    .m_axi_rlast         (s_axi_rlast         ),
    .m_axi_rvalid        (s_axi_rvalid        ),
    .m_axi_rready        (s_axi_rready        )
  );

  mig_7series_0 u_mig_7series_0 (
    // Memory interface ports
    .ddr3_addr            (ddr3_addr           ),  // output [13:0]   ddr3_addr
    .ddr3_ba              (ddr3_ba             ),  // output [2:0]    ddr3_ba
    .ddr3_cas_n           (ddr3_cas_n          ),  // output          ddr3_cas_n
    .ddr3_ck_n            (ddr3_ck_n           ),  // output [0:0]    ddr3_ck_n
    .ddr3_ck_p            (ddr3_ck_p           ),  // output [0:0]    ddr3_ck_p
    .ddr3_cke             (ddr3_cke            ),  // output [0:0]    ddr3_cke
    .ddr3_ras_n           (ddr3_ras_n          ),  // output          ddr3_ras_n
    .ddr3_reset_n         (ddr3_reset_n        ),  // output          ddr3_reset_n
    .ddr3_we_n            (ddr3_we_n           ),  // output          ddr3_we_n
    .ddr3_dq              (ddr3_dq             ),  // inout [15:0]    ddr3_dq
    .ddr3_dqs_n           (ddr3_dqs_n          ),  // inout [1:0]     ddr3_dqs_n
    .ddr3_dqs_p           (ddr3_dqs_p          ),  // inout [1:0]     ddr3_dqs_p
    .init_calib_complete  (init_calib_complete ),  // output          init_calib_complete
    .ddr3_cs_n            (ddr3_cs_n           ),  // output [0:0]    ddr3_cs_n
    .ddr3_dm              (ddr3_dm             ),  // output [1:0]    ddr3_dm
    .ddr3_odt             (ddr3_odt            ),  // output [0:0]    ddr3_odt
    // Application interface ports
    .ui_clk               (ui_clk              ),  // output          ui_clk
    .ui_clk_sync_rst      (ui_clk_sync_rst     ),  // output          ui_clk_sync_rst
    .mmcm_locked          (mmcm_locked         ),  // output          mmcm_locked
    .aresetn              (ddr3_rst_n          ),  // input           aresetn
    .app_sr_req           (1'b0                ),  // input           app_sr_req
    .app_ref_req          (1'b0                ),  // input           app_ref_req
    .app_zq_req           (1'b0                ),  // input           app_zq_req
    .app_sr_active        (                    ),  // output          app_sr_active
    .app_ref_ack          (                    ),  // output          app_ref_ack
    .app_zq_ack           (                    ),  // output          app_zq_ack
    // Slave Interface Write Address Ports
    .s_axi_awid           (s_axi_awid          ),  // input [3:0]     s_axi_awid
    .s_axi_awaddr         (s_axi_awaddr        ),  // input [27:0]    s_axi_awaddr
    .s_axi_awlen          (s_axi_awlen         ),  // input [7:0]     s_axi_awlen
    .s_axi_awsize         (s_axi_awsize        ),  // input [2:0]     s_axi_awsize
    .s_axi_awburst        (s_axi_awburst       ),  // input [1:0]     s_axi_awburst
    .s_axi_awlock         (s_axi_awlock        ),  // input [0:0]     s_axi_awlock
    .s_axi_awcache        (s_axi_awcache       ),  // input [3:0]     s_axi_awcache
    .s_axi_awprot         (s_axi_awprot        ),  // input [2:0]     s_axi_awprot
    .s_axi_awqos          (s_axi_awqos         ),  // input [3:0]     s_axi_awqos
    .s_axi_awvalid        (s_axi_awvalid       ),  // input           s_axi_awvalid
    .s_axi_awready        (s_axi_awready       ),  // output          s_axi_awready
    // Slave Interface Write Data Ports
    .s_axi_wdata          (s_axi_wdata         ),  // input [127:0]   s_axi_wdata
    .s_axi_wstrb          (s_axi_wstrb         ),  // input [15:0]    s_axi_wstrb
    .s_axi_wlast          (s_axi_wlast         ),  // input           s_axi_wlast
    .s_axi_wvalid         (s_axi_wvalid        ),  // input           s_axi_wvalid
    .s_axi_wready         (s_axi_wready        ),  // output          s_axi_wready
    // Slave Interface Write Response Ports
    .s_axi_bid            (s_axi_bid           ),  // output [3:0]    s_axi_bid
    .s_axi_bresp          (s_axi_bresp         ),  // output [1:0]    s_axi_bresp
    .s_axi_bvalid         (s_axi_bvalid        ),  // output          s_axi_bvalid
    .s_axi_bready         (s_axi_bready        ),  // input           s_axi_bready
    // Slave Interface Read Address Ports
    .s_axi_arid           (s_axi_arid          ),  // input [3:0]     s_axi_arid
    .s_axi_araddr         (s_axi_araddr        ),  // input [27:0]    s_axi_araddr
    .s_axi_arlen          (s_axi_arlen         ),  // input [7:0]     s_axi_arlen
    .s_axi_arsize         (s_axi_arsize        ),  // input [2:0]     s_axi_arsize
    .s_axi_arburst        (s_axi_arburst       ),  // input [1:0]     s_axi_arburst
    .s_axi_arlock         (s_axi_arlock        ),  // input [0:0]     s_axi_arlock
    .s_axi_arcache        (s_axi_arcache       ),  // input [3:0]     s_axi_arcache
    .s_axi_arprot         (s_axi_arprot        ),  // input [2:0]     s_axi_arprot
    .s_axi_arqos          (s_axi_arqos         ),  // input [3:0]     s_axi_arqos
    .s_axi_arvalid        (s_axi_arvalid       ),  // input           s_axi_arvalid
    .s_axi_arready        (s_axi_arready       ),  // output          s_axi_arready
    // Slave Interface Read Data Ports
    .s_axi_rid            (s_axi_rid           ),  // output [3:0]    s_axi_rid
    .s_axi_rdata          (s_axi_rdata         ),  // output [127:0]  s_axi_rdata
    .s_axi_rresp          (s_axi_rresp         ),  // output [1:0]    s_axi_rresp
    .s_axi_rlast          (s_axi_rlast         ),  // output          s_axi_rlast
    .s_axi_rvalid         (s_axi_rvalid        ),  // output          s_axi_rvalid
    .s_axi_rready         (s_axi_rready        ),  // input           s_axi_rready
    // System Clock Ports
    .sys_clk_i            (ddr3_clk200m        ),
    .sys_rst              (ddr3_rst_n          )   // input sys_rst
  );

endmodule