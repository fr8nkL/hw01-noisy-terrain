#version 300 es
precision highp float;

uniform vec2 u_PlanePos; // Our location in the virtual world displayed by the plane

in vec3 fs_Pos;
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;

in float frag_FBM;
in float frag_Height;
in float frag_Temp;
in float frag_Moisture;

out vec4 out_Col; // This is the final output color that you will see on your
// screen for the pixel that is currently being processed.


float random1( float p , float seed) {
  return fract(sin((p + seed) * 420.69) * 43758.5453);
}

float random1( vec2 p , vec2 seed) {
  return fract(sin(dot(p + seed,vec2(127.1,311.7)))*43758.5453);
}

float random1( vec3 p, vec3 seed ) {
  return fract(sin(dot(p + seed, vec3(127.1, 311.7, 191.999))) * 43758.5453);
}

vec2 random2( vec2 p , vec2 seed) {
  return fract(sin(vec2(dot(p + seed,vec2(127.1,311.7)),dot(p + seed, vec2(269.5,183.3))))*43758.5453);
}

vec3 random3( vec3 p, vec3 seed ) {
  return fract(sin(vec3(dot(p + seed, vec3(127.1, 311.7, 191.999)),
  dot(p + seed,vec3(269.5, 183.3, 765.54)),
  dot(p + seed, vec3(420.69, 631.2,109.21))))
  *43758.5453);
}

float mySmootherStep(float a, float b, float t) {
  t = t*t*t*(t*(t*6.0 - 15.0) + 10.0);
  return mix(a, b, t);
}

float interpNoise2D1(vec2 uv, vec2 seed) {
  vec2 uvFract = fract(uv);
  float ll = random1(floor(uv), seed);
  float lr = random1(floor(uv) + vec2(1.0,0.0), seed);
  float ul = random1(floor(uv) + vec2(0.0,1.0), seed);
  float ur = random1(floor(uv) + vec2(1.0,1.0), seed);

  float lerpXL = mySmootherStep(ll, lr, uvFract.x);
  float lerpXU = mySmootherStep(ul, ur, uvFract.x);

  return mySmootherStep(lerpXL, lerpXU, uvFract.y);
}

float interpNoise3D1(vec3 p, vec3 seed) {
  vec3 pFract = fract(p);
  float llb = random1(floor(p), seed);
  float lrb = random1(floor(p) + vec3(1.0,0.0,0.0), seed);
  float ulb = random1(floor(p) + vec3(0.0,1.0,0.0), seed);
  float urb = random1(floor(p) + vec3(1.0,1.0,0.0), seed);

  float llf = random1(floor(p) + vec3(0.0,0.0,1.0), seed);
  float lrf = random1(floor(p) + vec3(1.0,0.0,1.0), seed);
  float ulf = random1(floor(p) + vec3(0.0,1.0,1.0), seed);
  float urf = random1(floor(p) + vec3(1.0,1.0,1.0), seed);

  float lerpXLB = mySmootherStep(llb, lrb, pFract.x);
  float lerpXHB = mySmootherStep(ulb, urb, pFract.x);
  float lerpXLF = mySmootherStep(llf, lrf, pFract.x);
  float lerpXHF = mySmootherStep(ulf, urf, pFract.x);

  float lerpYB = mySmootherStep(lerpXLB, lerpXHB, pFract.y);
  float lerpYF = mySmootherStep(lerpXLF, lerpXHF, pFract.y);

  return mySmootherStep(lerpYB, lerpYF, pFract.z);
}

float fbm(vec2 uv, float octaves, vec2 seed) {
  float amp = 0.5;
  float freq = 8.0;
  float sum = 0.0;
  float maxSum = 0.0;
  for(float i = 0.0; i < 10.0; ++i) {
    if(i == octaves)
    break;
    maxSum += amp;
    sum += interpNoise2D1(uv * freq, seed) * amp;
    amp *= 0.5;
    freq *= 2.0;
  }
  return sum / maxSum;
}

float fbm(vec3 p, float octaves, vec3 seed) {
  float amp = 0.5;
  float freq = 8.0;
  float sum = 0.0;
  float maxSum = 0.0;
  for(float i = 0.0; i < 10.0; ++i) {
    if(i == octaves)
    break;
    maxSum += amp;
    sum += interpNoise3D1(p * freq, seed) * amp;
    amp *= 0.5;
    freq *= 2.0;
  }
  return sum / maxSum;
}

float surflet(vec2 P, vec2 gridPoint)
{
  // Compute falloff function by converting linear distance to a polynomial (quintic smootherstep function)
  float distX = abs(P.x - gridPoint.x);
  float distY = abs(P.y - gridPoint.y);
  float tX = 1.0 - 6.0 * pow(distX, 5.0) + 15.0 * pow(distX, 4.0) - 10.0 * pow(distX, 3.0);
  float tY = 1.0 - 6.0 * pow(distY, 5.0) + 15.0 * pow(distY, 4.0) - 10.0 * pow(distY, 3.0);

  // Get the random vector for the grid point
  vec2 gradient = random2(gridPoint, vec2(0.0, 0.0));
  // Get the vector from the grid point to P
  vec2 diff = P - gridPoint;
  // Get the value of our height field by dotting grid->P with our gradient
  float height = dot(diff, gradient);
  // Scale our height field (i.e. reduce it) by our polynomial falloff function
  return height * tX * tY;
}

float surflet(vec3 P, vec3 gridPoint)
{
  // Compute falloff function by converting linear distance to a polynomial (quintic smootherstep function)
  float distX = abs(P.x - gridPoint.x);
  float distY = abs(P.y - gridPoint.y);
  float distZ = abs(P.z - gridPoint.z);
  float tX = 1.0 - 6.0 * pow(distX, 5.0) + 15.0 * pow(distX, 4.0) - 10.0 * pow(distX, 3.0);
  float tY = 1.0 - 6.0 * pow(distY, 5.0) + 15.0 * pow(distY, 4.0) - 10.0 * pow(distY, 3.0);
  float tZ = 1.0 - 6.0 * pow(distZ, 5.0) + 15.0 * pow(distZ, 4.0) - 10.0 * pow(distZ, 3.0);

  // Get the random vector for the grid point
  vec3 gradient = random3(gridPoint, vec3(0.0, 0.0, 0.0));
  // Get the vector from the grid point to P
  vec3 diff = P - gridPoint;
  // Get the value of our height field by dotting grid->P with our gradient
  float height = dot(diff, gradient);
  // Scale our height field (i.e. reduce it) by our polynomial falloff function
  return height * tX * tY * tZ;
}

float perlinNoise(vec2 uv)
{
  // Tile the space
  vec2 uvXLYL = floor(uv);
  vec2 uvXHYL = uvXLYL + vec2(1.0, 0.0);
  vec2 uvXHYH = uvXLYL + vec2(1.0, 1.0);
  vec2 uvXLYH = uvXLYL + vec2(0.0, 1.0);

  return surflet(uv, uvXLYL) + surflet(uv, uvXHYL) + surflet(uv, uvXHYH) + surflet(uv, uvXLYH);
}

float perlinNoise(vec3 uv)
{
  // Tile the space
  vec3 uvXLYLZL = floor(uv);
  vec3 uvXHYLZL = uvXLYLZL + vec3(1.0, 0.0, 0.0);
  vec3 uvXHYHZL = uvXLYLZL + vec3(1.0, 1.0, 0.0);
  vec3 uvXLYHZL = uvXLYLZL + vec3(0.0, 1.0, 0.0);

  vec3 uvXLYLZH = uvXLYLZL + vec3(0.0, 0.0, 1.0);
  vec3 uvXHYLZH = uvXLYLZL + vec3(1.0, 0.0, 1.0);
  vec3 uvXHYHZH = uvXLYLZL + vec3(1.0, 1.0, 1.0);
  vec3 uvXLYHZH = uvXLYLZL + vec3(0.0, 1.0, 1.0);

  return surflet(uv, uvXLYLZL) + surflet(uv, uvXHYLZL) + surflet(uv, uvXHYHZL) + surflet(uv, uvXLYHZL) +
         surflet(uv, uvXLYLZH) + surflet(uv, uvXHYLZH) + surflet(uv, uvXHYHZH) + surflet(uv, uvXLYHZH);
}

float recursivePerlin(vec2 p) {
  vec2 offset = vec2(perlinNoise(p), perlinNoise(p + vec2(5.2, 1.3)));
  return perlinNoise(p + offset);
}

float recursivePerlin(vec3 p) {
  vec3 offset = vec3(perlinNoise(p), perlinNoise(p + vec3(5.2, 1.3, 9.5)), perlinNoise(p + vec3(121.7, 333.3, 678.9)));
  return perlinNoise(p + offset);
}

float recursivePerlin2(vec2 p) {
  vec2 offset1 = vec2(perlinNoise(p), perlinNoise(p + vec2(5.2, 1.3)));
  vec2 offset2 = vec2(perlinNoise(p * vec2(0.25, 2.25) + vec2(3.3, 4.4)), perlinNoise(p + vec2(55.2, 11.3)));
  vec2 offset3 = vec2(perlinNoise(p + offset1 + vec2(1.7, 9.2)), perlinNoise(p + offset2));
  return perlinNoise(p + offset3);
}

const vec4 dryColor = vec4(230.0, 200.0, 172.0, 255.0) / 255.0;
const vec4 wetColor = vec4(39.0, 125.0, 15.0, 255.0) / 255.0;

const vec4 deepWater = vec4(18.0, 46.0, 173.0, 255.0) / 255.0;
const vec4 shallowWater = vec4(68.0, 158.0, 249.0, 255.0) / 255.0;

// DESERT CODE
const vec4 sandColor0 = vec4(231.0, 223.0, 212.0, 255.0) / 255.0;
const vec4 sandColor1 = vec4(131.0, 128.0, 121.0, 255.0) / 255.0;
const vec4 sandColor2 = vec4(169.0, 157.0, 155.0, 255.0) / 255.0;
const vec4 sandColor3 = vec4(234.0, 200.0, 196.0, 255.0) / 255.0;
const vec4 sandColor4 = vec4(249.0, 225.0, 223.0, 255.0) / 255.0;
const vec4 sandColor5 = vec4(251.0, 240.0, 234.0, 255.0) / 255.0;
const vec4 sandyWaterColor = vec4(255.0, 250.0, 244.0, 255.0) / 255.0;//vec4(214.0, 212.0, 219.0, 255.0) / 255.0;
const vec4 desertWaterColor = vec4(64.0, 102.0, 159.0, 255.0) / 255.0;

void fbmToDesert(float fbmVal, out vec4 color) {
  // FBM is assumed to be uniform [0, 1) range.
  // 0 to 0.7 is flat-ish
  // 0.7 to 0.8 is sharp slope
  // 0.8 to 1 is flat
  float t = 0.0;
  if(fbmVal < 0.2) {
    t = smoothstep(0.75, 1.0, fbmVal / 0.2);
    color = mix(desertWaterColor, sandyWaterColor, t);
  }
  else if(fbmVal < 0.7) {
    t = (fbmVal - 0.2) / 0.5;
    float perlinT = t + recursivePerlin((fs_Pos.xz + u_PlanePos) * 0.25);
    color = mix(vec4(255.0, 250.0, 244.0, 255.0) / 255.0, mix(sandColor3, sandColor5, perlinT), smoothstep(0.0, 1.2, t));
  }
  else {
    t = (fbmVal - 0.7) / 0.1; // 0 to 1 along slope
    // t = sin(t * 3.14159 * 0.5 * 20.0); // Now it's a sine curve with frequency of 10
    // t = t + recursivePerlin((fs_Pos.xz  + u_PlanePos) * 2.0);
    t = t + recursivePerlin((vec3(0.0, frag_Height, 0.0) + fs_Pos.xyz  + vec3(u_PlanePos.x, 0.0, u_PlanePos.y)) * 0.5) * 0.5 +
            recursivePerlin((vec3(0.0, frag_Height, 0.0) + fs_Pos.xyz  + vec3(u_PlanePos.x, 0.0, u_PlanePos.y)) * 1.0) * 0.5;
    // t = t + fbm(fs_Pos.xy, 3.0, vec2(0.0, 0.0)) * 0.1;
    color = mix(sandColor2, sandColor3, t);
  }
}

const vec3 forestDarkGreen = vec3(82.0, 102.0, 101.0) / 255.0;
const vec3 forestMidGreen = vec3(99.0, 184.0, 147.0) / 255.0;
const vec3 forestMintGreen = vec3(141.0, 231.0, 187.0) / 255.0;
const vec3 forestPaleGreen = vec3(203.0, 240.0, 208.0) / 255.0;
const vec3 forestMidTeal = vec3(113.0, 162.0, 150.0) / 255.0;
const vec3 forestPaleTeal = vec3(163.0, 207.0, 194.0) / 255.0;
const vec3 forestBarkPale = vec3(128.0, 107.0, 104.0) / 255.0;
const vec3 forestBarkDark = vec3(80.0, 67.0, 65.0) / 255.0;
// FOREST CODE
in float frag_ForestTreesOrClearing;
void fbmToForest(float fbmVal, out vec4 color) {
  float floorT = recursivePerlin2((fs_Pos.xz + u_PlanePos)/ 4.0);
  vec3 clearingGroundColor = mix(forestMidTeal, forestMintGreen, floorT);
  float clearingT = smoothstep(0.0, 0.3, frag_ForestTreesOrClearing);
  color = mix(vec4(clearingGroundColor, 1.0), vec4(forestBarkPale, 1.0), clearingT);
  clearingT = smoothstep(0.3, 0.8, frag_ForestTreesOrClearing);
  color = mix(color, vec4(mix(forestDarkGreen, forestMidGreen, fbmVal), 1.0), clearingT);
}

const vec3 mountainDarkMauve = vec3(149.0, 102.0, 130.0) / 255.0;
const vec3 mountainMidMauve = vec3(194.0, 160.0, 187.0) / 255.0;
const vec3 mountainLightMauve = vec3(223.0, 205.0, 218.0) / 255.0;
const vec3 mountainPaleMauve = vec3(233.0, 230.0, 237.0) / 255.0;
const vec3 mountainDarkestMauve = vec3(78.0, 61.0, 66.0) / 255.0;
const vec3 mountainPeriwinkle = vec3(220.0, 224.0, 241.0) / 255.0;

const vec3 mountainPaleBlue = vec3(216.0, 234.0, 238.0) / 255.0;
const vec3 mountainLightBlue = vec3(160.0, 195.0, 204.0) / 255.0;
const vec3 mountainBlackStone = vec3(62.0, 59.0, 63.0) / 255.0;
const vec3 mountainDarkGrey = vec3(123.0, 116.0, 121.0) / 255.0;
const vec3 mountainLightGrey = vec3(188.0, 185.0, 187.0) / 255.0;
const vec3 mountainPaleGrey = vec3(220.0, 221.0, 222.0) / 255.0;
// MOUNTAIN CODE
in vec2 frag_mountainGradient;
void fbmToMountain(float fbmVal, out vec4 color) {
  // Map height field to color first
  // Topmost part is snow caps on mountains
  // Then stone
  // Then valley
  float valleyT = 0.0;
  float mountainT = (fbmVal - 0.5) / 0.5;
  mountainT = ((fbmVal - 0.5) / 0.5) * fbm((fs_Pos + vec3(u_PlanePos.x, fbmVal, u_PlanePos.y)) * vec3(0.025, 2.0, 0.025), 4.0, vec3(2.1, 3.4, 5.6));
  color = vec4(mix(mountainDarkestMauve, mountainMidMauve, mountainT), 1.0);
  float slopeT = clamp(1.0 - length(frag_mountainGradient * 20.0), 0.0, 1.0);
  slopeT = smoothstep(0.0, 1.0, slopeT) * smoothstep(0.6, 0.75, fbmVal);
  color = mix(color, vec4(mountainPeriwinkle, 1.0), slopeT);
}

// #define DESERT
// #define FOREST
#define MOUNTAINS
// #define FUNCTIONFUN
void main()
{
  vec4 diffuseColor;
  #ifdef DESERT
  fbmToDesert(frag_FBM, diffuseColor);
  #endif
  #ifdef FOREST
  fbmToForest(frag_FBM, diffuseColor);
  #endif
  #ifdef MOUNTAINS
  fbmToMountain(frag_FBM, diffuseColor);
  #endif
  #ifdef FUNCTIONFUN
  diffuseColor = vec4(frag_FBM, frag_FBM, frag_FBM, 1.0);
  #endif

  // Calculate the diffuse term for Lambert shading
  float diffuseTerm = dot(normalize(fs_Nor), normalize(fs_LightVec));
  // Avoid negative lighting values
  // diffuseTerm = clamp(diffuseTerm, 0, 1);

  float ambientTerm = 0.2;

  float lightIntensity = 1.0;//diffuseTerm + ambientTerm;

  float t = clamp(smoothstep(40.0, 50.0, length(fs_Pos)), 0.0, 1.0); // Distance fog
  // Compute final shaded color
  out_Col = mix(vec4(diffuseColor.rgb * lightIntensity, diffuseColor.a), vec4(164.0 / 255.0, 233.0 / 255.0, 1.0, 1.0), t);
}
