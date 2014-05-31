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

module ListenerC @safe() {
  uses {
    interface Boot;
    interface SplitControl as RadioControl;
	interface Timer<TMilli>;
	interface HplMsp430GeneralIO as Pin3;
    interface Leds;
    
    interface Receive;
  }
}
/*
 * In non error mode the following Led toggles:
 * Led 0 toggles in the following cases: 
 * 		Counter is incremented
 * Led 1:
 * 		ON if the radio is on
 * 		OFF if the radio is off
 * Led 2 toggles in the following cases:
 * 		Prime is 7
 * 		Prime is 17
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
 * 		Prime is 7
 * 		Prime is 17
 */
implementation
{
  int prime1 = 5;
  int prime2 = 19;
  int counter = 0;
  bool radioStarted = FALSE;
  bool ledErrorMode = FALSE;
  bool ledsOn = FALSE;
  
	typedef nx_struct DiscoMsg {
  	nx_uint16_t prime;
	} DiscoMsg;

  void startTimer() {
    call Timer.startPeriodic(256);
  }
  event void Boot.booted() {
    startTimer();
  }
  
  event void RadioControl.startDone(error_t error) {
  	if(error != SUCCESS)
  		if(ledErrorMode && ledsOn)
  			call Leds.led0Toggle();
  	  
  	  if(!ledErrorMode && ledsOn)
  			call Leds.led1On();
  	radioStarted = TRUE;
  }
  
    event void RadioControl.stopDone(error_t error) {
  		if(error != SUCCESS)
  			if(ledErrorMode && ledsOn)
  				call Leds.led1Toggle();
  		if(!ledErrorMode && ledsOn)
  			call Leds.led1Off();
  		radioStarted = FALSE;
  	}
  
  event void Timer.fired() 
  {
	counter++;
	if(!ledErrorMode && ledsOn)
		call Leds.led0Toggle();

	if(radioStarted)
	{
		call Pin3.clr();
		
		if (call RadioControl.stop() != SUCCESS)
				if(ledErrorMode && ledsOn)
					call Leds.led1Toggle();	
	}
	else
	{
		if(counter % prime1 == 0 || counter % prime2 == 0)
		{
			// Wakeup radio
			if (call RadioControl.start() != SUCCESS)
				if(ledErrorMode && ledsOn)
					call Leds.led0Toggle();			 
		} 
	}
  }
  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
	  if (len == sizeof(DiscoMsg)) {
	    DiscoMsg* msgPtr = (DiscoMsg*)payload;
	    uint16_t prime = msgPtr->prime;
	    if(prime == 7 || prime == 17)
	    {
	    	if(!ledErrorMode && ledsOn)
	    		call Leds.led2Toggle();
	    	call Pin3.set();
	    }
	  }

  return msg;
}
}