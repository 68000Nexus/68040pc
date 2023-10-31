//------------------------------------------------------------------------------
//
// DRAM Controller State machine
//
//------------------------------------------------------------------------------

module sm(
	input clk,
	input nRESET,

	input		dramsel,	// From decoder.v

	input	[11:0]	row_addr,	// Input row and column addresses, these
	input	[11:0]	col_addr,	// will get copied to internal registers
					// on transfer start to facilitate
					// advancing column addresses for
					// burst transfers.
	input	[3:0]	dec_ras,
	input	[3:0]	dec_cas,
	input	[1:0]	modsel,

//	output	[11:0]	m_addr,		// Multiplexed DRAM address bus
	output	[3:0]	ras,		// Shared CAS lines
	output	[3:0]	casa,		// Module 0 RAS lines
	output	[3:0]	casb,		// Module 0 RAS lines
	output	[3:0]	casc,		// Module 0 RAS lines
	output	[3:0]	casd,		// Module 0 RAS lines

	// 68040 signals
	input		nTS,		// Transfer start
	output		nTA,		// Transfer acknowledge
	input		nWR		// Write enable

);

reg	[11:0]	m_addr;
reg	[3:0]	ras;
reg	[3:0]	casa;
reg	[3:0]	casb;
reg	[3:0]	casc;
reg	[3:0]	casd;
reg		nTA;

// Asynchronous state machine signals
reg		a_refack;
reg		a_rcsel;
reg	[11:0]	a_m_addr;
reg	[3:0]	a_ras;
reg	[3:0]	a_casa;
reg	[3:0]	a_casb;
reg	[3:0]	a_casc;
reg	[3:0]	a_casd;
reg		a_wr;
reg		a_ta;

// internal signals
reg		rcsel;		// Mux selector, 0 = row, 1 = column
reg [11:0]	col_buf;

reg		refreq;		// Refresh request
wire		reftimer;	// Refresh counter equals limit
reg [8:0]	refc;		// Refresh counter
reg		refack;		// Refresh Acknowledge

reg [3:0]	initrefc;	// To count 8 init refresh cycles
wire		initreftimer;	// Init refresh cycle counter equals limit
reg		initrefdone;	// Indicates that 8 refreshes done

reg [12:0]	initc;		// Initialization counter
wire		inittimer;	// Init counter equals limit
reg		initdone;	// Initialization is done (stays 1 after inittimer goes high)

reg [3:0]	state, nstate;	// Current state, next state

// states
parameter [3:0] init0	= 4'b0000;	// Wait for 200us init delay
parameter [3:0]	init1	= 4'b0001;	// Wait for 8 refresh cycles
parameter [3:0] cbr1	= 4'b0010;
parameter [3:0] cbr2	= 4'b0011;
parameter [3:0] cbr3	= 4'b0100;
parameter [3:0] cbr4	= 4'b0101;
parameter [3:0] prechg	= 4'b0110;
parameter [3:0] rw1	= 4'b0111;
parameter [3:0] rw2	= 4'b1000;
parameter [3:0] rw3	= 4'b1001;
parameter [3:0] page1	= 4'b1010;
parameter [3:0] page2	= 4'b1011;
parameter [3:0] page3	= 4'b1100;
parameter [3:0] dummyB	= 4'b1101;
parameter [3:0] dummyC	= 4'b1110;
parameter [3:0] idle	= 4'b1111;

// The DRAM controller is implemented as two finite-state machines. The first
// machine operates asynchronously and determines the next state based on the
// current inputs. The second state machine applies the values of the
// asynchronous signals to the synchronous outputs with the system clock.

// Async FSM
always @(*) begin
	case (state)
		init0: begin			// Wait for 200us init delay
			a_ras	<= 4'b1111;
			a_casa	<= 4'b1111;
			a_casb	<= 4'b1111;
			a_casc	<= 4'b1111;
			a_casd	<= 4'b1111;
			a_refack <= 1'b0;
			a_ta	<= 1'b1;
			a_rcsel	<= 1'b0;
			nstate	<= init0;
			if (initdone == 1'b1) begin
				a_ras	<= 4'b1111;
				a_casa	<= 4'b1111;
				a_casb	<= 4'b1111;
				a_casc	<= 4'b1111;
				a_casd	<= 4'b1111;
				a_ta	<= 1'b1;
				a_refack <= 1'b0;
				a_rcsel	<= 1'b0;
				nstate	<= init1;
			end
		end

		init1: begin			// Wait for 8 refresh cycles
			a_ras	<= 4'b1111;
			a_casa	<= 4'b1111;
			a_casb	<= 4'b1111;
			a_casc	<= 4'b1111;
			a_casd	<= 4'b1111;
			a_ta	<= 1'b1;
			a_refack <= 1'b0;
			a_rcsel	<= 1'b0;
			nstate	<= init1;
//			if (initrefdone == 1'b1) begin
//				nstate	<= idle;
//			end
//			else if (refreq == 1'b1)
			if (refreq == 1'b1)
				nstate	<= cbr1;
		end

		idle: begin
			a_casa	<= 4'b1111;
			a_casb	<= 4'b1111;
			a_casc	<= 4'b1111;
			a_casd	<= 4'b1111;
			a_ta	<= 1'b1;
			a_refack <= 1'b0;
			a_rcsel	<= 1'b0;

			if (refreq == 1'b1) begin
				nstate	<= cbr1;
			end
			else begin
				if (dramsel == 1'b1) begin
					a_ras	<= dec_ras;
					nstate	<= rw1;
					a_wr	<= nWR;
				end
			end
		end

		rw1: begin			// DRAM access start
			a_ras	<= dec_ras;
			a_casa	<= (modsel == 2'd0) ? ~dec_cas : 4'b1111;
			a_casb	<= (modsel == 2'd1) ? ~dec_cas : 4'b1111;
			a_casc	<= (modsel == 2'd2) ? ~dec_cas : 4'b1111;
			a_casd	<= (modsel == 2'd3) ? ~dec_cas : 4'b1111;
			a_ta	<= 1'b0;	// Transfer Ack after 1 wait state
			nstate	<= rw2;
		end
		rw2: begin			// TA is sampled here
			a_ras	<= dec_ras;
			a_casa	<= 4'b1111;
			a_casb	<= 4'b1111;
			a_casc	<= 4'b1111;
			a_casd	<= 4'b1111;
			a_ta	<= 1'b1;
			nstate	<= rw3;
		end
		rw3: begin			// Read data sampled here
			a_casa	<= 4'b1111;	// Data is written to DRAM on
			a_casb	<= 4'b1111;	// rising edge of CAS
			a_casc	<= 4'b1111;
			a_casd	<= 4'b1111;
			/*
			// TODO: Implement page hit
			if (pagehit) begin
				ns	<= page1;
				a_ta	<= 1'b0;
				//...
			end else begin
			*/
			a_ras	<= 4'b1111;
			a_ta	<= 1'b1;
			nstate	<= prechg;
			//end
		end

		cbr1: begin			// CAS before RAS refresh start
			a_casa	<= 4'b0000;	// Assert all the CASs
			a_casb	<= 4'b0000;
			a_casc	<= 4'b0000;
			a_casd	<= 4'b0000;
			a_ras	<= 4'b1111;
			a_refack <= 1'b1;
			nstate	<= cbr2;
		end
		cbr2: begin
			a_casa	<= 4'b0000;
			a_casb	<= 4'b0000;
			a_casc	<= 4'b0000;
			a_casd	<= 4'b0000;
			a_ras	<= 4'b0000;	// Next, assert RAS
			a_refack <= 1'b0;
			nstate	<= cbr3;
		end
		cbr3: begin
			a_casa	<= 4'b1111;	// Un-assert all the CASs
			a_casb	<= 4'b1111;
			a_casc	<= 4'b1111;
			a_casd	<= 4'b1111;
			a_ras	<= 4'b0000;
			a_refack <= 1'b0;
			nstate	<= cbr4;
		end
		cbr4: begin
			a_casa	<= 4'b1111;
			a_casb	<= 4'b1111;
			a_casc	<= 4'b1111;
			a_casd	<= 4'b1111;
			a_ras	<= 4'b1111;	// Un-assert RAS
			a_refack <= 1'b0;
			if (~initrefdone)
				nstate <= init1;
			else
				nstate	<= prechg;
		end

		prechg: begin
			a_casa	<= 4'b1111;
			a_casb	<= 4'b1111;
			a_casc	<= 4'b1111;
			a_casd	<= 4'b1111;
			a_ras	<= 4'b1111;
			a_refack <= 1'b0;
			nstate	<= idle;
		end
	endcase
end

// Sync FSM
always @(negedge clk or negedge nRESET)
	if (~nRESET) begin
		state	<= init0;
		refack	<= 1'b0;
		ras	<= 4'b1111;
		casa	<= 4'b1111;
		casb	<= 4'b1111;
		casc	<= 4'b1111;
		casd	<= 4'b1111;
		m_addr	<= 12'h000;
		nTA	<= 1'b1;
	end
	else begin
		state	<= nstate;
		// Update synchronous signals
		refack	<= a_refack;
		m_addr	<= a_m_addr;
		ras	<= a_ras;
		casa	<= a_casa;
		casb	<= a_casb;
		casc	<= a_casc;
		casd	<= a_casd;
		m_addr	<= a_m_addr;
		nTA	<= a_ta;
	end

// ---------------------------
//   initialization timer
//   13 bits - 200us interval
// ---------------------------
always @(negedge clk or negedge nRESET) begin
	if (~nRESET)
		initc	<= 13'd0;
	else begin
		initc	<= initc + 1;
	end
end
// 33MHz input clock = 30.303ns/cycle
// DRAM Datasheet wants 200us after powerup for initialization
// 200us / 30.303ns = 6600
assign inittimer = ( initc == 13'd6600 ) ? 1'b1 : 1'b0;

always @(negedge clk or negedge nRESET) begin
	if (~nRESET)
		initdone <= 1'b0;
	else begin
		if (inittimer)
			initdone <= 1'b1;
	end
end

// --------------------------------------
//   init refresh counter
//   4 bits - 8 refresh cycles interval
// --------------------------------------
assign initreftimer = (initrefc == 4'd8 ) ? 1'b1 : 1'b0;

always @(negedge clk or negedge nRESET) begin
	if (~nRESET) begin
		initrefdone <= 1'b0;
	end
	else
		if (initreftimer == 1'b1)
			initrefdone <= 1'b1;
end

// ---------------------------
//   refresh counter
//   9 bits - 15us interval
// ---------------------------
always @(negedge clk or negedge nRESET) begin
	if (~nRESET) begin
		refc <= 9'b0;
		initrefc    <= 4'b0000;
	end
	else begin
		if (refack == 1'b1) begin
			refc <= 9'b0;
			initrefc <= initrefc + 1;
		end
		else
			refc <= refc + 1;
	end
end
// 33MHz input clock = 30.303ns/cycle
// 4096 RAS before CAS refreshes to do per 64ms
// 64ms / 4096 = 15.6us
// 500 cycles * 30.303ns = 15.151us (less than 15.6us)
assign reftimer = ( refc == 9'b1_1111_0100 ) ? 1'b1 : 1'b0;

// Synchronously set refreq to 1 if reftimer, and to 0 if refack
always @(negedge clk or negedge nRESET) begin
	if (~nRESET)
		refreq <= 1'b0;
	else begin
		if (refack == 1'b1)
			refreq <= 1'b0;
		else begin
			if (reftimer)
				refreq <= 1'b1;
		end
	end
end

endmodule
