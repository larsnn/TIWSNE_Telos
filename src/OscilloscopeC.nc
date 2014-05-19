/*
 * Copyright (c) 2006 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

/**
 * Oscilloscope demo application. See README.txt file in this directory.
 *
 * @author David Gay
 */
#include "Timer.h"
#include "Oscilloscope.h"

module OscilloscopeC @safe()
{
  uses {
    interface Boot;
    interface SplitControl as RadioControl;
    interface AMSend;
    interface Receive;
    interface Timer<TMilli>;
    interface Read<uint16_t>;
    interface Leds;
  }
}
implementation
{
  message_t sendBuf;
  bool sendBusy;
  int prime1 = 5;
  int prime2 = 19;
  int counter = 0;
  bool radioStarted = 0;

  /* Current local state - interval, version and accumulated readings */
  oscilloscope_t local;

  uint8_t reading; /* 0 to NREADINGS */

  /* When we head an Oscilloscope message, we check it's sample count. If
     it's ahead of ours, we "jump" forwards (set our count to the received
     count). However, we must then suppress our next count increment. This
     is a very simple form of "time" synchronization (for an abstract
     notion of time). */
  bool suppressCountChange;

  // Use LEDs to report various status issues.
  void report_problem() { call Leds.led0Toggle(); }
  void report_sent() { call Leds.led1Toggle(); }
  void report_received() { call Leds.led2Toggle(); }

  event void Boot.booted() {
    local.interval = DEFAULT_INTERVAL;
    local.id = TOS_NODE_ID;
    if (call RadioControl.start() != SUCCESS)
      report_problem();
  }

  void startTimer() {
    call Timer.startPeriodic(local.interval);
    reading = 0;
  }

  event void RadioControl.startDone(error_t error) {
  	radioStarted = 1;
  	call Leds.led0On();
  	
    startTimer();
    
    if (call RadioControl.stop() != SUCCESS)
    	report_problem();
  }

  event void RadioControl.stopDone(error_t error) {
  	call Leds.led0Off();
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    oscilloscope_t *omsg = payload;

    report_received();

    /* If we receive a newer version, update our interval. 
       If we hear from a future count, jump ahead but suppress our own change
    */
    if (omsg->version > local.version)
      {
	local.version = omsg->version;
	local.interval = omsg->interval;
	startTimer();
      }
    if (omsg->count > local.count)
      {
	local.count = omsg->count;
	suppressCountChange = TRUE;
      }

    return msg;
  }

  /* At each sample period:
     - if local sample buffer is full, send accumulated samples
     - read next sample
  */
  event void Timer.fired() 
  {
	counter++;
	call Leds.led1Toggle();

	if(radioStarted)
	{
		call Leds.led2Off();
		local.readings[0] = 11;      
	
		if (!sendBusy && sizeof local <= call AMSend.maxPayloadLength())
		{
			// Don't need to check for null because we've already checked length
			// above
			memcpy(call AMSend.getPayload(&sendBuf, sizeof(local)), &local, sizeof local);
			if (call AMSend.send(AM_BROADCAST_ADDR, &sendBuf, sizeof local) == SUCCESS)
			  sendBusy = TRUE;
		 }
		if (!sendBusy)
			report_problem();
		if (call RadioControl.stop() != SUCCESS)
				report_problem();
		radioStarted = 0;		
	}
	else
	{
		if(counter % prime1 == 0 || counter % prime2 == 0)
		{
			call Leds.led2On();
			// Wakeup radio and send message
		   if (call RadioControl.start() != SUCCESS)
				report_problem();
				
			local.readings[0] = 10;      
		
			if (!sendBusy && sizeof local <= call AMSend.maxPayloadLength())
			{
				// Don't need to check for null because we've already checked length above
				memcpy(call AMSend.getPayload(&sendBuf, sizeof(local)), &local, sizeof local);
				if (call AMSend.send(AM_BROADCAST_ADDR, &sendBuf, sizeof local) == SUCCESS)
				  sendBusy = TRUE;
			 }
			 if (!sendBusy)
				report_problem();
			 */
		} 
	}
  }

  event void AMSend.sendDone(message_t* msg, error_t error) {
    if (error == SUCCESS)
      report_sent();
    else
      report_problem();

    sendBusy = FALSE;
  }

  event void Read.readDone(error_t result, uint16_t data) {
    if (result != SUCCESS)
      {
	data = 0xffff;
	report_problem();
      }
    local.readings[reading++] = data;
  }
}
