/////////////////////////////////////////////////////////////////////////////////
// Company       : 武汉芯路恒科技有限公司
//                 http://xiaomeige.taobao.com
// Web           : http://www.corecourse.cn
// 
// Create Date   : 2019/04/10 00:00:00
// Module Name   : image_stitche_x_tb
// Description   : image_stitche_x 模块仿真文件
// 
// Dependencies  : 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

`timescale 1ns/1ns
`define PERIOD_CLK_i1 40
`define PERIOD_CLK_i2 30
`define PERIOD_CLK_o  20

module image_stitche_x_tb;

  reg            clk_image1_in      ;
  reg            clk_image2_in      ;
  reg            clk_image_out      ;
  reg            reset_p            ;
  
  wire           rst_busy_o         ;

  reg     [15:0] image1_data_pixel_i;
  reg            image1_data_valid_i;
  reg     [15:0] image2_data_pixel_i;
  reg            image2_data_valid_i;

  wire    [15:0] data_pixel_o       ;
  wire           data_valid_o       ;

  initial clk_image1_in = 1'b1;
  always #(`PERIOD_CLK_i1/2) clk_image1_in = ~clk_image1_in;

  initial clk_image2_in = 1'b1;
  always #(`PERIOD_CLK_i2/2) clk_image2_in = ~clk_image2_in;

  initial clk_image_out = 1'b1;
  always #(`PERIOD_CLK_o/2) clk_image_out = ~clk_image_out;

  initial begin
    reset_p = 1'b1;
    image1_data_pixel_i = 'd0;
    image1_data_valid_i = 1'b0;
    image2_data_pixel_i = 'd0;
    image2_data_valid_i = 1'b0;
    #201;
    reset_p = 1'b0;
    #200;

    wait(rst_busy_o == 1'b0);

    image1_data_in(0  ,50);
    image1_data_in(100,50);
    image2_data_in(50 ,50);
    image2_data_in(150,50);
    #5000;
    $stop;  
  end

  task image1_data_in;
    input [15:0]data_begin; //写入起始数据，后面递增
    input [15:0]data_cnt;   //写入数据个数

    begin
      image1_data_valid_i = 1'b0;
      image1_data_pixel_i = data_begin;

      @(posedge clk_image1_in)
      #1 image1_data_valid_i = 1'b1;
      repeat(data_cnt)
      begin
        @(posedge clk_image1_in)
        #1 image1_data_pixel_i = image1_data_pixel_i + 1'b1;
      end
      image1_data_valid_i = 1'b0;

    end
  endtask

  task image2_data_in;
    input [15:0]data_begin; //写入起始数据，后面递增
    input [15:0]data_cnt;   //写入数据个数

    begin
      image2_data_valid_i = 1'b0;
      image2_data_pixel_i = data_begin;

      @(posedge clk_image2_in)
      #1 image2_data_valid_i = 1'b1;
      repeat(data_cnt)
      begin
        @(posedge clk_image2_in)
        #1 image2_data_pixel_i = image2_data_pixel_i + 1'b1;
      end
      image2_data_valid_i = 1'b0;

    end
  endtask

  image_stitche_x
  #(
    .DATA_WIDTH       (16   ),  //16 or 24
    //image1: 50*100
    .IMAGE1_WIDTH_IN  (50   ),
    .IMAGE1_HEIGHT_IN (100  ),
    //image2: 50*100
    .IMAGE2_WIDTH_IN  (50   ),
    .IMAGE2_HEIGHT_IN (100  ),
    //image_out: 100*100
    .IMAGE_WIDTH_OUT  (100  ),
    .IMAGE_HEIGHT_OUT (100  )
  )image_stitche_x_inst
  (
    .clk_image1_in      (clk_image1_in      ),
    .clk_image2_in      (clk_image2_in      ),
    .clk_image_out      (clk_image_out      ),
    .reset_p            (reset_p            ),
    
    .rst_busy_o         (rst_busy_o         ),
    .image_in_ready_o   (                   ),
    .image1_data_pixel_i(image1_data_pixel_i),
    .image1_data_valid_i(image1_data_valid_i),
    .image2_data_pixel_i(image2_data_pixel_i),
    .image2_data_valid_i(image2_data_valid_i),

    .data_out_ready_i   (1'b0               ),
    .data_pixel_o       (data_pixel_o       ),
    .data_valid_o       (data_valid_o       )
  );

endmodule