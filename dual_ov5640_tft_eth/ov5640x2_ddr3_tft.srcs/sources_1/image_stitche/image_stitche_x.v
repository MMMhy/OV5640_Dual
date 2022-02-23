/////////////////////////////////////////////////////////////////////////////////
// Module Name   : image_stitche_x
// Description   : 输入的两张图片左右拼接后输出，
// 设置输入的两张图片尺寸需与设置拼接后输出图片尺寸满足如下要求：
// 输入图片1的宽度 + 输入图片2的宽度 == 输出图片的宽度;
// 输入图片1的高度 == 输入图片2的高度 == 输出图片的高度;
// 不满足要求的做错误参数设置处理，以输出设置尺寸输出一张纯白色图片
/////////////////////////////////////////////////////////////////////////////////

module image_stitche_x
#(
  parameter DATA_WIDTH        = 16,  //16 or 24
  //image1_in: 400*480
  parameter IMAGE1_WIDTH_IN   = 400,
  parameter IMAGE1_HEIGHT_IN  = 480,
  //image2_in: 400*480
  parameter IMAGE2_WIDTH_IN   = 400,
  parameter IMAGE2_HEIGHT_IN  = 480,
  //image_out: 800*480
  parameter IMAGE_WIDTH_OUT   = 800,
  parameter IMAGE_HEIGHT_OUT  = 480
)
(
  input                      clk_image1_in      ,
  input                      clk_image2_in      ,
  input                      clk_image_out      ,
  input                      reset_p            ,

  output                     rst_busy_o         ,
  output                     image_in_ready_o   ,

  input     [DATA_WIDTH-1:0] image1_data_pixel_i,
  input                      image1_data_valid_i,

  input     [DATA_WIDTH-1:0] image2_data_pixel_i,
  input                      image2_data_valid_i,

  input                      data_out_ready_i   ,
  output reg[DATA_WIDTH-1:0] data_pixel_o       ,
  output reg                 data_valid_o       
);

localparam S_IDLE    = 4'b0001,
           S_ARB     = 4'b0010,
           S_RD_IMG1 = 4'b0100,
           S_RD_IMG2 = 4'b1000;

  wire                image1_buf_rden;
  reg                 image1_buf_rden_dly1;
  wire[DATA_WIDTH-1:0]image1_buf_dout;
  wire                image1_buf_alfull;
  wire                image1_buf_empty;
  wire                image1_buf_wr_rst_busy;
  wire                image1_buf_rd_rst_busy;

  wire                image2_buf_rden;
  reg                 image2_buf_rden_dly1;
  wire[DATA_WIDTH-1:0]image2_buf_dout;
  wire                image2_buf_alfull;
  wire                image2_buf_empty;
  wire                image2_buf_wr_rst_busy;
  wire                image2_buf_rd_rst_busy;

  reg                 rd_image_sel;//0:image1,1:image2
  reg [11:0]          rd_data_cnt;

  reg [3:0]           curr_state;
  reg [3:0]           next_state;

  assign rst_busy_o = image1_buf_wr_rst_busy | image1_buf_rd_rst_busy | image2_buf_wr_rst_busy | image2_buf_rd_rst_busy;
  assign image_in_ready_o = (~image1_buf_alfull) && (~image2_buf_alfull) && (~rst_busy_o);

generate
  if ((IMAGE1_WIDTH_IN + IMAGE2_WIDTH_IN != IMAGE_WIDTH_OUT) || (IMAGE1_HEIGHT_IN != IMAGE_HEIGHT_OUT) || (IMAGE2_HEIGHT_IN != IMAGE_HEIGHT_OUT)) 
  begin: error_set_pro   //错误设置输入/输出图片参数情况的处理
//---------------------------------------------------------
    always@(posedge clk_image_out or posedge reset_p)
    begin
      if(reset_p)
        data_pixel_o <= 'd0;
      else
        data_pixel_o <= {DATA_WIDTH{1'b1}};
    end

    always@(posedge clk_image_out or posedge reset_p)
    begin
      if(reset_p)
        data_valid_o <= 'd0;
      else
        data_valid_o <= 1'b1;
    end
//---------------------------------------------------------
  end
  else
  begin: correct_set_pro   //正确设置输入/输出图片参数情况的处理
//---------------------------------------------------------
    image_buffer image1_buffer (
      .rst           (reset_p                ), // input wire rst
      .wr_clk        (clk_image1_in          ), // input wire wr_clk
      .rd_clk        (clk_image_out          ), // input wire rd_clk
      .din           (image1_data_pixel_i    ), // input wire [15 : 0] din
      .wr_en         (image1_data_valid_i    ), // input wire wr_en
      .rd_en         (image1_buf_rden        ), // input wire rd_en
      .dout          (image1_buf_dout        ), // output wire [15 : 0] dout
      .almost_full   (image1_buf_alfull      ),  // output wire almost_full
      .full          (                       ), // output wire full
      .empty         (image1_buf_empty       ), // output wire empty
      .wr_rst_busy   (image1_buf_wr_rst_busy ), // output wire wr_rst_busy
      .rd_rst_busy   (image1_buf_rd_rst_busy )  // output wire rd_rst_busy
    );

    image_buffer image2_buffer (
      .rst           (reset_p                ), // input wire rst
      .wr_clk        (clk_image2_in          ), // input wire wr_clk
      .rd_clk        (clk_image_out          ), // input wire rd_clk
      .din           (image2_data_pixel_i    ), // input wire [15 : 0] din
      .wr_en         (image2_data_valid_i    ), // input wire wr_en
      .rd_en         (image2_buf_rden        ), // input wire rd_en
      .dout          (image2_buf_dout        ), // output wire [15 : 0] dout
      .almost_full   (image2_buf_alfull      ),  // output wire almost_full
      .full          (                       ), // output wire full
      .empty         (image2_buf_empty       ), // output wire empty
      .wr_rst_busy   (image2_buf_wr_rst_busy ), // output wire wr_rst_busy
      .rd_rst_busy   (image2_buf_rd_rst_busy )  // output wire rd_rst_busy
    );

    always@(posedge clk_image_out or posedge reset_p)
    begin
      if(reset_p)
        data_valid_o <= 1'b0;
      else if(image1_buf_rden_dly1 | image2_buf_rden_dly1)
        data_valid_o <= 1'b1;
      else
        data_valid_o <= 1'b0;
    end

    always@(posedge clk_image_out or posedge reset_p)
    begin
      if(reset_p)
        data_pixel_o <= 'd0;
      else if(image1_buf_rden_dly1)
        data_pixel_o <= image1_buf_dout;
      else if(image2_buf_rden_dly1)
        data_pixel_o <= image2_buf_dout;
      else
        data_pixel_o <= 'd0;
    end

    assign image1_buf_rden = (curr_state == S_RD_IMG1) & (image1_buf_empty == 1'b0) & (data_out_ready_i == 1'b0);
    assign image2_buf_rden = (curr_state == S_RD_IMG2) & (image2_buf_empty == 1'b0) & (data_out_ready_i == 1'b0);

    always@(posedge clk_image_out or posedge reset_p)
    begin
      if(reset_p)
      begin
        image1_buf_rden_dly1 <= 1'b0;
        image2_buf_rden_dly1 <= 1'b0;
      end
      else
      begin
        image1_buf_rden_dly1 <= image1_buf_rden;
        image2_buf_rden_dly1 <= image2_buf_rden;
      end
    end

    //rd_data_cnt
    always@(posedge clk_image_out or posedge reset_p)
    begin
      if(reset_p)
        rd_data_cnt <= 'd0;
      else if(curr_state == S_RD_IMG1)
      begin
        if(image1_buf_rden == 1'b1)
          rd_data_cnt <= rd_data_cnt + 1'b1;
        else
          rd_data_cnt <= rd_data_cnt;
      end
      else if(curr_state == S_RD_IMG2)
      begin
        if(image2_buf_rden == 1'b1)
          rd_data_cnt <= rd_data_cnt + 1'b1;
        else
          rd_data_cnt <= rd_data_cnt;
      end
      else
        rd_data_cnt <= 'd0;
    end

    //rd_image_sel
    always@(posedge clk_image_out or posedge reset_p)
    begin
      if(reset_p)
        rd_image_sel <= 1'b0;
      else if((curr_state == S_RD_IMG1) && (rd_data_cnt == IMAGE1_WIDTH_IN - 1'b1))
        rd_image_sel <= 1'b1;
      else if((curr_state == S_RD_IMG2) && (rd_data_cnt == IMAGE2_WIDTH_IN - 1'b1))
        rd_image_sel <= 1'b0;
      else
        rd_image_sel <= rd_image_sel;
    end

    //*********************************
    //State Machine
    //*********************************
    always@(posedge clk_image_out or posedge reset_p)
    begin
      if(reset_p)
        curr_state <= S_IDLE;
      else
        curr_state <= next_state;
    end

    always@(*)
    begin
      case(curr_state)
        S_IDLE:
        begin
          if(rst_busy_o == 1'b0)
            next_state = S_ARB;
          else
            next_state = S_IDLE;
        end

        S_ARB:
        begin
          if((rd_image_sel == 1'b0) && (image1_buf_empty == 1'b0))
            next_state = S_RD_IMG1;
          else if((rd_image_sel == 1'b1) && (image2_buf_empty == 1'b0))
            next_state = S_RD_IMG2;
          else
            next_state = S_ARB;
        end

        S_RD_IMG1:
        begin
          if(image1_buf_rden && (rd_data_cnt == IMAGE1_WIDTH_IN - 1'b1))
            next_state = S_ARB;
          else
            next_state = S_RD_IMG1;
        end

        S_RD_IMG2:
        begin
          if(image2_buf_rden && (rd_data_cnt == IMAGE2_WIDTH_IN - 1'b1))
            next_state = S_ARB;
          else
            next_state = S_RD_IMG2;
        end

        default: next_state = S_IDLE;
      endcase
    end
//---------------------------------------------------------
  end
endgenerate

endmodule 