// Tank Battalion engine sound: LM324 Schmitt oscillator -> 7492 (with QB^QD
// feeding CKA) -> RC mix. Fixed-point model, voltages in Q16 volts.

module EngineSound
(
	input         clk,       // 18 MHz
	input         reset,     // 7492 reset (sound off)
	input         highrpm,
	output signed [15:0] sound
);

reg [8:0] div = 0;
wire ena = (div == 271);
always @(posedge clk) div <= ena ? 9'd0 : div + 1'd1;

reg        out = 0, g_d = 0, x_d = 0, qa = 0;
reg signed [21:0] v = 0, y = 50790;
reg [2:0]  cnt = 0;

wire signed [21:0] vp = out ? 22'sd183918 : 22'sd119800;
wire        nout = vp > v;
wire        g = highrpm ^ ~nout;
wire signed [21:0] target = nout ? (g ? 22'sd224892 : 22'sd186706)
                                 : (g ? 22'sd66398  : 22'sd28212);
wire        qb = (cnt == 1) | (cnt == 4);
wire        qd = (cnt >= 3);
wire        x = qb ^ qd;

always @(posedge clk) if (ena) begin
	out <= nout;
	v <= v + ((target - v + 22'sd128) >>> 8);
	g_d <= g;
	x_d <= x;
	if (reset) begin
		cnt <= 0;
		qa <= 0;
	end else begin
		if (g_d && !g) cnt <= (cnt == 5) ? 3'd0 : cnt + 1'd1;
		if (x_d && !x) qa <= ~qa;
	end
end

wire [1:0]         ones = qa + qb + qd;
wire signed [21:0] avg = 22'sd50790 + $signed({20'd0, ones}) * 22'sd52429;

always @(posedge clk) if (ena)
	y <= y + (((avg - y) * 24) >>> 10);

reg  signed [21:0] lp = 50790;
always @(posedge clk) if (ena)
	lp <= lp + ((y - lp) >>> 9);

wire signed [21:0] ac = (y - lp) >>> 2;
assign sound = ac[15:0];

endmodule
