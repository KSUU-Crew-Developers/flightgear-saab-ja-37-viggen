#
# Methods that is used across multiple displays (HUD, radarscreen, MI, TI)
#
var TAKEOFF = 0;
var NAV = 1;
var COMBAT =2;
var LANDING = 3;

var FALSE = 0;
var TRUE = 1;

var METRIC = 1;
var IMPERIAL = 0;

var clamp = func(v, min, max) { v < min ? min : v > max ? max : v }

# -100 - 0 : not blinking
# 1 - 10   : blinking
# 11 - 125 : steady on
var countQFE = 0;

var Common = {

	new: func {
	  	var co = { parents: [Common] };
	  	co.input = {
			speed_d:          "velocities/speed-down-fps",
	        speed_e:          "velocities/speed-east-fps",
	        speed_n:          "velocities/speed-north-fps",
	        mach:             "instrumentation/airspeed-indicator/indicated-mach",
	        gearsPos:         "gear/gear/position-norm",
	        wow0:             "fdm/jsbsim/gear/unit[0]/WOW",
	        wow1:             "fdm/jsbsim/gear/unit[1]/WOW",
	        wow2:             "fdm/jsbsim/gear/unit[2]/WOW",
	        dev:              "dev",
	        combat:           "ja37/hud/combat",
	        landingMode:      "ja37/hud/landing-mode",
	        currentMode:      "ja37/hud/current-mode",
	        elapsedSec:       "sim/time/elapsed-sec",

	        qfeActive:        "ja37/displays/qfe-active",
	        qfeShown:		  "ja37/displays/qfe-shown",
	        altCalibrated:    "ja37/avionics/altimeters-calibrated",
	        alt_ft:           "instrumentation/altimeter/indicated-altitude-ft",
	        ctrlRadar:        "controls/altimeter-radar",
	        units:            "ja37/hud/units-metric",
	        fiveHz:           "ja37/blink/five-Hz/state",
	        rad_alt:          "position/altitude-agl-ft",

	        station:          "controls/armament/station-select",
      	};
   
      	foreach(var name; keys(co.input)) {
        	co.input[name] = props.globals.getNode(co.input[name], 1);
      	}

      	co.mode = TAKEOFF;
      	co.modeTimeTakeoff = -1;
      	co.currArmName = "None";

      	return co;
	},

	loop: func {
		me.displayMode();
		me.QFE();
		me.armName();
		settimer(func me.loop(), 0.05);
	},

	armName: func {
		  me.armSelect = me.input.station.getValue();
	      if (me.armSelect > 0) {
	        me.armament = getprop("payload/weight["~ (me.armSelect-1) ~"]/selected");
	      } else {
	        me.armament = "";
	      }
	      if(me.armSelect == 0) {
	        me.currArmName = "AKAN";	        
	      } elsif(me.armament == "RB 24 Sidewinder") {
	        me.currArmName = "RB-24";	        
	      } elsif(me.armament == "RB 24J Sidewinder") {
	        me.currArmName = "RB-24J";	        
	      } elsif(me.armament == "RB 74 Sidewinder") {
	        me.currArmName = "RB-74";	        
	      } elsif(me.armament == "M70 ARAK") {
	        me.currArmName = "M70 ARAK";	        
	      } elsif(me.armament == "RB 71 Skyflash") {
	        me.currArmName = "RB-71";	        
	      } elsif(me.armament == "RB 99 Amraam") {
	        me.currArmName = "RB-99";	        
	      } elsif(me.armament == "RB 15F Attackrobot") {
	        me.currArmName = "RB-15F";	        
	      } elsif(me.armament == "RB 04E Attackrobot") {
	        me.currArmName = "RB-04E";	        
	      } elsif(me.armament == "RB 05A Attackrobot") {
	        me.currArmName = "RB-05A";	        
	      } elsif(me.armament == "RB 75 Maverick") {
	        me.currArmName = "RB-75";	        
	      } elsif(me.armament == "M71 Bomblavett") {
	        me.currArmName = "M71";	        
	      } elsif(me.armament == "M71 Bomblavett (Retarded)") {
	        me.currArmName = "M71R";	        
	      } elsif(me.armament == "M90 Bombkapsel") {
	        me.currArmName = "M90";	        
	      } elsif(me.armament == "M55 AKAN") {
	        me.currArmName = "M55 AKAN";	        
	      } elsif(me.armament == "TEST") {
	        me.currArmName = "TEST";	        
	      } else {
	        me.currArmName = "None";	        
	      }
	},

	displayMode: func {
		if (me.input.mach.getValue() != nil) {
		    me.hasRotated = FALSE;
		    if (me.input.mach.getValue() > 0.1) {
		      # we are moving, calc the flight path angle
		      me.vel_gh = math.sqrt(me.input.speed_n.getValue()*me.input.speed_n.getValue()+me.input.speed_e.getValue()*me.input.speed_e.getValue());
		      me.vel_gv = -me.input.speed_d.getValue();
		      me.hasRotated = math.atan2(me.vel_gv, me.vel_gh)*R2D > 3;
		    }
		    me.takeoffForbidden = me.hasRotated or me.input.mach.getValue() > 0.35 or me.input.gearsPos.getValue() != 1;
		    if(me.mode!= TAKEOFF and !me.takeoffForbidden and me.input.wow0.getValue() == TRUE and me.input.dev.getValue() != TRUE) {
		      # nosewheel touch runway, so we switch to TAKEOFF
		      me.mode= TAKEOFF;
		      me.modeTimeTakeoff = -1;
		    } elsif (me.input.dev.getValue() == TRUE and me.input.combat.getValue() == 1) {
		      # developer me.modeis active with tactical request, so we switch to COMBAT
		      me.mode= COMBAT;
		      me.modeTimeTakeoff = -1;
		    } elsif (me.mode== TAKEOFF and me.modeTimeTakeoff == -1 and me.input.wow0.getValue() == FALSE) {
		      # Nosewheel lifted off, so we start the 4 second counter
		      me.modeTimeTakeoff = me.input.elapsedSec.getValue();
		    } elsif (me.modeTimeTakeoff != -1 and me.input.elapsedSec.getValue() - me.modeTimeTakeoff > 4) {
		      if (me.takeoffForbidden == TRUE) {
		        # time to switch away from TAKEOFF mode.
		        if (me.input.gearsPos.getValue() == 1 or me.input.landingMode.getValue() == TRUE) {
		          me.mode= LANDING;
		        } else {
		          me.mode= me.input.combat.getValue() == 1 ? COMBAT : NAV;
		        }
		        me.modeTimeTakeoff = -1;
		      } else {
		        # 4 second has passed since frontgear touched runway, but conditions to switch from TAKEOFF has still not been met.
		        me.mode= TAKEOFF;
		      }
		    } elsif ((me.mode== COMBAT or me.mode== NAV) and (me.input.gearsPos.getValue() == 1 or me.input.landingMode.getValue() == TRUE)) {
		      # Switch to LANDING
		      me.mode= LANDING;
		      me.modeTimeTakeoff = -1;
		    } elsif (me.mode== COMBAT or me.mode== NAV) {
		      # determine if we should have COMBAT or NAV
		      me.mode= me.input.combat.getValue() == 1 ? COMBAT : NAV;
		      me.modeTimeTakeoff = -1;
		    } elsif (me.mode== LANDING and me.input.gearsPos.getValue() == 0 and me.input.landingMode.getValue() == FALSE) {
		      # switch from LANDING to COMBAT/NAV
		      me.mode= me.input.combat.getValue() == 1 ? COMBAT : NAV;
		      me.modeTimeTakeoff = -1;
		    }
		    me.input.currentMode.setIntValue(me.mode);
		}
    },

    QFE: func {
    	if (me.input.alt_ft.getValue() != nil) {
	    	me.metric = me.input.units.getValue();
	    	var alt = me.metric == METRIC ? me.input.alt_ft.getValue() * FT2M : me.input.alt_ft.getValue();
	    	var radAlt = me.input.ctrlRadar.getValue() == 1?(me.metric == METRIC ? me.input.rad_alt.getValue() * FT2M : me.input.rad_alt.getValue()):nil;

	    	me.radar_clamp = me.metric == METRIC ? 100 : 100/FT2M;
		    me.alt_diff = me.metric == METRIC ? 7 : 7/FT2M;
		    me.INT = FALSE;

		    if (radAlt == nil and me.input.ctrlRadar.getValue() == 1) {
		      # Radar alt instrument not initialized yet
		      countQFE = 0;
		      me.input.altCalibrated.setBoolValue(FALSE);
		    } elsif (radAlt != nil and radAlt < me.radar_clamp) {
		      # check for QFE warning
		      me.diff = radAlt - alt;
		      if (countQFE == 0 and (me.diff > me.alt_diff or me.diff < -me.alt_diff)) {
		        #print("QFE warning " ~ countQFE);
		        # is not calibrated, and is not blinking
		        me.input.altCalibrated.setBoolValue(FALSE);
		        countQFE = 1;     
		        #print("QFE not calibrated, and is not blinking");     
		      } elsif (me.diff > -me.alt_diff and me.diff < me.alt_diff) {
		          #is calibrated
		        if (me.input.altCalibrated.getValue() == FALSE and countQFE < 11) {
		          # was not calibrated before, is now.
		          #print("QFE was not calibrated before, is now. "~countQFE);
		          countQFE = 11;
		        }
		        me.input.altCalibrated.setBoolValue(TRUE);
		      } elsif (me.input.altCalibrated.getValue() == 1 and (me.diff > me.alt_diff or me.diff < -me.alt_diff)) {
		        # was calibrated before, is not anymore.
		        #print("QFE was calibrated before, is not anymore. "~countQFE);
		        countQFE = 1;
		        me.input.altCalibrated.setBoolValue(FALSE);
		      }
		    } else {
		      # is above height for checking for calibration
		      countQFE = 0;
		      #QFE = 0;
		      me.input.altCalibrated.setBoolValue(TRUE);
		      #print("QFE not calibrated, and is not blinking");
		    }

		    if (countQFE > 0) {
				# QFE is shown
				me.input.qfeActive.setBoolValue(TRUE);
				if(countQFE == 1) {
					countQFE = 2;
				}
				if(countQFE < 10) {
					# blink the QFE
					if(me.input.fiveHz.getValue() == TRUE) {
					  me.input.qfeShown.setBoolValue(TRUE);
					} else {
					  me.input.qfeShown.setBoolValue(FALSE);
					}
				} elsif (countQFE == 10) {
					#if(me.input.ias.getValue() < 10) {
					  # adjust the altimeter (commented out after placing altimeter in plane)
					  # var inhg = getprop("systems/static/pressure-inhg");
					  #setprop("instrumentation/altimeter/setting-inhg", inhg);
					 # countQFE = 11;
					  #print("QFE adjusted " ~ inhg);
					#} else {
					  countQFE = -100;
					#}
				} elsif (countQFE < 125) {
					# QFE is steady
					countQFE = countQFE + 1;
					me.input.qfeShown.setBoolValue(TRUE);
					#print("steady on");
				} else {
					countQFE = -100;
					me.input.altCalibrated.setBoolValue(TRUE);
					#print("off");
				}
		    } else {
		      me.input.qfeActive.setBoolValue(FALSE);
		      countQFE = clamp(countQFE+1, -101, 0);
		      #print("hide  off");
		    }
		    #print("QFE count " ~ countQFE);
		}
    },
};

var common = Common.new();
common.loop();