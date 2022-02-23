/////////////////////////////////////////////////////////////////////////////////
// Module Name   : camera_init
// Description   : 摄像头初始化驱动模块
/////////////////////////////////////////////////////////////////////////////////

module camera_init(
  Clk,
  Rst_p,

  Init_Done,
  camera_rst_n,
  camera_pwdn,

  i2c_sclk,
  i2c_sdat
);
  input Clk;
  input Rst_p;

  output reg Init_Done;
  output camera_rst_n;
  output camera_pwdn;

  output i2c_sclk;
  inout i2c_sdat;

  localparam device_id = 8'h78;
  localparam addr_mode = 1'b1;

  localparam RGB = 0;
  localparam JPEG = 1;

  parameter IMAGE_TYPE   = RGB;
  parameter IMAGE_WIDTH  = 640;
  parameter IMAGE_HEIGHT = 480;
  parameter IMAGE_FLIP   = 0;
  parameter IMAGE_MIRROR = 0;

  assign camera_pwdn = 0;

  wire [15:0]addr;
  reg wrreg_req;
  reg rdreg_req;
  wire [7:0] wrdata;

  wire [7:0]rddata;
  wire RW_Done;
  wire ack;

  reg [7:0]cnt;
  wire [23:0]lut;

  wire [7:0]lut_size;

  generate
  if(IMAGE_TYPE == RGB)
    begin
      assign lut_size = 252;
      case ({IMAGE_FLIP[0], IMAGE_MIRROR[0]})
        2'b00:
          begin
            ov5640_init_table_rgb camera_init_table(
              .addr (cnt ),
              .clk  (Clk ),
              .q    (lut )
            );
            defparam camera_init_table.IMAGE_WIDTH  = IMAGE_WIDTH;
            defparam camera_init_table.IMAGE_HEIGHT = IMAGE_HEIGHT;
            defparam camera_init_table.IMAGE_FLIP   = 8'h40;
            defparam camera_init_table.IMAGE_MIRROR = 4'h7;
          end
        2'b01:
          begin
            ov5640_init_table_rgb camera_init_table(
              .addr (cnt ),
              .clk  (Clk ),
              .q    (lut )
            );
            defparam camera_init_table.IMAGE_WIDTH  = IMAGE_WIDTH;
            defparam camera_init_table.IMAGE_HEIGHT = IMAGE_HEIGHT;
            defparam camera_init_table.IMAGE_FLIP   = 8'h40;
            defparam camera_init_table.IMAGE_MIRROR = 4'h0;
          end
        2'b10:
          begin
            ov5640_init_table_rgb camera_init_table(
              .addr (cnt ),
              .clk  (Clk ),
              .q    (lut )
            );
            defparam camera_init_table.IMAGE_WIDTH  = IMAGE_WIDTH;
            defparam camera_init_table.IMAGE_HEIGHT = IMAGE_HEIGHT;
            defparam camera_init_table.IMAGE_FLIP   = 8'h47;
            defparam camera_init_table.IMAGE_MIRROR = 4'h7;
          end
        2'b11:
          begin
            ov5640_init_table_rgb camera_init_table(
              .addr (cnt ),
              .clk  (Clk ),
              .q    (lut )
            );
            defparam camera_init_table.IMAGE_WIDTH  = IMAGE_WIDTH;
            defparam camera_init_table.IMAGE_HEIGHT = IMAGE_HEIGHT;
            defparam camera_init_table.IMAGE_FLIP   = 8'h47;
            defparam camera_init_table.IMAGE_MIRROR = 4'h0;
          end
      endcase
    end
  else //IMAGE_TYPE == JPEG
    begin
      assign lut_size = 250;
      case ({IMAGE_FLIP[0], IMAGE_MIRROR[0]})
        2'b00:
          begin
            ov5640_init_table_jpeg camera_init_table(
              .addr (cnt ),
              .clk  (Clk ),
              .q    (lut )
            );
            defparam camera_init_table.IMAGE_WIDTH  = IMAGE_WIDTH;
            defparam camera_init_table.IMAGE_HEIGHT = IMAGE_HEIGHT;
            defparam camera_init_table.IMAGE_FLIP   = 8'h40;
            defparam camera_init_table.IMAGE_MIRROR = 4'h7;
          end
        2'b01:
          begin
            ov5640_init_table_jpeg camera_init_table(
              .addr (cnt ),
              .clk  (Clk ),
              .q    (lut )
            );
            defparam camera_init_table.IMAGE_WIDTH  = IMAGE_WIDTH;
            defparam camera_init_table.IMAGE_HEIGHT = IMAGE_HEIGHT;
            defparam camera_init_table.IMAGE_FLIP   = 8'h40;
            defparam camera_init_table.IMAGE_MIRROR = 4'h0;
          end
        2'b10:
          begin
            ov5640_init_table_jpeg camera_init_table(
              .addr (cnt ),
              .clk  (Clk ),
              .q    (lut )
            );
            defparam camera_init_table.IMAGE_WIDTH  = IMAGE_WIDTH;
            defparam camera_init_table.IMAGE_HEIGHT = IMAGE_HEIGHT;
            defparam camera_init_table.IMAGE_FLIP   = 8'h47;
            defparam camera_init_table.IMAGE_MIRROR = 4'h7;
          end
        2'b11:
          begin
            ov5640_init_table_jpeg camera_init_table(
              .addr (cnt ),
              .clk  (Clk ),
              .q    (lut )
            );
            defparam camera_init_table.IMAGE_WIDTH  = IMAGE_WIDTH;
            defparam camera_init_table.IMAGE_HEIGHT = IMAGE_HEIGHT;
            defparam camera_init_table.IMAGE_FLIP   = 8'h47;
            defparam camera_init_table.IMAGE_MIRROR = 4'h0;
          end
      endcase
    end
  endgenerate

  assign addr = lut[23:8];
  assign wrdata = lut[7:0];

  i2c_control i2c_control(
    .Clk       (Clk       ),
    .Rst_p     (Rst_p     ),
    .wrreg_req (wrreg_req ),
    .rdreg_req (0         ),
    .addr      (addr      ),
    .addr_mode (addr_mode ),
    .wrdata    (wrdata    ),
    .rddata    (rddata    ),
    .device_id (device_id ),
    .RW_Done   (RW_Done   ),
    .ack       (ack       ),
    .i2c_sclk  (i2c_sclk  ),
    .i2c_sdat  (i2c_sdat  )
  );

  wire Go;   //initial enable
  reg [20:0] delay_cnt;

  //上电并复位完成20ms后再配置摄像头，所以从上电到开始配置应该是1.0034 + 20 = 21.0034ms
  //这里为了优化逻辑，简化比较器逻辑，直接使延迟比较值为24'h100800，是21.0125ms
  always @ (posedge Clk or posedge Rst_p)
  if (Rst_p)
    delay_cnt <= 21'd0;
  else if (delay_cnt == 21'h100800)
    delay_cnt <= 21'h100800;
  else
    delay_cnt <= delay_cnt + 1'd1;

  //当延时时间到，开始使能初始化模块对OV5640的寄存器进行写入  
  assign Go = (delay_cnt == 21'h1007ff) ? 1'b1 : 1'b0;

  //5640要求上电后其复位状态需要保持1ms，所以上电后需要1ms之后再使能释放摄像头的复位信号
  //这里为了优化逻辑，简化比较器逻辑，直接使延迟比较值为24'hC400，是1.003520ms
  assign camera_rst_n = (delay_cnt > 21'h00C400);

  reg [18:0] delay5ms_cnt;
  wire       delay5ms_flag;

  always@(posedge Clk or posedge Rst_p)
  if(Rst_p)
    delay5ms_cnt <= 0;
  else if(cnt == 1 && RW_Done && (!ack))
    delay5ms_cnt <= 1;
  else if(delay5ms_cnt > 0)
    delay5ms_cnt <= delay5ms_cnt + 1;

  assign delay5ms_flag = delay5ms_cnt[18];

  always@(posedge Clk or posedge Rst_p)
  if(Rst_p)
    cnt <= 0;
  else if(Go) 
    cnt <= 0;
  else if(cnt == 1)begin
    if(delay5ms_flag)
      cnt <= 2;
    else
      cnt <= 1;
  end
  else if(cnt < lut_size && cnt != 1)begin
    if(RW_Done && (!ack))
      cnt <= cnt + 1'b1;
    else
      cnt <= cnt;
  end
  else
    cnt <= 0;

  always@(posedge Clk or posedge Rst_p)
  if(Rst_p)
    Init_Done <= 0;
  else if(Go) 
    Init_Done <= 0;
  else if(cnt == lut_size)
    Init_Done <= 1;

  reg [1:0]state;

  always@(posedge Clk or posedge Rst_p)
  if(Rst_p)begin
    state <= 0;
    wrreg_req <= 1'b0;
  end
  else if(cnt < lut_size)begin
    case(state)
      0:
        if(Go)
          state <= 1;
        else
          state <= 0;
      1:
        begin
          wrreg_req <= 1'b1;
          state <= 2;
        end
      2:
        begin
          wrreg_req <= 1'b0;
          if(cnt == 1 && delay5ms_flag)
            state <= 1;
          else if(cnt != 1 && RW_Done)
            state <= 1;
          else
            state <= 2;
        end
      default:state <= 0;
    endcase
  end
  else
    state <= 0;

endmodule
