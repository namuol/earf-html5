#include <iostream>
#include <SDL/SDL.h>
#include <SDL/SDL_keysym.h>
#include <SDL/SDL_image.h>

#include "ITimer.h"
#include "POSIXTimer.h"
#include "Camera.h"

#define SCR_W 640
#define SCR_H 400

#define MAX_D 512
#define LOD_FACTOR 4

using namespace std;
bool running = true;
bool leftdown, rightdown, updown, downdown,
     wdown, sdown, qdown, edown;
bool recording = false;

void quit() {
  SDL_Quit();
}

void handle_key(SDL_Event* e, bool keydown) {
  switch (e->key.keysym.sym) {
    case SDLK_LEFT:
      leftdown = keydown;
      break;
    case SDLK_RIGHT:
      rightdown = keydown;
      break;
    case SDLK_UP:
      updown = keydown;
      break;
    case SDLK_DOWN:
      downdown = keydown;
      break;
    case SDLK_w:
      wdown = keydown;
      break;
    case SDLK_s:
      sdown = keydown;
      break;
    case SDLK_q:
      qdown = keydown;
      break;
    case SDLK_e:
      edown = keydown;
      break;
    case SDLK_SPACE:
      recording = !recording;
      break;
    default:
      break;
  }
}

void event(SDL_Event* e) {
  switch (e->type) {
  case SDL_QUIT:
    running = false;
    break;
  case SDL_KEYDOWN:
    if (e->key.keysym.sym == SDLK_ESCAPE) {
      running = false;
      break;
    }
    handle_key(e, true);
    break;
  case SDL_KEYUP:
    handle_key(e, false);
    break;
  }
}

int main(int ac, char** av) {
  cout << -4 % 255 << endl;

  SDL_Surface* scr;

  if (SDL_Init(SDL_INIT_EVERYTHING) < 0) {
    quit();
    return -1;
  } 
  
  if ((scr = SDL_SetVideoMode(SCR_W,SCR_H,32, SDL_HWSURFACE|SDL_DOUBLEBUF)) == NULL) {
    quit();
    return -2;
  }
  SDL_Surface* _map, * map;
  _map = IMG_Load("heightmap.jpg");
  map = SDL_DisplayFormat(_map);

  cout << scr->format << endl;
  cout << map->format << endl;

  Camera* cam = new Camera(Vector(map->w/2,1280,map->h/2), 25, SCR_W,SCR_H);

  POSIXTimer timer;
  timer.init();
  timer.calc_precision(100);

  int cyclesLeftOver = 0;
  int lastFrameTime = 0;
  int updateInterval = 1000/60;
  int maxCyclesPerFrame = 8;
  double camH = 100;
  SDL_Event e;

  Vector cv;
  int frame = 1;
  char fn [255];
  while( running )
  {
    int currentTime;
    int updateIterations;
    int dt;

    currentTime = timer.get_time();
    dt = (currentTime - lastFrameTime);
    updateIterations = (dt + cyclesLeftOver);

    if (updateIterations > (maxCyclesPerFrame * updateInterval)) {
      updateIterations = (maxCyclesPerFrame * updateInterval);
    }
    
    while (updateIterations > updateInterval) {
      updateIterations -= updateInterval;

      // UPDATE EVERYTHING.
      if (updown)
        cv += cam->look()*0.2;
      if (downdown)
        cv -= cam->look()*0.2;
      if (leftdown)
        cv += cam->perp()*0.2;
      if (rightdown)
        cv -= cam->perp()*0.2;

      if (wdown)
        camH += 4;
      if (sdown)
        camH -= 4;
      
      if (qdown)
        cam->ang(cam->ang() + 0.03);
      if (edown)
        cam->ang(cam->ang() - 0.03);

      double h; 
      Uint8 r,g,b;
      Vector eye = cam->eye();
      if (eye.x >= 0 && eye.z >= 0) {
        Uint32 c = getpixel(map, (int)(eye.x)%map->w,(int)(eye.z)%map->h);         
        SDL_GetRGB(c, scr->format, &r, &g, &b);
        h = (double)r * 0.25;
        double target = (h+camH) - eye.y;
        cv.y = (target - cv.y) * 0.1;
      }
      cam->eye(cam->eye() + cv);
      cv *= 0.9;
      while (SDL_PollEvent(&e)) {
        event(&e);
      }
    }

    cyclesLeftOver = updateIterations;
    lastFrameTime = currentTime;

    // RENDER EVERYTHING.
    SDL_FillRect( SDL_GetVideoSurface(), NULL, 0 );
    if(SDL_MUSTLOCK(scr)) SDL_LockSurface(scr);
    if(SDL_MUSTLOCK(map)) SDL_LockSurface(map);
    for (int x=0; x < SCR_W; ++x) {
      int maxY = SCR_H-1;
      double cx,cy,cz;
      double h, ch;
      Uint32 c;
      Uint8 r,g,b;
      Ray ray = cam->getRayFromUV(x,0);
      ch = ray.pos.y;
      for (double d = 35; d < MAX_D; d += 1 + LOD_FACTOR*(int)(d-100)/MAX_D) {
        cx = 1 * (ray.pos.x + ray.norm.x * d);
        cz = 1 * (ray.pos.z + ray.norm.z * d);
        if (cx < 0 || cz < 0) continue;
        c = getpixel(map, (int)cx%map->w,(int)cz%map->h);         
        SDL_GetRGB(c, scr->format, &r, &g, &b);
        h = (double)r * 0.25;

        // My projection function doesn't work, but the simpler one below it does...
        //int y = SCR_H - (((h - ch) * (13.4/d)) / 256.0) * SCR_H;
        int y = SCR_H - (((h - ch) * 350) / d + SCR_H);

        //cout << y << endl;
        if (y < 0) continue;

        double fog = 1.0 - d/MAX_D;
        r*=fog;
        g*=fog;
        b*=fog;
        if (y < maxY) {
          for (int _y = maxY; _y > y; --_y) {
            if (_y >= SCR_H) continue;
            setpixel(scr, x,_y, r,g,b);
          }
          maxY = y;
        }
      }
    }

    SDL_UnlockSurface(scr);
    SDL_UnlockSurface(map);
    SDL_Flip(scr);

    if (recording && frame%5==1) {
      sprintf(fn, "%06d.bmp", frame);
      SDL_SaveBMP(scr, fn);
    }
    ++frame;

    int leftoverTime = updateInterval - (timer.get_time() - lastFrameTime);
    if (leftoverTime < 0)
      cout << leftoverTime << endl;

    // If we have more than 1 update interval worth of time left still,
    //  wait it out to save CPU cycles.
    if( leftoverTime > timer.precision() )
    {
      timer.wait(leftoverTime - (leftoverTime % timer.precision()));
    }

    while( leftoverTime > 0 )
    {
      leftoverTime = updateInterval - (timer.get_time() - lastFrameTime);
    }
  }

  quit();
  return 0;
}
