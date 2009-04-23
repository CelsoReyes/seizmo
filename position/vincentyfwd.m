function [stla,stlo,baz]=vincentyfwd(evla,evlo,dist,az,ellipsoid,tolerance)
%VINCENTYFWD    Find destination point on an ellipsoid relative to a point
%    
%    Description: [LAT2,LON2,BAZ]=VINCENTYFWD(LAT1,LON1,DIST,AZ) returns
%     geodetic latitudes LAT2 and longitudes LON2 of destination points, as
%     well as the backazimuths BAZ, given the distances DIST and forward
%     azimuths AZ from initial points with geodetic latitudes LAT1 and
%     longitudes LON1 on the WGS-84 reference ellipsoid.  Inputs are all in
%     degrees except DIST which must be in kilometers.  Outputs are all in
%     degrees.  LAT1 and LON1 must be scalar or nonempty same-size arrays
%     and DIST and AZ must be as well.  If multiple initial points and
%     distance-azimuths are given, all must be same size (1 initial point
%     per distance-azimuth).  A single initial point may be paired with
%     multiple distance-azimuths and multiple initial points may be paired
%     with a single distance-azimuth to make working with repetitive data
%     simpler.
%
%     VINCENTYFWD(LAT1,LON1,DIST,AZ,[A F]) allows specifying the
%     ellipsoid parameters A (equatorial radius in kilometers) and F
%     (flattening).  This is compatible with output from Matlab's Mapping
%     Toolbox function ALMANAC.  By default the ellipsoid parameters are
%     set to those of the WGS-84 reference ellipsoid.
%
%     VINCENTYFWD(LAT1,LON1,DIST,AZ,[A F],TOL) sets the tolerance (minimum
%     precision) of the calculation.  Units are in radians.  The default is
%     1e-12 (~0.01mm for the WGS-84 reference ellipsoid).
%
%    Notes:
%     - Destination points are found following the formulation of:
%        T. Vincenty (1975), Direct and Inverse Solutions of Geodesics on
%        the Ellipsoid with Application of Nested Equations, Survey Review,
%        Vol. XXII, No. 176, pp. 88-93.
%       and assume the reference ellipsoid WGS-84 unless another is given.
%     - Latitudes are geodetic (0 deg lat == equator, range -90<=lat<=90)
%     - Longitudes are returned in the range -180<lon<=180
%     - Azimuths are returned in the range 0<=az<=360
%
%    Tested on: Matlab r2007b
%
%    Usage:    [lat2,lon2,baz]=vincentyfwd(lat1,lon1,dist,az)
%              [lat2,lon2,baz]=vincentyfwd(lat1,lon1,dist,az,[a f])
%              [lat2,lon2,baz]=vincentyfwd(lat1,lon1,dist,az,[a f],tol)
%
%    Examples:
%     St. Louis, MO USA to ???:
%      [lat2,lon2,baz]=vincentyfwd(38.649,-90.305,5000,-30)
%
%    See also: vincentyinv, sphericalinv, sphericalfwd, haversine

%     Version History:
%        Oct. 14, 2008 - initial version
%        Oct. 26, 2008 - improved scalar expansion, allow specifying the
%                        tolerance, doc update
%        Apr. 23, 2009 - fix nargchk for octave
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Apr. 23, 2009 at 12:00 GMT

% todo:

% require 4 to 6 inputs
msg=nargchk(4,6,nargin);
if(~isempty(msg)); error(msg); end

% default - WGS-84 Reference Ellipsoid
if(nargin==4 || isempty(ellipsoid))
    % a=radius at equator (major axis)
    % f=flattening
    a=6378137.0;
    f=1/298.257223563;
else
    % manually specify ellipsoid (will accept almanac output)
    if(isnumeric(ellipsoid) && numel(ellipsoid)==2 && ellipsoid(2)<1)
        a=ellipsoid(1)*1000; % km=>m
        f=ellipsoid(2);
    else
        error('seizmo:vincentyfwd:badEllipsoid',...
            ['Ellipsoid must a 2 element vector specifying:\n'...
            '[equatorial_radius flattening(<1)]'])
    end
end

% default tolerances
if(any(nargin==[4 5]) || isempty(tolerance))
    % roughly 0.01mm
    tolerance=1e-12;
elseif(~isnumeric(tolerance) || numel(tolerance)>1)
    error('seizmo:vincentyfwd:badTolerance',...
        'Tolerance must be a scalar specifying precision in radians!');
elseif(any(tolerance<0) || any(tolerance>pi))
    error('seizmo:vincentyfwd:badTolerance',...
        'Tolerances must be in the range 0 to PI!');
end

% size up inputs
sz1=size(evla); sz2=size(evlo);
sz3=size(dist); sz4=size(az);
n1=prod(sz1); n2=prod(sz2);
n3=prod(sz3); n4=prod(sz4);

% basic check inputs
if(~isnumeric(evla) || ~isnumeric(evlo) ||...
        ~isnumeric(dist) || ~isnumeric(az))
    error('seizmo:vincentyfwd:nonNumeric','All inputs must be numeric!');
elseif(any([n1 n2 n3 n4]==0))
    error('seizmo:vincentyfwd:emptyLatLon',...
        'Location inputs must be nonempty arrays!');
end

% expand scalars
if(n1==1); evla=repmat(evla,sz2); n1=n2; sz1=sz2; end
if(n2==1); evlo=repmat(evlo,sz1); n2=n1; sz2=sz1; end
if(n3==1); stla=repmat(dist,sz4); n3=n4; sz3=sz4; end
if(n4==1); stlo=repmat(az,sz3); n4=n3; sz4=sz3; end

% cross check inputs
if(~isequal(sz1,sz2) || ~isequal(sz3,sz4) ||...
        (~any([n1 n3]==1) && ~isequal(sz1,sz3)))
    error('seizmo:vincentyfwd:nonscalarUnequalArrays',...
        'Input arrays need to be scalar or have equal size!');
end

% expand scalars
if(n2==1); evla=repmat(evla,sz3); evlo=repmat(evlo,sz3); end
if(n4==1); dist=repmat(stla,sz1); az=repmat(stlo,sz1); end

% number of pairs
n=size(evla);

% check lats are within -90 to 90 (Geodetic Latitude φ)
if(any(abs(evla)>90))
    error('seizmo:vincentyfwd:latitudeOutOfRange',...
        'Starting latitude out of range (-90 to 90)');
end

% force lon 0 to 360
evlo=mod(evlo,360);

% conversion constants
R2D=180/pi;
D2R=pi/180;

% convert to radians
az=az.*D2R;

% convert to meters
dist=dist.*1000;

% reduced latitude
tanU1=(1-f).*tan(evla.*D2R);
cosU1=1./sqrt(1+tanU1.^2);
sinU1=tanU1.*cosU1;

% various ellipsoid measures
b=a-a*f;
b2=b^2;
a2=a^2;

% setup
sinalpha1=sin(az); cosalpha1=cos(az);
sigma1=atan2(tanU1,cosalpha1);
sinalpha=cosU1.*sinalpha1;
sin2alpha=sinalpha.^2;
cos2alpha=1-sin2alpha;
u2=cos2alpha.*(a2-b2)./b2;
A=1+u2./16384.*(4096+u2.*(-768+u2.*(320-175.*u2)));
B=u2./1024.*(256+u2.*(-128+u2.*(74-47.*u2)));

% iterate until sigma converges
left=true(n); cos2sigmam=nan(n); deltasigma=nan(n);
sigma=dist./(b.*A); sigmaprime=2*pi*ones(n);
while (any(left)) % forces at least one iteration
    cos2sigmam(left)=cos(2.*sigma1(left)+sigma(left));
    deltasigma(left)=B(left).*sin(sigma(left)).*(cos2sigmam(left)...
        +B(left)./4.*(cos(sigma(left)).*(-1+2.*cos2sigmam(left).^2)...
        -B(left)./6.*cos2sigmam(left).*(-3+4.*sin(sigma(left)).^2)...
        .*(-3+4.*cos2sigmam(left).^2)));
    sigmaprime(left)=sigma(left);
    sigma(left)=dist(left)./(b.*A(left))+deltasigma(left);
    left(left)=abs(sigma(left)-sigmaprime(left))>tolerance;
end

% get destination point
cossigma=cos(sigma); sinsigma=sin(sigma); cos2sigmam=cos(2.*sigma1+sigma);
stla=R2D.*atan2(sinU1.*cossigma+cosU1.*sinsigma.*cosalpha1,...
    (1-f).*sqrt(sin2alpha+(sinU1.*sinsigma...
    -cosU1.*cossigma.*cosalpha1).^2));
lambda=atan2(sinsigma.*sinalpha1,...
    cosU1.*cossigma-sinU1.*sinsigma.*cosalpha1);
C=f./16.*cos2alpha.*(4+f.*(4-3.*cos2alpha));
L=lambda-(1-C).*f.*sinalpha.*(sigma+C.*sinsigma.*(cos2sigmam+...
    C.*cossigma.*(-1+2.*cos2sigmam.^2)));
stlo=mod(evlo+L*R2D,360);
stlo(stlo>180)=stlo(stlo>180)-360;

% get backazimuth
baz=mod(180+...
    R2D.*atan2(sinalpha,-sinU1.*sinsigma+cosU1.*cossigma.*cosalpha1),360);

end
