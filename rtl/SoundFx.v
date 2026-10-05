// Hit / shoot sounds: a noise-controlled switch chops the charge on C10 / C11,
// followed by a multiple-feedback band-pass modelled as a state-variable filter.
// Fixed point, voltages in Q24.

module FxClocks
(
	input  clk,       // 18 MHz
	output ena48,
	output noise
);

reg [8:0]  d48 = 0;
reg [12:0] d4k = 0;
reg [17:0] lfsr = 18'h2AAAA;

assign ena48 = (d48 == 374);
wire   ena4k = (d4k == 4499);
assign noise = lfsr[0];

always @(posedge clk) begin
	d48 <= ena48 ? 9'd0 : d48 + 1'd1;
	d4k <= ena4k ? 13'd0 : d4k + 1'd1;
	if (ena4k) lfsr <= {lfsr[16:0], lfsr[17] ^ lfsr[10]};
end

endmodule

module SoundFx #(
	parameter [15:0] DECAY = 921,
	parameter [15:0] DIV   = 8383,
	parameter [15:0] F     = 1438,
	parameter [15:0] Q     = 26482,
	parameter [17:0] GAIN  = 52734
)
(
	input  clk,
	input  ena48,
	input  trig,
	input  noise,
	output signed [15:0] sound
);

localparam signed [63:0] V0 = 64'sd72142029;
localparam signed [63:0] DECAYS = DECAY;
localparam signed [63:0] DIVS   = DIV;
localparam signed [63:0] FS_    = F;
localparam signed [63:0] QS     = Q;
localparam signed [63:0] GAINS  = GAIN;

reg signed [63:0] v = 0, low = 0, band = 0;

wire signed [63:0] x     = noise ? ((v * DIVS) >>> 16) : 64'sd0;
wire signed [63:0] low_n = low + ((FS_ * band) >>> 16);
wire signed [63:0] hi    = x - low_n - ((QS * band) >>> 16);
wire signed [63:0] band_n = band + ((FS_ * hi) >>> 16);

always @(posedge clk) if (ena48) begin
	if (trig)                 v <= v + (((V0 - v) * 1365) >>> 16);
	else if (v < 64'sd262144) v <= 0;
	else if (noise)           v <= v - ((v * DECAYS) >>> 24);
	low  <= low_n;
	band <= band_n;
end

wire signed [63:0] scaled = (band * GAINS) >>> 24;
assign sound = (scaled > 64'sd32767) ? 16'sh7FFF : (scaled < -64'sd32768) ? 16'sh8000 : scaled[15:0];

endmodule
