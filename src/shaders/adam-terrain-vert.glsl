#version 300 es


uniform mat4 u_Model;
uniform mat4 u_ModelInvTr;
uniform mat4 u_ViewProj;
uniform vec2 u_PlanePos; // Our location in the virtual world displayed by the plane

in vec4 vs_Pos;
in vec4 vs_Nor;
in vec4 vs_Col;

out vec3 fs_Pos;
out vec4 fs_Nor;
out vec4 fs_LightVec;
out vec4 fs_Col;

const vec4 lightDir = normalize(vec4(1, 1, 1, 0));

float random1( float p , float seed) {
  return fract(sin((p + seed) * 420.69) * 43758.5453);
}

float random1( vec2 p , vec2 seed) {
  return fract(sin(dot(p + seed,vec2(127.1,311.7)))*43758.5453);
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

vec2 mySmootherStep(vec2 a, vec2 b, float t) {
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

vec2 interpNoise2D2(vec2 uv, vec2 seed) {
  vec2 uvFract = fract(uv);
  vec2 ll = random2(floor(uv), seed);
  vec2 lr = random2(floor(uv) + vec2(1.0,0.0), seed);
  vec2 ul = random2(floor(uv) + vec2(0.0,1.0), seed);
  vec2 ur = random2(floor(uv) + vec2(1.0,1.0), seed);

  vec2 lerpXL = mySmootherStep(ll, lr, uvFract.x);
  vec2 lerpXU = mySmootherStep(ul, ur, uvFract.x);

  return mySmootherStep(lerpXL, lerpXU, uvFract.y);
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

vec2 fbm2(vec2 uv, float octaves, vec2 seed) {
  float amp = 0.5;
  float freq = 8.0;
  vec2 sum = vec2(0.0);
  float maxSum = 0.0;
  for(float i = 0.0; i < 10.0; ++i) {
    if(i == octaves)
      break;
    maxSum += amp;
    sum += interpNoise2D2(uv * freq, seed) * amp;
    amp *= 0.5;
    freq *= 2.0;
  }
  return sum / maxSum;
}

float worleyNoise(vec2 uv) {
    // Tile the space
    vec2 uvInt = floor(uv);
    vec2 uvFract = fract(uv);

    float minDist = 1.0; // Minimum distance initialized to max.

    // Search all neighboring cells and this cell for their point
    for(float y = -1.0; y <= 1.0; ++y) {
        for(float x = -1.0; x <= 1.0; ++x) {
            vec2 neighbor = vec2(x, y);
            // Random point inside current neighboring cell
            vec2 point = random2(uvInt + neighbor, vec2(0.0, 0.0));
            // Compute the distance b/t the point and the fragment
            // Store the min dist thus far
            vec2 diff = neighbor + point - uvFract;
            float dist = length(diff);
            minDist = min(minDist, dist);
        }
    }
    return minDist;
}

float sineWorley(float worley) {
  return sin(worley * 3.14159 * 0.5);
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

float forestSummedWorley(vec2 uv, float octaves) {
  float amp = 0.5;
  float freq = 1.0;
  float sum = 0.0;
  float maxSum = 0.0;
  for(float i = 0.0; i < 10.0; ++i) {
    if(i == octaves)
      break;
    maxSum += amp;
    float noise = 1.0 - worleyNoise(uv * freq);
    noise = max(0.0, (noise - 0.4) / 0.6);
    sum += sineWorley(noise) * amp;
    amp *= 0.5;
    freq *= 2.0;
  }
  return sum / maxSum;
}

// Uses Musgrave's hybrid multifractal approach
// In summary, each octave is additionally scaled by the height of the previous octave
// This means areas with low initial height tend to be smoother, leading to
// smooth valley floors and craggy mountaintops
float mountainSummedPerlin(vec2 uv, float octaves) {
  float amp = 0.5;
  float freq = 1.0;
  float sum = 0.0;
  float maxSum = 0.0;
  float prevValue = 1.0;
  for(float i = 0.0; i < 10.0; ++i) {
    if(i == octaves)
      break;
    maxSum += amp;
    float noise = 1.0 - abs(perlinNoise(uv * freq));
    noise = noise * prevValue;
    prevValue = noise;
    sum += noise * amp;
    amp *= 0.5;
    freq *= 2.0;
  }
  return sum / maxSum;
}

// DESERT-specific out variables go here

// GraphToy stuff

//smoothstep(0, 0.15, x) * (max(((0.4-x*x) * 0.2), 0) + (step(x, 0.69) + step(0.69, x) * (abs(floor(x * 100.0) % 2) * 0.1 + 0.9) * step(x, 0.8) + 1.0 - step(x, 0.8)) * ((pow(smoothstep(0.0, 0.9, pow(smoothstep(0.0, 1.0, x), 1.0)), 100.0) + x * 0.1) / 1.1))

void generateDesertTerrain(vec2 worldPos, out float fbmNoise, out float height) {
  // FBM is assumed to be uniform [0, 1) range.
  // Linear to cubic
  // Want to shift curve to right, keep left bound flat
  // height = (smoothstep(0.0, 0.3, (pow(smoothstep(0.0, 1.0, fbm), 4.0) + fbm * 0.05) / 1.05) + fbm * 0.02) / 1.02 * 10.0;
  float x = fbm((u_PlanePos + worldPos) / 128.0, 4.0, vec2(67.89, 34.123));
  fbmNoise = x;
  height = (pow(smoothstep(0.0, 0.9, pow(smoothstep(0.0, 1.0, x), 1.0)), 100.0) * (floor(x * 40.0) / 40.0) + x * 0.1) / 1.1 * 10.0;
  height = 10.0 * (max(0.05 * (1.0 - pow(4.0 * (x - 0.42), 2.0)), 0.0) + smoothstep(0.05, 0.2, x) * (max(((0.4-x*x) * 0.2), 0.0) + (step(x, 0.69) + step(0.69, x) * (abs(mod(floor(x * 100.0), 2.0)) * 0.1 + 0.9) * step(x, 0.8) + 1.0 - step(x, 0.8)) * ((pow(smoothstep(0.0, 0.9, pow(smoothstep(0.0, 1.0, x), 1.0)), 100.0) + x * 0.1) / 1.1)));
}

// FOREST-specific out variables go here
out float frag_ForestTreesOrClearing;
void generateForestTerrain(vec2 worldPos, out float fbmNoise, out float height) {
  // Use summed Worley noise
  float x = forestSummedWorley((worldPos + u_PlanePos) / 8.0, 6.0);
  fbmNoise = x;
  x = sin(3.14159 * 0.5 * x);
  // Secondary noise value to determine if a FOREST zone is a clearing or trees
  frag_ForestTreesOrClearing = fbm((worldPos + u_PlanePos) / 512.0, 4.0, vec2(67.89, 34.123));
  // If secondary noise is <= 0.35, it's clearing.
  frag_ForestTreesOrClearing = smoothstep(0.35, 0.38, frag_ForestTreesOrClearing);
  height = (x * 2.5 + 0.5) * frag_ForestTreesOrClearing;
}

// MOUNTAIN-specific out variables go here
out vec2 frag_mountainGradient;
void generateMountainTerrain(vec2 worldPos, out float fbmNoise, out float height) {
  float x = mountainSummedPerlin((worldPos + u_PlanePos) / 48.0, 8.0);
  frag_mountainGradient = vec2(mountainSummedPerlin((worldPos + u_PlanePos + vec2(1.0, 0.0)) / 48.0, 8.0) - mountainSummedPerlin((worldPos + u_PlanePos - vec2(1.0, 0.0)) / 48.0, 8.0),
                               mountainSummedPerlin((worldPos + u_PlanePos + vec2(0.0, 1.0)) / 48.0, 8.0) - mountainSummedPerlin((worldPos + u_PlanePos - vec2(0.0, 1.0)) / 48.0, 8.0) * 1.0);
  x = pow(x, 6.0);
  fbmNoise = x;
  height = x * 15.0;
}

// FUNCTIONFUN-specific variables go here
void generateFunctionFunTerrain(vec2 worldPos, out float fbmNoise, out float height) {
  float x = fbm((worldPos + u_PlanePos) / 128.0, 6.0, vec2(67.89, 34.123));
  // Remap x here
  x = pow(x, 0.1);
  fbmNoise = height = x;
  height *= 10.0;
}

out float frag_FBM; // Unaltered FBM value
out float frag_Height; // FBM after being remapped
out float frag_Temp;
out float frag_Moisture;


// #define DESERT
// #define FOREST
#define MOUNTAINS
// #define FUNCTIONFUN
void main()
{
  fs_Col = vs_Col;
  mat3 invTranspose = mat3(u_ModelInvTr);
  fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0.0);
  vec4 modelposition = u_Model * vs_Pos;
  fs_Pos = modelposition.xyz;

  // float fbmNoise = fbm((u_PlanePos + modelposition.xz) / 64.0, 3.0, vec2(67.89, 34.123));
  #ifdef DESERT
  // Desert terrain
  frag_FBM = fbm((u_PlanePos + modelposition.xz) / 128.0, 4.0, vec2(67.89, 34.123));
  generateDesertTerrain(modelposition.xz, frag_FBM, frag_Height);
  #endif

  #ifdef FOREST
  // Forest terrain
  // frag_FBM = fbm((u_PlanePos + modelposition.xz) / 128.0, 4.0, vec2(67.89, 34.123));
  generateForestTerrain(modelposition.xz, frag_FBM, frag_Height);
  #endif

  #ifdef MOUNTAINS
  generateMountainTerrain(modelposition.xz, frag_FBM, frag_Height);
  #endif

  #ifdef FUNCTIONFUN
  generateFunctionFunTerrain(modelposition.xz, frag_FBM, frag_Height);
  #endif

  float dY = frag_Height;

  frag_Moisture = fbm((u_PlanePos + modelposition.xz) / 512.0, 4.0, vec2(1000.101, -1000.101));

  modelposition.y += dY;

  fs_LightVec = lightDir;

  gl_Position = u_ViewProj * modelposition;
}
