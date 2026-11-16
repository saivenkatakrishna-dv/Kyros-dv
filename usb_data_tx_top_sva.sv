`timescale 1ns/1ps

//==============================================================================
// USB DATA TX TOP - FORMAL ASSERTION MODULE
//
// Intended DUT:
//   usb_data_tx_top
//
//==============================================================================

module usb_data_tx_top_sva #(
  parameter bit          HS_SUPPORT = 1'b1,
  parameter int unsigned MAX_PKT    = (HS_SUPPORT ? 1024 : 1023),
  parameter int unsigned LEN_W      = $clog2(MAX_PKT + 1)
) (
  input  logic             clk,
  input  logic             rst_n,

  input  logic             req_valid,
  input logic             req_ready,
  input  logic             req_use_int_toggle,
  input  logic             req_toggle,
  input  logic             req_force_data0,
  input  logic [1:0]       req_type,
  input  logic             ls_mode,
  input  logic             hs_mode,
  input  logic             req_dir_in,
  input  logic [1:0]       req_mult,
  input  logic [1:0]       req_tx_idx,
  input  logic [LEN_W-1:0] req_length,
  input  logic [LEN_W-1:0] cfg_max_pkt,
  input  logic             abort,

  input  logic [7:0]       pld_data,
  input  logic             pld_valid,
  input logic             pld_ready,

  input logic [7:0]       tx_data,
  input logic             tx_valid,
  input  logic             tx_ready,
  input logic             tx_sop,
  input logic             tx_eop,
  input logic             tx_bs_viol,
  input logic             pkt_active,

  input  logic             ack_rcvd,
  input  logic             nyet_rcvd,
  input  logic             toggle_clr,
  input logic             ep_toggle,
  input logic             ack_pending,

  input logic             done,
  input logic             err_req,
  input logic             aborted,
  input logic             underrun,
  input logic             req_fire_ok,
  input logic             crc_out,
  input logic             sel_err,
  input logic [1:0]       state,
  input logic             use_err
  
);

  import usb_pkg::*;

  //--------------------------------------------------------------------------
  // Internal DUT aliases
  //--------------------------------------------------------------------------

  wire tog_q          = u_tog.tog_q;
  wire sent_data0_q   = u_tog.sent_data0_q;
  wire sent_noniso_q  = u_tog.sent_noniso_q;
  wire pend_q         = u_tog.pend_q;
  wire tog_nxt        = u_tog.tog_nxt;
  wire ack_any        = u_tog.ack_any;

  wire [3:0] sel_pid_i       = u_sel.pid;
  wire [7:0] sel_pid_byte_i  = u_sel.pid_byte;
  wire       toggle_used_i   = u_tog.toggle_used;
  wire       req_is_isoc_i   = (req_type == EP_ISOC);

  wire req_bad          = u_gate.req_bad;
  wire req_fire         = u_gate.req_fire;
 // wire req_fire_ok_i    = u_gate.req_fire_ok;
  wire hs_eff_i         = u_gate.hs_eff;
  wire asm_req_valid_i  = u_gate.asm_req_valid;

  // usb_packet_assembler state encoding:
  // {S_IDLE, S_PID, S_DATA, S_CRC} = {2'd0, 2'd1, 2'd2, 2'd3}
  localparam logic [1:0] ST_IDLE = 2'd0;
  localparam logic [1:0] ST_PID  = 2'd1;
  localparam logic [1:0] ST_DATA = 2'd2;
  localparam logic [1:0] ST_CRC  = 2'd3;

  wire state_idle = (u_asm.state == ST_IDLE);
  wire state_pid  = (u_asm.state == ST_PID);
  wire state_data = (u_asm.state == ST_DATA);
  wire state_crc  = (u_asm.state == ST_CRC);

  wire cnt_last_i     = u_asm.cnt_last;
  wire cnt_zero_i     = u_asm.cnt_zero;
  wire byte_acc_i     = u_asm.byte_acc;
  wire start_i        = u_asm.start;
  wire crc_last_i     = u_asm.crc_last;
 
    localparam logic [1:0] S_IDLE = 2'd0;
    localparam logic [1:0] S_PID  = 2'd1;
    localparam logic [1:0] S_DATA = 2'd2;
    localparam logic [1:0] S_CRC  = 2'd3;
  
property ap_payload_recovery_during_stall;
  @(posedge clk) disable iff (!rst_n)

  (state == S_DATA &&
   !tx_ready &&
   !pld_valid &&
   !abort)

  ##1

  (state == S_DATA &&
   !tx_ready &&
   pld_valid &&
   !abort)

  |-> (!use_err &&
       tx_data == pld_data &&
       !tx_bs_viol &&
       !tx_eop);

endproperty

assert property (ap_payload_recovery_during_stall)
else $error(
  "BUG: Underrun committed before payload transfer opportunity"
);

property ap_tx_output_stable_when_stalled;
  @(posedge clk) disable iff (!rst_n)

  (tx_valid && !tx_ready && !abort)
  |=> (abort ||
       (tx_valid &&
        $stable(tx_data) &&
        $stable(tx_sop) &&
        $stable(tx_eop) &&
        $stable(tx_bs_viol)));

endproperty

assert property (ap_tx_output_stable_when_stalled)
else $error(
  "BUG: TX output changed or valid dropped during back-pressure"
);

property ap_fs_bulk_cfg24_len20_rejected;
  @(posedge clk) disable iff (!rst_n)

  (req_valid &&
   req_ready &&
   !ls_mode &&
   !hs_mode &&
   req_type == EP_BULK &&
   cfg_max_pkt == 24 &&
   req_length == 20 &&
   !sel_err)

  |-> !req_fire_ok;

endproperty

assert property (ap_fs_bulk_cfg24_len20_rejected)
else $error(
  "BUG: FS BULK accepted cfg_max_pkt=24, req_length=20"
);


 //  issue 1
// 1. Invalid SETUP length must be rejected
ap_invalid_setup_length_rejected:
assert property (
  @(posedge clk) disable iff (!rst_n)
  (req_valid && req_force_data0 &&
   req_type == EP_CTRL && req_length != 8)
  |-> !req_fire_ok
);

// 2. SETUP on non-control endpoint must be rejected
ap_setup_non_control_rejected:
assert property (
  @(posedge clk) disable iff (!rst_n)
  (req_valid && req_force_data0 &&
   req_type != EP_CTRL)
  |-> !req_fire_ok
);

// 3. Accepted SETUP must be legal
ap_accepted_setup_is_legal:
assert property (
  @(posedge clk) disable iff (!rst_n)
  (req_fire_ok && req_force_data0)
  |-> (req_type == EP_CTRL && req_length == 8)
);



/*
//-----------------------------------------------------------------------------------
//=========================================================================
    // ASSUMPTIONS : the scenario of spec 8.6.4 at high speed
    //=========================================================================

    // High-speed operation (the case where the spec fixes the required error
    // mechanism: complement the CRC). FS/LS need a bit-stuff violation from
    // the SIE and cannot be seen on this interface.
    as_high_speed:
        assume property (@(posedge clk) disable iff (!rst_n)
                         hs_mode && !ls_mode);

    // Isolate underrun from host abort (abort has the same truncation issue
    // but is a different scenario).
    as_no_abort:
        assume property (@(posedge clk) disable iff (!rst_n)
                         !abort);

    // The SIE/PHY never back-pressures. Only needed by ap_underrun_crc_complemented
    // to fix the byte timing; ap_underrun_ends_with_crc does not need it.
    as_no_backpressure:
        assume property (@(posedge clk) disable iff (!rst_n)
                         tx_ready);

    //=========================================================================
    // ASSERTIONS
    //=========================================================================

    // 1. An underrun must not leave a silently truncated packet: the last byte
    //    the SIE accepted before the underrun status must be the final byte
    //    (tx_eop) of a CRC field. The status pulses one clock after the last
    //    accepted byte, the same timing as done.
    ap_underrun_ends_with_crc:
        assert property (@(posedge clk) disable iff (!rst_n)
                         underrun
                         |-> $past(tx_valid && tx_ready && tx_eop))
        else $error("8.6.4: underrun left a truncated packet with no forced-error CRC");

    // 2. That CRC field must be the complement of the CRC calculated over the
    //    data sent so far (wire order: high byte first, each byte bit-reversed).
    ap_underrun_crc_complemented:
        assert property (@(posedge clk) disable iff (!rst_n)
                         underrun
                         |-> ($past(tx_data, 2) == {~crc_out[8],  ~crc_out[9],  ~crc_out[10], ~crc_out[11],
                                                    ~crc_out[12], ~crc_out[13], ~crc_out[14], ~crc_out[15]}) &&
                             ($past(tx_data, 1) == {~crc_out[0],  ~crc_out[1],  ~crc_out[2],  ~crc_out[3],
                                                    ~crc_out[4],  ~crc_out[5],  ~crc_out[6],  ~crc_out[7]}))
        else $error("8.6.4: CRC sent on underrun is not the complement of the calculated CRC");

    //=========================================================================
    // COVER : the scenario is reachable (rules out a vacuous proof)
    //=========================================================================
    cv_underrun:
        cover property (@(posedge clk) disable iff (!rst_n) underrun);


// SETUP request must have exactly 8 bytes
property ap_setup_length_8;
  @(posedge clk) disable iff (!rst_n)
  (req_valid && req_force_data0)
  |-> (req_type == EP_CTRL && req_length == 8);
endproperty

//assert property (ap_setup_length_8);

// Invalid SETUP request must not be accepted
property ap_invalid_setup_rejected;
  @(posedge clk) disable iff (!rst_n)
  (req_valid && req_force_data0 &&
   ((req_type != EP_CTRL) || (req_length != 8)))
  |-> !req_fire_ok;
endproperty

assert property (ap_invalid_setup_rejected);

*/
  //--------------------------------------------------------------------------
  // RESET / BASIC OUTPUT CONSISTENCY
  //--------------------------------------------------------------------------
/*
  ap_reset_req_ready:
    assert property (@(posedge clk)
                     !rst_n |-> req_ready)
    else $error("REQ_READY must be high in IDLE after reset");

  ap_reset_pkt_idle:
    assert property (@(posedge clk)
                     !rst_n |-> !pkt_active)
    else $error("PKT_ACTIVE must be low during reset");

  ap_reset_outputs:
    assert property (@(posedge clk)
                     !rst_n |-> !tx_valid &&
                               !tx_sop &&
                               !tx_eop &&
                               !pld_ready &&
                               !done &&
                               !aborted &&
                               !underrun &&
                               !ack_pending)
    else $error("Unexpected output asserted during reset");
*/
/*
  ap_req_ready_state:
    assert property (@(posedge clk) disable iff (!rst_n)
                     req_ready == state_idle)
    else $error("REQ_READY does not match assembler IDLE state");

  ap_pkt_active_state:
    assert property (@(posedge clk) disable iff (!rst_n)
                     pkt_active == state_idle)
    else $error("PKT_ACTIVE does not match assembler state");

  ap_ep_toggle_consistency:
    assert property (@(posedge clk) disable iff (!rst_n)
                     ep_toggle == tog_q)
    else $error("EP_TOGGLE mismatch with toggle tracker");

  ap_ack_pending_consistency:
    assert property (@(posedge clk) disable iff (!rst_n)
                     ack_pending == pend_q)
    else $error("ACK_PENDING mismatch with toggle tracker");

  //--------------------------------------------------------------------------
  // REQUEST GATE
  //--------------------------------------------------------------------------

  ap_asm_req_valid:
    assert property (@(posedge clk) disable iff (!rst_n)
                     asm_req_valid_i == (req_valid && !req_bad))
    else $error("Assembler request valid mismatch");

  ap_req_fire:
    assert property (@(posedge clk) disable iff (!rst_n)
                     req_fire == (req_valid && req_ready))
    else $error("Request fire mismatch");

  ap_req_fire_ok:
    assert property (@(posedge clk) disable iff (!rst_n)
                     req_fire_ok_i == (req_fire && !req_bad))
    else $error("REQ_FIRE_OK mismatch");

  ap_bad_req_not_forwarded:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (req_fire && req_bad)
                     |-> !req_fire_ok_i && !asm_req_valid_i)
    else $error("Bad request was forwarded");

  ap_bad_req_error:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (req_fire && req_bad)
                     |=> err_req)
    else $error("ERR_REQ missing after rejected request");

  ap_no_spurious_error:
    assert property (@(posedge clk) disable iff (!rst_n)
                     err_req |-> $past(req_fire && req_bad))
    else $error("ERR_REQ asserted without rejected request");

  ap_hs_eff:
    assert property (@(posedge clk) disable iff (!rst_n)
                     hs_eff_i == (HS_SUPPORT && hs_mode))
    else $error("HS effective mode mismatch");

  //--------------------------------------------------------------------------
  // REQUEST ACCEPTANCE / PID SELECTION
  //--------------------------------------------------------------------------

  ap_legal_request_starts_packet:
    assert property (@(posedge clk) disable iff (!rst_n)
                     req_fire_ok_i |=> state_pid)
    else $error("Legal request did not enter PID state");

  ap_request_latches_pid:
    assert property (@(posedge clk) disable iff (!rst_n)
                     req_fire_ok_i
                     |=> u_asm.pid_byte_q == $past(sel_pid_byte_i))
    else $error("PID byte was not latched correctly");

  ap_pid_encoding:
    assert property (@(posedge clk) disable iff (!rst_n)
                     sel_pid_byte_i == {~sel_pid_i, sel_pid_i})
    else $error("PID byte encoding is incorrect");

  ap_data_pid_legal:
    assert property (@(posedge clk) disable iff (!rst_n)
                     req_fire_ok_i |->
                     sel_pid_i inside {
                       PID_DATA0, PID_DATA1,
                       PID_DATA2, PID_MDATA
                     })
    else $error("Illegal DATA PID selected");

  //--------------------------------------------------------------------------
  // ASSEMBLER STATE MACHINE
  //--------------------------------------------------------------------------

  ap_idle_state_behavior:
    assert property (@(posedge clk) disable iff (!rst_n)
                     state_idle |-> !pkt_active && !pld_ready)
    else $error("Invalid IDLE state outputs");

  ap_pid_valid:
    assert property (@(posedge clk) disable iff (!rst_n)
                     state_pid && !abort |-> tx_valid)
    else $error("TX_VALID missing in PID state");

  ap_pid_sop:
    assert property (@(posedge clk) disable iff (!rst_n)
                     state_pid |-> tx_sop)
    else $error("TX_SOP missing in PID state");

  ap_pid_no_eop:
    assert property (@(posedge clk) disable iff (!rst_n)
                     state_pid |-> !tx_eop)
    else $error("TX_EOP asserted in PID state");

  ap_data_sop_low:
    assert property (@(posedge clk) disable iff (!rst_n)
                     state_data |-> !tx_sop)
    else $error("TX_SOP asserted in DATA state");

  ap_crc_sop_low:
    assert property (@(posedge clk) disable iff (!rst_n)
                     state_crc |-> !tx_sop)
    else $error("TX_SOP asserted in CRC state");

  ap_pld_ready:
    assert property (@(posedge clk) disable iff (!rst_n)
                     pld_ready == (state_data && tx_ready && !abort))
    else $error("PLD_READY behavior mismatch");

  ap_data_valid:
    assert property (@(posedge clk) disable iff (!rst_n)
                     state_data |-> (tx_valid == (pld_valid && !abort)))
    else $error("TX_VALID mismatch in DATA state");

  ap_crc_valid:
    assert property (@(posedge clk) disable iff (!rst_n)
                     state_crc |-> (tx_valid == !abort))
    else $error("TX_VALID mismatch in CRC state");

  ap_abort_drops_tx_valid:
    assert property (@(posedge clk) disable iff (!rst_n)
                     abort |-> !tx_valid)
    else $error("Abort did not suppress TX_VALID");

  ap_abort_busy_to_idle:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (abort && !state_idle) |=> state_idle)
    else $error("Abort did not return assembler to IDLE");

  ap_abort_pulse:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (abort && !state_idle) |=> aborted)
    else $error("ABORTED pulse missing");

  ap_aborted_one_cycle:
    assert property (@(posedge clk) disable iff (!rst_n)
                     aborted |=> !aborted)
    else $error("ABORTED is not a one-cycle pulse");

  ap_underrun_condition:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (state_data && !pld_valid && !abort)
                     |=> state_idle && underrun)
    else $error("DATA underrun behavior incorrect");

  ap_underrun_one_cycle:
    assert property (@(posedge clk) disable iff (!rst_n)
                     underrun |=> !underrun)
    else $error("UNDERRUN is not a one-cycle pulse");

  ap_pid_to_data:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (state_pid && tx_ready && !abort && !cnt_zero_i)
                     |=> state_data)
    else $error("PID did not transition to DATA");

  ap_pid_to_crc_zero:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (state_pid && tx_ready && !abort && cnt_zero_i)
                     |=> state_crc)
    else $error("Zero-length PID did not transition to CRC");

  ap_data_to_crc:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (state_data && pld_valid && tx_ready &&
                      cnt_last_i && !abort)
                     |=> state_crc)
    else $error("Last DATA byte did not transition to CRC");

  ap_data_waits_for_ready:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (state_data && pld_valid && !cnt_last_i &&
                      !abort && !tx_ready)
                     |=> state_data)
    else $error("DATA state advanced without TX_READY");

  ap_crc_waits_for_ready:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (state_crc && !abort && !crc_last_i && !tx_ready)
                     |=> state_crc)
    else $error("CRC state advanced without TX_READY");

  ap_crc_to_idle_done:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (state_crc && tx_ready && crc_last_i && !abort)
                     |=> state_idle && done)
    else $error("CRC completion did not return to IDLE with DONE");

  ap_done_one_cycle:
    assert property (@(posedge clk) disable iff (!rst_n)
                     done |=> !done)
    else $error("DONE is not a one-cycle pulse");

  //--------------------------------------------------------------------------
  // SOP / EOP
  //--------------------------------------------------------------------------

  ap_eop_only_crc:
    assert property (@(posedge clk) disable iff (!rst_n)
                     tx_eop |-> state_crc)
    else $error("TX_EOP asserted outside CRC state");

  ap_eop_matches_crc_last:
    assert property (@(posedge clk) disable iff (!rst_n)
                     state_crc |-> (tx_eop == crc_last_i))
    else $error("TX_EOP does not match CRC_LAST");

  // The supplied RTL drives tx_sop/tx_eop from state and independently
  // suppresses tx_valid during abort. Therefore SOP->VALID and EOP->VALID
  // assertions are intentionally not used here.

  //--------------------------------------------------------------------------
  // TX DATA MUX
  //--------------------------------------------------------------------------

  ap_pid_tx_data:
    assert property (@(posedge clk) disable iff (!rst_n)
                     state_pid |-> tx_data == u_asm.pid_byte_q)
    else $error("TX_DATA mismatch in PID state");

  ap_data_tx_data:
    assert property (@(posedge clk) disable iff (!rst_n)
                     state_data |-> tx_data == pld_data)
    else $error("TX_DATA mismatch in DATA state");

  ap_crc_tx_data:
    assert property (@(posedge clk) disable iff (!rst_n)
                     state_crc |-> tx_data == u_asm.crc_byte)
    else $error("TX_DATA mismatch in CRC state");

  //--------------------------------------------------------------------------
  // PAYLOAD ACCEPTANCE
  //--------------------------------------------------------------------------

  ap_byte_accept:
    assert property (@(posedge clk) disable iff (!rst_n)
                     byte_acc_i == (pld_ready && pld_valid))
    else $error("BYTE_ACC mismatch");

  ap_pld_ready_no_idle:
    assert property (@(posedge clk) disable iff (!rst_n)
                     !state_data |-> !pld_ready)
    else $error("PLD_READY asserted outside DATA state");

  //--------------------------------------------------------------------------
  // CRC CONTROL
  //--------------------------------------------------------------------------

  ap_crc_seed_on_start:
    assert property (@(posedge clk) disable iff (!rst_n)
                     start_i |=> u_asm.u_crc.crc_q == CRC16_INIT)
    else $error("CRC generator was not seeded on request");

  ap_crc_data_advances:
    assert property (@(posedge clk) disable iff (!rst_n)
                     byte_acc_i
                     |=> u_asm.u_crc.crc_q ==
                         $past(u_asm.u_crc.crc_nxt))
    else $error("CRC did not advance on accepted payload byte");

  ap_zero_len_crc_load:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (state_pid && tx_ready && cnt_zero_i && !abort)
                     |=> u_asm.u_split.crc_q == $past(u_asm.crc_out))
    else $error("Zero-length CRC was not loaded correctly");

  ap_last_data_crc_load:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (byte_acc_i && cnt_last_i)
                     |=> u_asm.u_split.crc_q == $past(u_asm.crc_next_out))
    else $error("Final payload CRC was not loaded correctly");

  ap_crc_splitter_first_byte:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (state_crc && !u_asm.u_split.idx_q)
                     |-> !u_asm.u_split.crc_last)
    else $error("CRC splitter first byte incorrectly marked last");

  ap_crc_splitter_second_byte:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (state_crc && u_asm.u_split.idx_q)
                     |-> u_asm.u_split.crc_last)
    else $error("CRC splitter second byte not marked last");

  //--------------------------------------------------------------------------
  // TOGGLE TRACKER
  //--------------------------------------------------------------------------

  ap_toggle_used_selection:
    assert property (@(posedge clk) disable iff (!rst_n)
                     req_use_int_toggle |-> toggle_used_i == tog_nxt)
    else $error("Internal toggle selection mismatch");

  ap_external_toggle_selection:
    assert property (@(posedge clk) disable iff (!rst_n)
                     !req_use_int_toggle |-> toggle_used_i == req_toggle)
    else $error("External toggle selection mismatch");

  ap_toggle_clear:
    assert property (@(posedge clk) disable iff (!rst_n)
                     toggle_clr |=> tog_q == 1'b0)
    else $error("TOGGLE_CLR did not force DATA0");

  ap_toggle_clear_pending:
    assert property (@(posedge clk) disable iff (!rst_n)
                     toggle_clr |=> !pend_q)
    else $error("TOGGLE_CLR did not clear pending");

  ap_done_sets_pending:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (done && sent_noniso_q &&
                      !req_fire_ok_i && !aborted && !underrun &&
                      !ack_any && !toggle_clr)
                     |=> pend_q)
    else $error("DONE did not set ACK pending for non-ISO packet");

  ap_iso_request_no_pending:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (req_fire_ok_i && req_is_isoc_i)
                     |=> !pend_q)
    else $error("ISO request incorrectly set ACK pending");

  ap_abort_clears_pending:
    assert property (@(posedge clk) disable iff (!rst_n)
                     aborted |=> !pend_q)
    else $error("ABORTED did not clear ACK pending");

  ap_underrun_clears_pending:
    assert property (@(posedge clk) disable iff (!rst_n)
                     underrun |=> !pend_q)
    else $error("UNDERRUN did not clear ACK pending");

  ap_ack_advances_toggle:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (pend_q && (ack_rcvd || nyet_rcvd) &&
                      !toggle_clr && !req_fire_ok_i)
                     |=> tog_q == $past(sent_data0_q))
    else $error("ACK/NYET did not update toggle correctly");

  ap_ack_clears_pending:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (pend_q && (ack_rcvd || nyet_rcvd) &&
                      !req_fire_ok_i && !toggle_clr)
                     |=> !pend_q)
    else $error("ACK/NYET did not clear pending");

 ap_stray_ack_no_toggle_effect_comb:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (!pend_q &&
                      (ack_rcvd || nyet_rcvd) &&
                      !toggle_clr)
                     |-> tog_nxt == tog_q)
    else $error("Stray ACK/NYET incorrectly affected tog_nxt");
    
  ap_toggle_hold_no_handshake:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (!ack_any && !toggle_clr)
                     |=> tog_q == $past(tog_q))
    else $error("Toggle changed without ACK/NYET or clear");

  ap_iso_no_toggle_change:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (req_fire_ok_i && req_is_isoc_i &&
                      !ack_any && !toggle_clr)
                     |-> tog_nxt == tog_q)
    else $error("ISO request changed toggle unexpectedly");

  ap_ack_new_request_bypass:
    assert property (@(posedge clk) disable iff (!rst_n)
                     (req_use_int_toggle && pend_q &&
                      (ack_rcvd || nyet_rcvd) &&
                      req_fire_ok_i && !toggle_clr)
                     |-> toggle_used_i == sent_data0_q)
    else $error("Same-cycle ACK/NYET + new request did not use updated toggle");

  // A new request supersedes the previous pending state.
  ap_new_request_clears_pending:
    assert property (@(posedge clk) disable iff (!rst_n)
                     req_fire_ok_i |=> !pend_q)
    else $error("New request did not supersede pending state");

  //--------------------------------------------------------------------------
  // STATUS PULSE CAUSALITY
  //--------------------------------------------------------------------------

  ap_no_done_without_crc_completion:
    assert property (@(posedge clk) disable iff (!rst_n)
                     done |-> $past(state_crc &&
                                     tx_ready &&
                                     crc_last_i &&
                                     !abort))
    else $error("DONE asserted without CRC completion");

  ap_no_underrun_outside_data:
    assert property (@(posedge clk) disable iff (!rst_n)
                     underrun |-> $past(state_data &&
                                         !pld_valid &&
                                         !abort))
    else $error("UNDERRUN asserted without DATA starvation");

  ap_no_abort_pulse_without_busy_abort:
    assert property (@(posedge clk) disable iff (!rst_n)
                     aborted |-> $past(abort && !state_idle))
    else $error("ABORTED asserted without busy-state abort");

  //--------------------------------------------------------------------------
  // ENVIRONMENT ASSUMPTIONS
  //--------------------------------------------------------------------------

  as_ack_nyet_exclusive:
    assume property (@(posedge clk) disable iff (!rst_n)
                     !(ack_rcvd && nyet_rcvd));

  as_ack_pulse:
    assume property (@(posedge clk) disable iff (!rst_n)
                     ack_rcvd |=> !ack_rcvd);

  as_nyet_pulse:
    assume property (@(posedge clk) disable iff (!rst_n)
                     nyet_rcvd |=> !nyet_rcvd);

  as_toggle_clear_pulse:
    assume property (@(posedge clk) disable iff (!rst_n)
                     toggle_clr |=> !toggle_clr);

  as_valid_pid:
    assume property (@(posedge clk) disable iff (!rst_n)
                     req_fire_ok_i |->
                     sel_pid_i inside {
                       PID_DATA0, PID_DATA1,
                       PID_DATA2, PID_MDATA
                     });
*/
endmodule


//==============================================================================
// BIND
//==============================================================================
//
// Add this after the RTL modules are compiled:
//
 bind usb_data_tx_top
   usb_data_tx_top_sva #(
     .HS_SUPPORT(1'b0)
   ) u_usb_data_tx_top_sva (

// Named port connections based on the module interface
.clk                 ( clk                 ),
.rst_n               ( rst_n               ),

.req_valid           ( req_valid           ),
.req_ready           ( req_ready           ),
.req_use_int_toggle  ( req_use_int_toggle  ),
.req_toggle          ( req_toggle          ),
.req_force_data0     ( req_force_data0     ),
.req_type            ( req_type            ),
.ls_mode             ( ls_mode             ),
.hs_mode             ( hs_mode             ),
.req_dir_in          ( req_dir_in          ),
.req_mult            ( req_mult            ),
.req_tx_idx          ( req_tx_idx          ),
.req_length          ( req_length          ),
.cfg_max_pkt         ( cfg_max_pkt         ),
.abort               ( abort               ),

.pld_data            ( pld_data            ),
.pld_valid           ( pld_valid           ),
.pld_ready           ( pld_ready           ),

.tx_data             ( tx_data             ),
.tx_valid            ( tx_valid            ),
.tx_ready            ( tx_ready            ),
.tx_sop              ( tx_sop              ),
.tx_eop              ( tx_eop              ),
.pkt_active          ( pkt_active          ),

.ack_rcvd            ( ack_rcvd            ),
.nyet_rcvd           ( nyet_rcvd           ),
.toggle_clr          ( toggle_clr          ),
.ep_toggle           ( ep_toggle           ),
.ack_pending         ( ack_pending         ),

.done                ( done                ),
.err_req             ( err_req             ),
.aborted             ( aborted             ),
.underrun            ( underrun            ),
.crc_out             ( u_asm.crc_out       ),
.req_fire_ok         (u_gate.req_fire_ok   ),
.tx_bs_viol          (tx_bs_viol           ),
.sel_err             (sel_err              ),
.use_err             (u_asm.use_err        ),
.state               (u_asm.state          )
);    


//
// If your formal tool does not support .* on the bind instance,
// connect the top-level ports explicitly.
//
//==============================================================================

