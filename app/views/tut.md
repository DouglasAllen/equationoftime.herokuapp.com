## Tutorial


## &Delta; = ( &Mu; - &nu; ) + ( &lambda; - &alpha; )

The above reads:
delta = mu - nu + lambda - alpha    
true noon (solar transit of local meridian) and clock noon difference.
  
mu = Mean Solar Anomaly

nu = True Solar Anomaly  

lambda = Apparent Solar Longitude

alpha = Apparent Solar Right Ascension 
    
        
&nbsp;&nbsp;&nbsp;   The "Equation of Time" is a formula to align solar time with clock time. 
( see: Graph link above. ) So who would care if you don't use a sundial to find 
out the time?  When I first started to research this a few years ago that was not 
my intent.  I wanted to know how to calculate sunrise and sunset. My intent was 
to find or write a program that would do that because I got lazy about putting up 
and taking down the "Red, White, and Blue". You may just keep it up if it is 
displayed with a light at night. But then when to turn that light on and off?  
	
           
&nbsp;&nbsp;&nbsp;   I found a BASIC program written by a Canadian amateur radio operator.
It was kind of hard for me to get into it beacuse it's like what they call 
"spaghetti code" and I'm still not that adept with BASIC.  But it has nice 
graphics as a clock. I was able to modify it to use a serial port to switch the 
light on and off using a relay.  But the program is still not that accurate and 
I had to figure out when to turn that PC on and off or just leave it running. :D
   Well this might be a nice idea for an embedded device that uses less power but I 
don't want to deal with pattents and all so go ahead and please make one for us all. 
It might make a few bucks from the real patriotic malibu light lovers.  I eventually
opted for a light sensor circuit. Maybe I could ajust it to twilight for the pc.
         
        
&nbsp;&nbsp;&nbsp;   I found that the "Equation of Time" was needed to complete these calculations.
It all made sense when I realized that almost equal amounts of daylight 
from daybreak to noon and from noon to nightfall are used.  But when does 
"Noon" for my location actually occur?  Keep this in mind as you read further.


&nbsp;&nbsp;&nbsp;   Looking at the graph you'll see three wave forms.  The two dashed
wave forms sum together to form the solid red wave form.  Notice that one occurs
at two cycles of change.  This is the Ecliptic cycle.  It's caused by the tilt 
of the Earth spinning on its' axis making the Sun appear higher and lower in
the sky at different seasons.  Notice that it crosses zero at four times
a year.  You may be familiar with these times.  They are the Equinoxes of Spring and
Fall and Solstices of Summer and Winter.  Check the data for it at Data


&nbsp;&nbsp;&nbsp;   Again looking at the graph we see a one cycle wave form.  This is the Elliptic
cycle or sometimes called the orbital time change.  It's the Earth orbit around 
the Sun like all the other planets.  It shows how time is effected by the angle 
away from the Sun at different seasons due to an eliptical orbit. 
The Sun only crosses that imaginary Celestial Equator twice a year and is not a 
graph of time but of solar altitude.  You could trace it from time laps photos 
creating what is known as an Analemma.  There's a link about it at Links
http://www.analemma.com/.
	         

&nbsp;&nbsp;&nbsp;   Your longitude is needed first to calculate what is termed "Mean local noon".
If you are west of the Greenwich Prime Meridian then your longitude has a 
minus sign.  If you are east of the Greenwich Prime Meridian then your 
longitude has a positive sign.( not needed though )   
Longitude can be converted to a time by just dividing it by 15.0.      
Your longitude converted to time will tell you your Mean local noon time.
	
      
Example: You are at 75.324 degrees longitude west = -75.324

    ```ruby
    longitude = -75.342
    noon_utc = 12.0
    local_mean_noon = noon_utc - longitude / 15.0     
    local_mean_noon = "#{noon_utc - (longitude / 15.0)} (hours UTC)"
    # local_mean_noon = "#{12.0 - (-5.0228)} (hours UTC)"
    # local_mean_noon = "#{12.0 + 5.0228} (hours UTC)"
    # local_mean_noon = "17.0228 (hours UTC)"
    #=> "17.0228 (hours UTC)"	
                   
[Ruby code](/gist)


&nbsp;&nbsp;&nbsp;   UTC is the reference Time Zone throughout the world and so is often called
"zulu" time for the Zero time zone.      
The "Equation of Time" is then subtracted from your "Mean Noon Time".
This is what you may see at the top of the graph above but 
pay careful attention to the sign.  People often cunfuse this.
And time is more often not used but the difference in angle is.

      
Lets say that True - Mean = - 4 minutes and 40 seconds. ( -0.0777778 ) hr.
Example :
 
    ```ruby
    eot = -0.0777778
    local_mean_noon = 17.0228 #(hours UTC)
    local_noon = "#{local_mean_noon - eot} (hours UTC.)" 
    # local_noon = 17.0228 + 0.0777778 
    # local_noon = "17.1005778 (hours UTC.)"
    #=> "17.1005778 (hours UTC.)"
      
Note: This time is in decimal format.  You will have to convert it.


This will be the actual clock time of your "True Solar Transit Time".      
This time can then be converted to your time zone by adding your zone offset.
      
Example : 

 -5.0 if West or +5.0 if East of the Prime Meridian by 5 time zones.      
      
            
&nbsp;&nbsp;&nbsp;   Now we have a reasonable place to start if we wish to calculate the sunrise      
or sunset for your location.  It works for most locations except those at or 
past the arctic circles.  (+/- 90.0 degrees latitude).  
Note: Of course you will want to know your latitude as well when it comes to 
calculating rise and set times.

                  
&nbsp;&nbsp;&nbsp;   I have included methods in this Ruby gem to do exactly that. See below:
There are a couple of methods you can try out once you have the ajd set for the
date you require. Use eot.ajd = 'some ajd at noon time'
One method is eot.mean\_local\_noon\_jd and will give you the mean clock time for
solar transit if you entered your longitude via eot.longitude = 'your longitude'
The other is eot.local\_noon\_dt which yields the true solar transit time for your
location. It subtracts the equation of time from your mean noon time.
One quick note on the graph. It shows that clock time is fast or slow and not
how much time to add or subtract.

           
Please note: 

&nbsp;&nbsp;&nbsp;   The gem has undergone some major changes because of Ruby C Extensions.
I'll just add notes on each page about them and leave much of the original
information in tact.  Thank you for your interest in this gem.               
   

[Julian Numbers and DateTime](/datetime) live page explains about using them in Ruby                    

[Julian Century Fractional Time](/jcft) for use of datetime in angle calculations.    
                
[&Mu; Mean Anomaly](/mean) for use of mean anomaly calculations.                  

[&nu; True Anomaly](/eqc) for use of true anomaly calculations.

[ &lambda; Apparent Longitude](/ecliplong) for use of true longitude calculations.

[ &alpha; Right Ascension](/rghtascn) for use of right ascension calculations. 

[ &Delta; Time now](/eot) Live calculations of Equation of Time now.

[ Times](/mysuntimes) Live calculations of sunrise and sunset times today.                      

[ Links](/links) Some links that I learned more about the Equation of Time with plus.
