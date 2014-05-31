// $Id: BaseStationP.nc,v 1.10 2008/06/23 20:25:14 regehr Exp $

/*									tab:4
 * "Copyright (c) 2000-2005 The Regents of the University  of California.  
 * All rights reserved.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose, without fee, and without written agreement is
 * hereby granted, provided that the above copyright notice, the following
 * two paragraphs and the author appear in all copies of this software.
 * 
 * IN NO EVENT SHALL THE UNIVERSITY OF CALIFORNIA BE LIABLE TO ANY PARTY FOR
 * DIRECT, INDIRECT, SPECIAL, INCIDENTAL, OR CONSEQUENTIAL DAMAGES ARISING OUT
 * OF THE USE OF THIS SOFTWARE AND ITS DOCUMENTATION, EVEN IF THE UNIVERSITY OF
 * CALIFORNIA HAS BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 * 
 * THE UNIVERSITY OF CALIFORNIA SPECIFICALLY DISCLAIMS ANY WARRANTIES,
 * INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS FOR A PARTICULAR PURPOSE.  THE SOFTWARE PROVIDED HEREUNDER IS
 * ON AN "AS IS" BASIS, AND THE UNIVERSITY OF CALIFORNIA HAS NO OBLIGATION TO
 * PROVIDE MAINTENANCE, SUPPORT, UPDATES, ENHANCEMENTS, OR MODIFICATIONS."
 *
 * Copyright (c) 2002-2005 Intel Corporation
 * All rights reserved.
 *
 * This file is distributed under the terms in the attached INTEL-LICENSE     
 * file. If you do not find these files, copies can be found by writing to
 * Intel Research Berkeley, 2150 Shattuck Avenue, Suite 1300, Berkeley, CA, 
 * 94704.  Attention:  Intel License Inquiry.
 */

/*
 * @author Phil Buonadonna
 * @author Gilman Tolle
 * @author David Gay
 * Revision:	$Id: BaseStationP.nc,v 1.10 2008/06/23 20:25:14 regehr Exp $
 */
  
/* 
 * BaseStationP bridges packets between a serial channel and the radio.
 * Messages moving from serial to radio will be tagged with the group
 * ID compiled into the TOSBase, and messages moving from radio to
 * serial will be filtered by that same group id.
 */

#include "AM.h"
#include "Serial.h"

module TransmitterC @safe() {
  uses {
    interface Boot;

	interface Timer<TMilli>;
	interface Leds;
	interface HplMsp430GeneralIO as Pin3;
	interface SplitControl as RadioControl;
	interface Packet;
  	interface AMPacket;
  	interface AMSend;		

  }
}
/* In non error mode the following Led toggles:
 * Led 0 toggles in the following cases: 
 * 		Counter is incremented
 * Led 1:
 * 		ON if the radio is on
 * 		OFF if the radio is off
 * Led 2 
 * 		ON between beginning send of a message and done sending of a message
 * 		OFF otherwise
 * 
 * 
 * In error mode the following LED toggles:
 * Led 0 toggles in the following cases: 
 * 		RadioControl.startDone != SUCCESS 
 * 		RadioControl.start != SUCCESS
 * Led 1 toggles in the following cases:
 * 		RadioControl.stopDone != SUCCESS
 * 		RadioControl.stop() != SUCCES
 * Led 2 toggles in the following cases:
 * 		AMSend.send != SUCCESS
 * 		AMSend.sendDone != SUCCESS
 */

implementation
{
	int prime1 = 7;
	int prime2 = 17;
	int counter = 0;
	nx_uint16_t currentPrime;
	bool radioStarted = FALSE;
	bool turnOffRadio = FALSE;
	bool ledsOn = FALSE;

	bool ledErrorMode = FALSE;
	
	bool sendBusy = FALSE;
	message_t msgmst;
	
	typedef nx_struct DiscoMsg {
  	nx_uint16_t prime;
	} DiscoMsg;

  void startTimer() {
    call Timer.startPeriodic(256);
  }
     
  void turnRadioOff()
  {
	if (call RadioControl.stop() != SUCCESS)
		if(ledErrorMode && ledsOn)
			call Leds.led1On();
  }
  
	event void RadioControl.stopDone(error_t error) 
	{
  		if(error != SUCCESS)
  			if(ledErrorMode && ledsOn)
				call Leds.led1On();
				
  		if(!ledErrorMode && ledsOn)
  			call Leds.led1Off();
  		radioStarted = FALSE;
  	}

  //Transmits the current prime number
  void transmitMsg()
  {
  	DiscoMsg* msgPtr = (DiscoMsg*)(call Packet.getPayload(&msgmst, sizeof (DiscoMsg)));
    msgPtr->prime = currentPrime;
    if(!ledErrorMode && ledsOn)
    	call Leds.led2On();
    if (call AMSend.send(AM_BROADCAST_ADDR, &msgmst, sizeof(DiscoMsg)) == SUCCESS) 
    {
      sendBusy = TRUE;
    }
    else
    {
    	if(ledErrorMode && ledsOn)
			call Leds.led2Toggle();
    }    	
  }

  event void AMSend.sendDone(message_t* msg, error_t error) 
  {
  	if(!ledErrorMode && ledsOn)
  	call Leds.led2Off();
  		
  	if(turnOffRadio)
  	{
  		turnRadioOff();
  		turnOffRadio = FALSE;
  	}
  		
  	if(error != SUCCESS)
  		if(ledErrorMode && ledsOn)
			call Leds.led2Toggle();
  	

  		
    if (&msgmst == msg) {
      sendBusy = FALSE;
    }
  }
 
	//Transmits a message
  event void RadioControl.startDone(error_t error) 
  {
  	if(error != SUCCESS)
  		if(ledErrorMode && ledsOn)
			call Leds.led0Toggle();
	if(!ledErrorMode && ledsOn)
  		call Leds.led1On();
  		
  	radioStarted = TRUE;
  	transmitMsg();  			
  }
	
  event void Boot.booted() {
    startTimer();
  }

  event void Timer.fired() 
  {
	counter++;
	if(!ledErrorMode && ledsOn)
		call Leds.led0Toggle();

	if(radioStarted)
	{
		call Pin3.clr();
		
		//By setting turnOffRadio to 1 the radio is turned off when the message is transmitted.
		turnOffRadio = TRUE;	
		transmitMsg();
	}
	else
	{
		if(counter % prime1 == 0 || counter % prime2 == 0)
		{
			currentPrime = prime1;
			if(counter % prime2 == 0)
				currentPrime = prime2;
				
			call Pin3.set();
			// Wakeup radio. It automatically invokes transmitMsg
			if (call RadioControl.start() != SUCCESS)
				if(ledErrorMode && ledsOn)
					call Leds.led0Toggle();			 
		} 
	}
  }
}