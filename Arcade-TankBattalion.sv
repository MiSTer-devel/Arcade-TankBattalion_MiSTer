//============================================================================
//  Arcade: TankBattalion
//
//  Namco 1980 Arcade Game
//  Hardware Description by Nick Stone, MisterRetroWolf
//  https://github.com/nic24-rgb/TankBatt 
//
//============================================================================

module emu
(
	`include "sys/emu_ports.vh"
);


///////// Default values for ports not used in this core /////////

assign ADC_BUS  = 'Z;
assign USER_OUT = '1;
assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
//assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = '0;  

assign VGA_F1 = 0;
assign VGA_SCALER = 0;
assign VGA_DISABLE = 0;
assign HDMI_FREEZE = 0;
assign FB_FORCE_BLANK = 0;
assign HDMI_BLACKOUT = 0;
assign HDMI_BOB_DEINT = 0;

assign AUDIO_S = 1;//signed for audio out
//assign AUDIO_L = 0;
//assign AUDIO_R = 0;
assign AUDIO_MIX = 0;

assign LED_DISK = 0;
assign LED_POWER = 0;
assign BUTTONS = 0;

//////////////////////////////////////////////////////////////////

wire [1:0] ar = status[20:19];

assign VIDEO_ARX = (!ar) ? ((status[2])  ? 8'd4 : 8'd3) : (ar - 1'd1);
assign VIDEO_ARY = (!ar) ? ((status[2])  ? 8'd3 : 8'd4) : 12'd0;

`include "build_id.v" 
localparam CONF_STR = {
	"A.TANKBATTALION;;",
	"H0OJK,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"H1H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;", 														   
	"-;",
	"O8,Test Mode,Off,On;",
	"O9,Lives,3,2;",
	"OAB,Bonus,20000,10000,None,15000;",
	"OCD,Coinage,1 Coin/1 Credit,2 Coins/1 Credit,1 Coin/2 Credits,Freeplay;",
	"OE,Cabinet,Upright,Cocktail;",
	"-;",	
	"R0,Reset;",
	"J1,Shoot,Start 1P,Start 2P,Coin,Service;",
	"Jn,A,Start,Select,Left,Right;",
	"V,v",`BUILD_DATE
};


////////////////////   CLOCKS   ///////////////////

wire CLK_18M;
wire clk_4M;
wire clk_sys=CLK_18M;//clk_4M;
wire clk_vid;
reg ce_pix;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(CLK_18M),//18
	.outclk_1(clk_vid),//16
	.outclk_2(clk_4M)//4
);

////////////////////   HPS   /////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;
wire        video_rotated;

wire        ioctl_download;
wire        ioctl_upload;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;
wire  [7:0] ioctl_din;
wire  [7:0] ioctl_index;
wire        ioctl_wait;

wire [15:0] joystick_0;

wire [21:0] gamma_bus;


hps_io #(.CONF_STR(CONF_STR)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),
	.EXT_BUS(),

	.buttons(buttons),
	.status(status),
	.status_menumask({direct_video}),

	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video), 
   .video_rotated(video_rotated),
	.ioctl_download(ioctl_download),
	.ioctl_upload(ioctl_upload),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_din(ioctl_din),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.joystick_0(joystick_0)
);

///////////////////   CONTROLS   ////////////////////
wire m_right  = joystick_0[0];
wire m_left   = joystick_0[1];
wire m_down   = joystick_0[2];
wire m_up     = joystick_0[3];
wire m_shoot  = joystick_0[4];
wire m_start1p  = joystick_0[5];
wire m_start2p  = joystick_0[6];
wire m_coin   = joystick_0[7];
wire m_service   = joystick_0[8];
wire m_testtogg   = status[8];

// DIPs
//wire [7:0]m_dip = {status[14],status[13:12],status[11:10],status[9],status[8],1'b1};
wire [7:0]m_dip = {1'b1,status[8],status[9],status[11],~status[10],~status[13:12],~status[14]};
/*
| 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 |
|   |OFF|   |   |   |   |   |   | Test Mode - Off*
|   |ON |   |   |   |   |   |   | Test Mode - On
|   |   |OFF|   |   |   |   |   | Lives - 2
|   |   |ON |   |   |   |   |   | Lives - 3*
|   |   |   |OFF|OFF|   |   |   | Bonus Life - None
|   |   |   |ON |OFF|   |   |   | Bonus Life - 20000*
|   |   |   |OFF|ON |   |   |   | Bonus Life - 15000
|   |   |   |ON |ON |   |   |   | Bonus Life - 10000
|   |   |   |   |   |OFF|OFF|   | Coinage - 1 Coin/1 Credit*
|   |   |   |   |   |ON |OFF|   | Coinage - 1 Coin/2 Credit
|   |   |   |   |   |OFF|ON |   | Coinage - 2 Coin/1 Credit
|   |   |   |   |   |ON |ON |   | Coinage - Free Play
|   |   |   |   |   |   |   |OFF| Cabinet - Upright*
|   |   |   |   |   |   |   |ON | Cabinet - Cocktail
*/

///////////////////   CLOCK DIVIDER   ////////////////////

always @(posedge clk_vid) begin
	reg [1:0] div;
	div <= div + (forced_scandoubler ? 2'd1 : 2'd2);
	ce_pix <= !div;
end

///////////////////   VIDEO   ////////////////////
wire hblank, vblank;
wire hs, vs;

wire r, g, b;
wire [8:0] rgb = {{3{r}},{3{g}},{3{b}}};//23:0

wire no_rotate = status[2] | direct_video;
wire rotate_ccw = 0;
wire flip = 0;



screen_rotate screen_rotate (.*);

arcade_video #(260,9) arcade_video //288
(
	.*,
	.clk_video(clk_vid),
	.RGB_in(rgb),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),
	.fx(status[5:3])
);


///////////////////   GAME   ////////////////////
wire rom_download = ioctl_download & !ioctl_index;
wire reset_top = (RESET | status[0] | buttons[1] | rom_download);
assign LED_USER = rom_download;

Tankb_fpga tankb (
	.CLK_18M(CLK_18M),
	.RED(r),
	.GREEN(g),
	.BLUE(b),
	.H_SYNC(hs),
	.V_SYNC(vs),
	.H_BLANK(hblank),
	.V_BLANK(vblank),
	.RESET_n(~reset_top),
	.CONTROLS(~{m_service,m_testtogg,m_coin,m_start2p,m_start1p,m_shoot,m_up,m_down,m_left,m_right}),
	.DIP(m_dip),
	.dn_addr(ioctl_addr[13:0]),
	.dn_data(ioctl_dout),
	.dn_wr(ioctl_wr & rom_download), //& rom_download
	.audio_l(AUDIO_L),
	.audio_r(AUDIO_R)
);
	
endmodule