#include "helio.h"

/* Mean geocentric longitude of the Sun */
double mlSun(double t)
{
  double a;
  
  a = fmod(      280.4664567    +
  t * (        36000.76982779   +
  t * (            0.0003032028 +
  t * (   1.0/499310.0          +
  t * (  1.0/-152990.0          +
  t * (1.0/-19880000.0 ) ) ) ) ), 360.0 ) * 0.017453292519943295769236907684886;

  return a;
}

/* Eccentricity of Earth orbit */
double eoe(double t)
{
  double e;

  e = (0.016708617 + t * (-0.000042037 + t *  -0.0000001235));

  return e; 
}

double eqc(double ma, double t)
{             
  double a1, a2, a3, a4, a5, s1, s2, s3, s4, s5, e;
  e   = eoe(t);  
  s1  = sin( 1.0 * ma );
  s2  = sin( 2.0 * ma );
  s3  = sin( 3.0 * ma );
  s4  = sin( 4.0 * ma );
  s5  = sin( 5.0 * ma );
  a1  = s1 * 2;
  a2  = s2 * 5.0/4.0;
  a3  = s3 * 13.0/12.0 - s1 * 1.0/4.0;
  a4  = s4 * 103.0/96.0 - s2 * 11.0/24.0;
  a5  = s5 * 1097.0/960.0 + s1 * 5.0/96.0 - s3 * 43.0/64.0;
  /* Equation of Center */
  //a =  s1 * (e  *    2.0      - e3 * 1.0/4.0 + e5 *  5.0/96.0) +
  //     s2 * (e2 *    5.0/4.0  - 0.0          - e4 * 11.0/24.0) + 
  //     s3 * (e3 *   13.0/12.0 - 0.0          - e5 * 43.0/64.0) +
  //     s4 *  e4 *  103.0/96.0                                  +
  //     s5 *  e5 * 1097.0/960.0; 
  return e * (a1 + e * (a2 + e * (a3 + e * (a4 + e * a5))));
}

double tlSun(double ma, double t)
{
  double a;

  a = fmod( mlSun(t) + eqc(ma, t), 57.295779513082320876798154814105);

  return a;
}

double alSun(double ma, double t, double o)
{
  double a;

  a = fmod(tlSun(ma, t) - 
           0.00569 * 0.017453292519943295769236907684886 - 
           0.00478 * 0.017453292519943295769236907684886 * 
           sin(o), 57.295779513082320876798154814105);

  return a;
}

double raSun(double y0, double cos_al_Sun)
{
  return atan2(-y0, -cos_al_Sun);
}

double cosZ(double zenith)
{

  double ca;

  ca = cos(zenith * 0.017453292519943295769236907684886);

  return ca;
}

double cos_al_sun(double al_sun) 
{

  double ca;

  ca = cos(al_sun);

  return ca;
}

double cos_dec_sun(double dec_sun) 
{

  double ca;

  ca = cos(dec_sun);

  return ca;
} 

double cos_lat(double lat) 
{

  double ca;

  ca = cos(lat * 0.017453292519943295769236907684886);

  return ca;
}                                   

double cos_tl_sun(double tl_sun) 
{

  double ca;

  ca = cos(tl_sun);

  return ca;
}                                               

double cos_to_earth(double to_earth) 
{

  double ca;

  ca = cos(to_earth);

  return ca;
} 

double sin_al_sun(double al_sun) 
{

  double sa;

  sa = sin(al_sun);

  return sa;
}

double sin_dec_sun(double dec_sun) 
{

  double sa;

  sa = sin(dec_sun);

  return sa;
}  

double sin_lat(double lat) 
{

  double sa;

  sa = sin(lat * 0.017453292519943295769236907684886);

  return sa;
}                                   

double sin_tl_sun(double tl_sun) 
{

  double sa;

  sa = sin(tl_sun);

  return sa;
}                                               

double sin_to_earth(double to_earth) 
{

  double sa;

  sa = sin(to_earth);

  return sa;
} 

double sun(double zenith, double dec_sun, double lat)
{
  double cos1 = cosZ(zenith);
  double sin2 = sin_dec_sun(dec_sun);
  double sin3 = sin_lat(lat);
  double cos2 = cos_dec_sun(dec_sun);
  double cos3 = cos_lat(lat);
  double top  = cos1 - sin2 * sin3;
  double bot  = cos2 * cos3;
  double ca   = top / bot;
  double c;
  c = (ca > 1.0 || ca < -1.0) ? 1.0: ca;    
  return acos(c);
}

double sun_dec(double al_sun, double to_earth) 
{
  double sin1 = sin_to_earth(to_earth);
  double sin2 = sin_al_sun(al_sun);
  double a   = asin(sin1 * sin2);
  return a;
}
//                                                       
