// Module Name   : ov5640x2_ddr3_tft
// Description   : 双目摄像头采集数据，DDR3缓存，TFT显示,以太网传输

module ov5640x2_ddr3_tft(

  //System clock reset
  input           clk50m        , //系统时钟输入，50MHz
  input           reset_n       , //复位信号输入
  
  input           Ctrl_on_1     ,
  input           Ctrl_on_2     ,
  //LED
  output [3:0]    led           ,
  //eth interface
  output          gtxclk        ,
  output [7:0]    gmii_txd      ,
  output          gmii_txen     ,
  output          eth_reset_n   ,
  //TFT Interface               
  output [15:0]   TFT_rgb       , //TFT数据输出
  output          TFT_hs        , //TFT行同步信号
  output          TFT_vs        , //TFT场同步信号
  output          TFT_clk       , //TFT像素时钟
  output          TFT_de        , //TFT数据使能
  output          TFT_pwm       , //TFT背光控制
  //camera1 interface
  output          camera1_sclk  ,
  inout           camera1_sdat  ,
  input           camera1_vsync ,
  input           camera1_href  ,
  input           camera1_pclk  ,
  output          camera1_xclk  ,
  input  [7:0]    camera1_data  ,
  output          camera1_rst_n ,
  //camera2 interface
  output          camera2_sclk  ,
  inout           camera2_sdat  ,
  input           camera2_vsync ,
  input           camera2_href  ,
  input           camera2_pclk  ,
  output          camera2_xclk  ,
  input  [7:0]    camera2_data  ,
  output          camera2_rst_n ,
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

//Internal connect
  //clock
  wire          pll_locked;
  wire          loc_clk50m;
  wire          loc_clk200m;
  wire          loc_clk24m;
  wire          loc_clk33m;
  wire          loc_clk9m;
  wire          loc_clk125m;
  //reset
  wire          g_rst_p;
  //camera1 interface
  wire          camera1_init_done;
  wire          pclk1_bufg_o;
  wire [15:0]   image1_data;
  wire          image1_data_valid;
  wire          image1_data_hs;
  wire          image1_data_vs;
  //camera2 interface
  wire          camera2_init_done;
  wire          pclk2_bufg_o;
  wire [15:0]   image2_data;
  wire          image2_data_valid;
  wire          image2_data_hs;
  wire          image2_data_vs;
  //wr_fifo Interface
  wire          wrfifo_clr;
  wire          wrfifo_wren;
  wire [15:0]   wrfifo_din;
  wire          wrfifo_full;
  //rd_fifo Interface
  wire          rdfifo_clr;
  wire          rdfifo_rden;
  wire [15 :0]  rdfifo_dout;
  //mig Interface 
  wire          ddr3_rst_n;
  wire          ddr3_init_done;
  //tft
  wire          clk_disp;
  wire          frame_begin;
  
  wire          tx_en_pulse;
  wire          tx_done;
  wire          fifo_rd;
  wire [7:0]    fifo_dout;
  
  reg           pixel_data_valid;
  reg  [15:0]   pixel_data;
  reg  [11:0]   pixel_data_hcnt;
  reg  [11:0]   pixel_data_vcnt;
  //Set IMAGE Size  
  parameter IMAGE_WIDTH  = 1280;
  parameter IMAGE_HEIGHT = 720;
  //Set ETH 
  parameter DST_MAC   = 48'h50_7B_9D_68_78_4F;
  parameter SRC_MAC   = 48'h00_0a_35_01_fe_c0;
  parameter DST_IP    = 32'hc0_a8_00_03;
  parameter SRC_IP    = 32'hc0_a8_00_02;
  parameter DST_PORT  = 16'd6000;
  parameter SRC_PORT  = 16'd5000;

//TFT5.0寸显示屏，分辨率800*480，像素时钟33MHz
  parameter DISP_WIDTH  = 800;
  parameter DISP_HEIGHT = 480;

  assign clk_disp = loc_clk33m;
  assign eth_reset_n = reset_n;
  assign ddr3_rst_n = pll_locked;
  assign g_rst_p    = ~ddr3_init_done;

  assign led = {camera2_init_done,camera1_init_done,ddr3_init_done,pll_locked};

  pll pll
  (
    // Clock out ports
    .clk_out1 (loc_clk50m   ), // output clk_out1
    .clk_out2 (loc_clk200m  ), // output clk_out2
    .clk_out3 (loc_clk24m   ), // output clk_out3
    .clk_out4 (loc_clk33m   ), // output clk_out4
    .clk_out5 (loc_clk9m    ), // output clk_out5
    .clk_out6 (loc_clk125m  ), // output clk_out6
    // Status and control signals
    .resetn   (reset_n      ), // input reset
    .locked   (pll_locked   ), // output locked
    // Clock in ports
    .clk_in1  (clk50m       )  // input clk_in1
  );

  assign camera1_xclk = loc_clk24m;
  assign camera2_xclk = loc_clk24m;

  camera_init
  #(
    .IMAGE_TYPE  ( 0            ),// 0: RGB; 1: JPEG
    .IMAGE_WIDTH ( DISP_WIDTH/2 ),// 图片宽度
    .IMAGE_HEIGHT( DISP_HEIGHT  ),// 图片高度
    .IMAGE_FLIP  ( 0            ),// 0: 不翻转，1: 上下翻转
    .IMAGE_MIRROR( 0            ) // 0: 不镜像，1: 左右镜像
  )camera1_init
  (
    .Clk         (loc_clk50m        ),
    .Rst_p       (g_rst_p           ),
    .Init_Done   (camera1_init_done ),
    .camera_rst_n(camera1_rst_n     ),
    .camera_pwdn (                  ),
    .i2c_sclk    (camera1_sclk      ),
    .i2c_sdat    (camera1_sdat      )
  );

  camera_init
  #(
    .IMAGE_TYPE  ( 0            ),// 0: RGB; 1: JPEG
    .IMAGE_WIDTH ( DISP_WIDTH/2 ),// 图片宽度
    .IMAGE_HEIGHT( DISP_HEIGHT  ),// 图片高度
    .IMAGE_FLIP  ( 0            ),// 0: 不翻转，1: 上下翻转
    .IMAGE_MIRROR( 0            ) // 0: 不镜像，1: 左右镜像
  )camera2_init
  (
    .Clk         (loc_clk50m        ),
    .Rst_p       (g_rst_p           ),
    .Init_Done   (camera2_init_done ),
    .camera_rst_n(camera2_rst_n     ),
    .camera_pwdn (                  ),
    .i2c_sclk    (camera2_sclk      ),
    .i2c_sdat    (camera2_sdat      )
  );

  BUFG BUFG_inst1 (
    .O(pclk1_bufg_o ), // 1-bit output: Clock output
    .I(camera1_pclk )  // 1-bit input: Clock input
  );

  DVP_Capture DVP_Capture_inst1(
    .Rst_p      (g_rst_p           ),//input
    .PCLK       (pclk1_bufg_o      ),//input
    .Vsync      (camera1_vsync     ),//input
    .Href       (camera1_href      ),//input
    .Data       (camera1_data      ),//input     [7:0]
    .Ctrl_on    (Ctrl_on_1         ),//input 开关1

    .ImageState (                  ),//output reg
    .DataValid  (image1_data_valid ),//output
    .DataPixel  (image1_data       ),//output    [15:0]
    .DataHs     (image1_data_hs    ),//output
    .DataVs     (image1_data_vs    ),//output
    .Xaddr      (                  ),//output    [11:0]
    .Yaddr      (                  ) //output    [11:0]
  );

  BUFG BUFG_inst2 (
    .O(pclk2_bufg_o ), // 1-bit output: Clock output
    .I(camera2_pclk )  // 1-bit input: Clock input
  );

  DVP_Capture DVP_Capture_inst2(
    .Rst_p      (g_rst_p           ),//input
    .PCLK       (pclk2_bufg_o      ),//input
    .Vsync      (camera2_vsync     ),//input
    .Href       (camera2_href      ),//input
    .Data       (camera2_data      ),//input     [7:0]
    .Ctrl_on    (Ctrl_on_2         ),//input 开关2

    .ImageState (                  ),//output reg
    .DataValid  (image2_data_valid ),//output
    .DataPixel  (image2_data       ),//output    [15:0]
    .DataHs     (image2_data_hs    ),//output
    .DataVs     (image2_data_vs    ),//output
    .Xaddr      (                  ),//output    [11:0]
    .Yaddr      (                  ) //output    [11:0]
  );

  wire [15:0]image_stitche_data;
  wire       image_stitche_data_valid;

  image_stitche_x
  #(
    .DATA_WIDTH        ( 16           ),  //16 or 24
    //image1_in: 400*480
    .IMAGE1_WIDTH_IN   ( DISP_WIDTH/2 ),
    .IMAGE1_HEIGHT_IN  ( DISP_HEIGHT  ),
    //image2_in: 400*480
    .IMAGE2_WIDTH_IN   ( DISP_WIDTH/2 ),
    .IMAGE2_HEIGHT_IN  ( DISP_HEIGHT  ),
    //image_out: 800*480
    .IMAGE_WIDTH_OUT   ( DISP_WIDTH   ),
    .IMAGE_HEIGHT_OUT  ( DISP_HEIGHT  )
  )image_stitche_x
  (
    .clk_image1_in      (pclk1_bufg_o      ),
    .clk_image2_in      (pclk2_bufg_o      ),
    .clk_image_out      (pclk2_bufg_o      ),
    .reset_p            (g_rst_p           ),

    .rst_busy_o         (                  ),
    .image_in_ready_o   (                  ),

    .image1_data_pixel_i(image1_data       ),
    .image1_data_valid_i(image1_data_valid ),

    .image2_data_pixel_i(image2_data       ),
    .image2_data_valid_i(image2_data_valid ),

    .data_out_ready_i   (wrfifo_full       ),
    .data_pixel_o       (image_stitche_data),
    .data_valid_o       (image_stitche_data_valid)
  );

  assign wrfifo_wren = image_stitche_data_valid;
  assign wrfifo_din = image_stitche_data;
  assign wrfifo_clr = ~camera1_init_done || (~camera2_init_done);
  assign rdfifo_clr = frame_begin;

  disp_driver disp_driver
  (
    .ClkDisp     (clk_disp       ),
    .Rst_p       (g_rst_p        ),

    .Data        (rdfifo_dout    ),
    .DataReq     (rdfifo_rden    ),

    .H_Addr      (               ),
    .V_Addr      (               ),

    .Disp_HS     (TFT_hs         ),
    .Disp_VS     (TFT_vs         ),
    .Disp_Red    (TFT_rgb[15:11] ),
    .Disp_Green  (TFT_rgb[10:5]  ),
    .Disp_Blue   (TFT_rgb[4:0]   ),
    .Frame_Begin (frame_begin    ),
    .Disp_DE     (TFT_de         ),
    .Disp_PCLK   (TFT_clk        )
  );

  assign TFT_pwm = 1'b1;

  ddr3_ctrl_2port #(
    .WR_DDR_ADDR_BEGIN (0   ),
    .WR_DDR_ADDR_END   (DISP_WIDTH*DISP_HEIGHT*2),
    .RD_DDR_ADDR_BEGIN (0   ),
    .RD_DDR_ADDR_END   (DISP_WIDTH*DISP_HEIGHT*2)
  )
  ddr3_ctrl_2port(
    //clock reset
    .ddr3_clk200m  (loc_clk200m   ),
    .ddr3_rst_n    (ddr3_rst_n    ),
    .ddr3_init_done(ddr3_init_done),
    //wr_fifo Interface
    .wrfifo_clr    (wrfifo_clr    ),
    .wrfifo_clk    (pclk2_bufg_o  ),
    .wrfifo_wren   (wrfifo_wren   ),
    .wrfifo_din    (wrfifo_din    ),
    .wrfifo_full   (wrfifo_full   ),
    .wrfifo_wr_cnt (              ),
    //rd_fifo Interface
    .rdfifo_clr    (rdfifo_clr    ),
    .rdfifo_clk    (clk_disp      ),
    .rdfifo_rden   (rdfifo_rden   ),
    .rdfifo_dout   (rdfifo_dout   ),
    .rdfifo_empty  (              ),
    .rdfifo_rd_cnt (              ),
    //DDR3 Interface
    // Inouts
    .ddr3_dq       (ddr3_dq       ),
    .ddr3_dqs_n    (ddr3_dqs_n    ),
    .ddr3_dqs_p    (ddr3_dqs_p    ),
    // Outputs      
    .ddr3_addr     (ddr3_addr     ),
    .ddr3_ba       (ddr3_ba       ),
    .ddr3_ras_n    (ddr3_ras_n    ),
    .ddr3_cas_n    (ddr3_cas_n    ),
    .ddr3_we_n     (ddr3_we_n     ),
    .ddr3_reset_n  (ddr3_reset_n  ),
    .ddr3_ck_p     (ddr3_ck_p     ),
    .ddr3_ck_n     (ddr3_ck_n     ),
    .ddr3_cke      (ddr3_cke      ),
    .ddr3_cs_n     (ddr3_cs_n     ),
    .ddr3_dm       (ddr3_dm       ),
    .ddr3_odt      (ddr3_odt      )
  );
  
  //对摄像头采集数据每行加上行号，2byte
  reg [15:0]image_stitche_data_dly1;
  reg       image_stitche_data_valid_dly1;

  always@(posedge loc_clk125m)
  begin
    image_stitche_data_dly1 <= image_stitche_data;
    image_stitche_data_valid_dly1 <= image_stitche_data_valid;
  end

  always@(posedge loc_clk125m or posedge g_rst_p)
  if(g_rst_p)
    pixel_data_hcnt <= 0;
  else if(image_stitche_data_valid)
    if(pixel_data_hcnt == IMAGE_WIDTH - 1'b1)
      pixel_data_hcnt <= 0;
    else
      pixel_data_hcnt <= pixel_data_hcnt + 1'b1;
  else
    pixel_data_hcnt <= pixel_data_hcnt;

  always@(posedge loc_clk125m or posedge g_rst_p)
  if(g_rst_p)
    pixel_data_vcnt <= 0;
  else if(image_stitche_data_valid)
    if((pixel_data_hcnt == IMAGE_WIDTH - 1'b1) && 
       (pixel_data_vcnt == IMAGE_HEIGHT - 1'b1))
      pixel_data_vcnt <= 0;
    else if(pixel_data_hcnt == IMAGE_WIDTH - 1'b1)
      pixel_data_vcnt <= pixel_data_vcnt + 1'b1;
    else
      pixel_data_vcnt <= pixel_data_vcnt;
  else
    pixel_data_vcnt <= pixel_data_vcnt;

  always@(posedge loc_clk125m or posedge g_rst_p)
  if(g_rst_p)
    pixel_data <= 0;
  else if(image_stitche_data_valid && (pixel_data_hcnt == 0))
    pixel_data <= pixel_data_vcnt;    //add_row_num
  else if(image_stitche_data_valid_dly1)
    pixel_data <= image_stitche_data_dly1;

  always@(posedge loc_clk125m or posedge g_rst_p)
  if(g_rst_p)
    pixel_data_valid <= 0;
  else if(image_stitche_data_valid && (pixel_data_hcnt == 0))
    pixel_data_valid <= 1;
  else if(image_stitche_data_valid_dly1)
    pixel_data_valid <= 1;
  else
    pixel_data_valid <= 0;
    eth_tx_ctrl
  #(
    .PAYLOAD_DATA_BYTE (2              ),
    .PAYLOAD_LENGTH    (IMAGE_WIDTH +1 )
  )eth_tx_ctrl_inst
  (
    .reset_p          (g_rst_p          ),

    .clk              (loc_clk125m      ),
    .data_i           ({pixel_data[7:0],pixel_data[15:8]}),
    .data_valid_i     (pixel_data_valid),

    .eth_txfifo_rd_clk(loc_clk125m      ),
    .tx_en_pulse      (tx_en_pulse      ),
    .tx_done          (tx_done          ),
    .eth_txfifo_rden  (fifo_rd          ),
    .eth_txfifo_dout  (fifo_dout        )
  );

  //eth udp 1g
  eth_udp_tx_gmii eth_udp_tx_gmii(
    .clk125m      (loc_clk125m           ),
    .reset_p      (g_rst_p               ),

    .tx_en_pulse  (tx_en_pulse           ),
    .tx_done      (tx_done               ),
    
    .dst_mac      (DST_MAC               ),
    .src_mac      (SRC_MAC               ),  
    .dst_ip       (DST_IP                ),
    .src_ip       (SRC_IP                ),  
    .dst_port     (DST_PORT              ),
    .src_port     (SRC_PORT              ),
    
    .data_length  (IMAGE_WIDTH*2+2       ),
    
    .payload_req_o(fifo_rd               ),
    .payload_dat_i(fifo_dout             ),

    .gmii_tx_clk  (gtxclk                ),
    .gmii_txen    (gmii_txen             ),
    .gmii_txd     (gmii_txd              )
  );

endmodule