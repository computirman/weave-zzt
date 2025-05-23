//from "sdl_events.h"

type
  PSDL_EventType = ^TSDL_EventType;
  TSDL_EventType = type cuint32;

  {**
   *  The types of events that can be delivered.
   *}
const

  { General keyboard/mouse state definitions }
  SDL_RELEASED         = 0;
  SDL_PRESSED          = 1;

  SDL_FIRSTEVENT       = TSDL_EventType(0);     // Unused (do not remove) (needed in pascal?)

  SDL_COMMONEVENT      = TSDL_EventType(1);     //added for pascal-compatibility

  { Application events }
  SDL_QUITEV           = TSDL_EventType($100);  // User-requested quit (originally SDL_QUIT, but changed, cause theres a method called SDL_QUIT)


  { These application events have special meaning on iOS, see README.iOS for details *}
  
  {* The application is being terminated by the OS. *
   * Called on iOS in applicationWillTerminate()    *
   * Called on Android in onDestroy()               *}
  SDL_APP_TERMINATING  = TSDL_EventType($101);

  {* The application is low on memory, free memory if possible. *
   * Called on iOS in applicationDidReceiveMemoryWarning()      *
   * Called on Android in onLowMemory()                         *}
  SDL_APP_LOWMEMORY    = TSDL_EventType($102);

  {* The application is about to enter the background. *
   * Called on iOS in applicationWillResignActive()    *
   * Called on Android in onPause()                    *}
  SDL_APP_WILLENTERBACKGROUND = TSDL_EventType($103);
  
  {* The application did enter the background and may not get CPU for some time. *
   * Called on iOS in applicationDidEnterBackground()                            *
   * Called on Android in onPause()                                              *}
  SDL_APP_DIDENTERBACKGROUND = TSDL_EventType($104);
  
  {* The application is about to enter the foreground. *
   * Called on iOS in applicationWillEnterForeground() *
   * Called on Android in onResume()                   *}
  SDL_APP_WILLENTERFOREGROUND = TSDL_EventType($105);
  
  {* The application is now interactive.           *
   * Called on iOS in applicationDidBecomeActive() *
   * Called on Android in onResume()               *}
  SDL_APP_DIDENTERFOREGROUND = TSDL_EventType($106); 


  { Window events }
  SDL_WINDOWEVENT      = TSDL_EventType($200);  // Window state change
  SDL_SYSWMEVENT       = TSDL_EventType($201);  // System specific event

  { Keyboard events }
  SDL_KEYDOWN          = TSDL_EventType($300);  // Key pressed
  SDL_KEYUP            = TSDL_EventType($301);  // Key released
  SDL_TEXTEDITING      = TSDL_EventType($302);  // Keyboard text editing (composition)
  SDL_TEXTINPUT        = TSDL_EventType($303);  // Keyboard text input
  SDL_KEYMAPCHANGED    = TSDL_EventType($304);  // Keymap changed due to a system event such as an input language or keyboard layout change.

  { Mouse events }
  SDL_MOUSEMOTION      = TSDL_EventType($400);  // Mouse moved
  SDL_MOUSEBUTTONDOWN  = TSDL_EventType($401);  // Mouse button pressed
  SDL_MOUSEBUTTONUP    = TSDL_EventType($402);  // Mouse button released
  SDL_MOUSEWHEEL       = TSDL_EventType($403);  // Mouse wheel motion

  { Joystick events }
  SDL_JOYAXISMOTION    = TSDL_EventType($600);  // Joystick axis motion
  SDL_JOYBALLMOTION    = TSDL_EventType($601);  // Joystick trackball motion
  SDL_JOYHATMOTION     = TSDL_EventType($602);  // Joystick hat position change
  SDL_JOYBUTTONDOWN    = TSDL_EventType($603);  // Joystick button pressed
  SDL_JOYBUTTONUP      = TSDL_EventType($604);  // Joystick button released
  SDL_JOYDEVICEADDED   = TSDL_EventType($605);  // A new joystick has been inserted into the system 
  SDL_JOYDEVICEREMOVED = TSDL_EventType($606);  // An opened joystick has been removed 

  { Game controller events }
  SDL_CONTROLLERAXISMOTION     = TSDL_EventType($650);  // Game controller axis motion
  SDL_CONTROLLERBUTTONDOWN     = TSDL_EventType($651);  // Game controller button pressed 
  SDL_CONTROLLERBUTTONUP       = TSDL_EventType($652);  // Game controller button released
  SDL_CONTROLLERDEVICEADDED    = TSDL_EventType($653);  // A new Game controller has been inserted into the system 
  SDL_CONTROLLERDEVICEREMOVED  = TSDL_EventType($654);  // An opened Game controller has been removed 
  SDL_CONTROLLERDEVICEREMAPPED = TSDL_EventType($655);  // The controller mapping was updated 
   
  { Touch events }
  SDL_FINGERDOWN      = TSDL_EventType($700);
  SDL_FINGERUP        = TSDL_EventType($701);
  SDL_FINGERMOTION    = TSDL_EventType($702);

  { Gesture events }
  SDL_DOLLARGESTURE   = TSDL_EventType($800);
  SDL_DOLLARRECORD    = TSDL_EventType($801);
  SDL_MULTIGESTURE    = TSDL_EventType($802);

  { Clipboard events }
  SDL_CLIPBOARDUPDATE = TSDL_EventType($900); // The clipboard changed

  { Drag and drop events }
  SDL_DROPFILE        = TSDL_EventType($1000); // The system requests a file open
  SDL_DROPTEXT        = TSDL_EventType($1001); // text/plain drag-and-drop event
  SDL_DROPBEGIN       = TSDL_EventType($1002); // A new set of drops is beginning (NULL filename)
  SDL_DROPCOMPLETE    = TSDL_EventType($1003); // Current set of drops is now complete (NULL filename)

  { Audio hotplug events }
  SDL_AUDIODEVICEADDED     = TSDL_EventType($1100); // A new audio device is available
  SDL_AUDIODEVICEREMOVED   = TSDL_EventType($1101); // An audio device has been removed.

  { Render events }
  SDL_RENDER_TARGETS_RESET = TSDL_EventType($2000); // The render targets have been reset
  SDL_RENDER_DEVICE_RESET  = TSDL_EventType($2001); // The device has been reset and all textures need to be recreated
  
  {** Events SDL_USEREVENT through SDL_LASTEVENT are for your use,
   *  and should be allocated with SDL_RegisterEvents()
   *}
  SDL_USEREVENT    = TSDL_EventType($8000);

  {**
   *  This last event is only for bounding internal arrays (needed in pascal ??)
   *}
  SDL_LASTEVENT    = TSDL_EventType($FFFF);

type
  {**
   *  Fields shared by every event
   *}

  TSDL_CommonEvent = record
    type_: cuint32;
    timestamp: cuint32;
  end;

  {**
   *  Window state change event data (event.window.*)
   *}

  TSDL_WindowEvent = record
    type_: cuint32;       // SDL_WINDOWEVENT
    timestamp: cuint32;
    windowID: cuint32;    // The associated window
    event: cuint8;        // SDL_WindowEventID
    padding1: cuint8;
    padding2: cuint8;
    padding3: cuint8;
    data1: cint32;       // event dependent data
    data2: cint32;       // event dependent data 
  end;

  {**
   *  Keyboard button event structure (event.key.*)
   *}
  TSDL_KeyboardEvent = record
    type_: cuint32;        // SDL_KEYDOWN or SDL_KEYUP
    timestamp: cuint32;
    windowID: cuint32;     // The window with keyboard focus, if any
    state: cuint8;         // SDL_PRESSED or SDL_RELEASED 
    _repeat: cuint8;       // Non-zero if this is a key repeat
    padding2: cuint8;
    padding3: cuint8;
    keysym: TSDL_KeySym;  // The key that was pressed or released
  end;

const
  SDL_TEXTEDITINGEVENT_TEXT_SIZE = 32;

type
 
  {**
   *  Keyboard text editing event structure (event.edit.*)
   *}

  TSDL_TextEditingEvent = record
    type_: cuint32;                               // SDL_TEXTEDITING 
    timestamp: cuint32;
    windowID: cuint32;                            // The window with keyboard focus, if any
    text: array[0..SDL_TEXTEDITINGEVENT_TEXT_SIZE] of Char;  // The editing text 
    start: cint32;                               // The start cursor of selected editing text
    length: cint32;                              // The length of selected editing text
  end;

const
  SDL_TEXTINPUTEVENT_TEXT_SIZE = 32;

type

  {**
   *  Keyboard text input event structure (event.text.*)
   *}

  TSDL_TextInputEvent = record
    type_: cuint32;                                          // SDL_TEXTINPUT 
    timestamp: cuint32;
    windowID: cuint32;                                       // The window with keyboard focus, if any
    text: array[0..SDL_TEXTINPUTEVENT_TEXT_SIZE] of Char;   // The input text 
  end;

  {**
   *  Mouse motion event structure (event.motion.*)
   *}
 
  TSDL_MouseMotionEvent = record
    type_: cuint32;       // SDL_MOUSEMOTION
    timestamp: cuint32;
    windowID: cuint32;    // The window with mouse focus, if any
    which: cuint32;       // The mouse instance id, or SDL_TOUCH_MOUSEID
    state: cuint8;        // The current button state 
    padding1: cuint8;
    padding2: cuint8;
    padding3: cuint8;
    x: cint32;           // X coordinate, relative to window
    y: cint32;           // Y coordinate, relative to window
    xrel: cint32;        // The relative motion in the X direction 
    yrel: cint32;        // The relative motion in the Y direction
  end;

  {**
   *  Mouse button event structure (event.button.*)
   *}

  TSDL_MouseButtonEvent = record
    type_: cuint32;       // SDL_MOUSEBUTTONDOWN or SDL_MOUSEBUTTONUP 
    timestamp: cuint32;
    windowID: cuint32;    // The window with mouse focus, if any
    which: cuint32;       // The mouse instance id, or SDL_TOUCH_MOUSEID 
    button: cuint8;       // The mouse button index
    state: cuint8;        // SDL_PRESSED or SDL_RELEASED
    clicks: cuint8;       // 1 for single-click, 2 for double-click, etc.
    padding1: cuint8;
    x: cint32;           // X coordinate, relative to window
    y: cint32;           // Y coordinate, relative to window 
  end;

  {**
   *  Mouse wheel event structure (event.wheel.*)
   *}
 
  TSDL_MouseWheelEvent = record
    type_: cuint32;        // SDL_MOUSEWHEEL
    timestamp: cuint32;
    windowID: cuint32;    // The window with mouse focus, if any
    which: cuint32;       // The mouse instance id, or SDL_TOUCH_MOUSEID
    x: cint32;           // The amount scrolled horizontally 
    y: cint32;           // The amount scrolled vertically
    direction: cuint32;   // Set to one of the SDL_MOUSEWHEEL_* defines. When FLIPPED the values in X and Y will be opposite. Multiply by -1 to change them back
  end;

  {**
   *  Joystick axis motion event structure (event.jaxis.*)
   *}

  TSDL_JoyAxisEvent = record
    type_: cuint32;         // SDL_JOYAXISMOTION 
    timestamp: cuint32;
    which: TSDL_JoystickID; // The joystick instance id
    axis: cuint8;           // The joystick axis index 
    padding1: cuint8;
    padding2: cuint8;
    padding3: cuint8;
    value: cint16;         // The axis value (range: -32768 to 32767)
    padding4: cuint16;
  end;

  {**
   *  Joystick trackball motion event structure (event.jball.*)
   *}

  TSDL_JoyBallEvent = record
    type_: cuint32;         // SDL_JOYBALLMOTION
    timestamp: cuint32;
    which: TSDL_JoystickID; // The joystick instance id
    ball: cuint8;           // The joystick trackball index
    padding1: cuint8;
    padding2: cuint8;
    padding3: cuint8;
    xrel: cint16;          // The relative motion in the X direction
    yrel: cint16;          // The relative motion in the Y direction
  end;

  {**
   *  Joystick hat position change event structure (event.jhat.*)
   *}

  TSDL_JoyHatEvent = record
    type_: cuint32;         // SDL_JOYHATMOTION
    timestamp: cuint32;
    which: TSDL_JoystickID; // The joystick instance id
    hat: cuint8;            // The joystick hat index
    value: cuint8;         {*  The hat position value.
                           *  SDL_HAT_LEFTUP   SDL_HAT_UP       SDL_HAT_RIGHTUP
                           *  SDL_HAT_LEFT     SDL_HAT_CENTERED SDL_HAT_RIGHT
                           *  SDL_HAT_LEFTDOWN SDL_HAT_DOWN     SDL_HAT_RIGHTDOWN
                           *
                           *  Note that zero means the POV is centered.
                           *}
    padding1: cuint8;
    padding2: cuint8;
  end;

  {**
   *  Joystick button event structure (event.jbutton.*)
   *}

  TSDL_JoyButtonEvent = record
    type_: cuint32;        // SDL_JOYBUTTONDOWN or SDL_JOYBUTTONUP
    timestamp: cuint32;
    which: TSDL_JoystickID; // The joystick instance id 
    button: cuint8;         // The joystick button index
    state: cuint8;          // SDL_PRESSED or SDL_RELEASED
    padding1: cuint8;
    padding2: cuint8;
  end;

  {**
   *  Joystick device event structure (event.jdevice.*)
   *}

  TSDL_JoyDeviceEvent = record
    type_: cuint32;      // SDL_JOYDEVICEADDED or SDL_JOYDEVICEREMOVED
    timestamp: cuint32;
    which: cint32;      // The joystick device index for the ADDED event, instance id for the REMOVED event
  end;

  {**
   *  Game controller axis motion event structure (event.caxis.*)
   *}

  TSDL_ControllerAxisEvent = record
    type_: cuint32;         // SDL_CONTROLLERAXISMOTION
    timestamp: cuint32;
    which: TSDL_JoystickID; // The joystick instance id
    axis: cuint8;           // The controller axis (SDL_GameControllerAxis)
    padding1: cuint8;
    padding2: cuint8;
    padding3: cuint8;
    value: cint16;         // The axis value (range: -32768 to 32767)
    padding4: cuint16;
  end;

  {**
   *  Game controller button event structure (event.cbutton.*)
   *}

  TSDL_ControllerButtonEvent = record
    type_: cuint32;         // SDL_CONTROLLERBUTTONDOWN or SDL_CONTROLLERBUTTONUP
    timestamp: cuint32;
    which: TSDL_JoystickID; // The joystick instance id
    button: cuint8;         // The controller button (SDL_GameControllerButton)
    state: cuint8;          // SDL_PRESSED or SDL_RELEASED
    padding1: cuint8;
    padding2: cuint8;
  end;


  {**
   *  Controller device event structure (event.cdevice.*)
   *}

  TSDL_ControllerDeviceEvent = record
    type_: cuint32;       // SDL_CONTROLLERDEVICEADDED, SDL_CONTROLLERDEVICEREMOVED, or SDL_CONTROLLERDEVICEREMAPPED
    timestamp: cuint32;
    which: cint32;       // The joystick device index for the ADDED event, instance id for the REMOVED or REMAPPED event
  end;

  {**
   *  Audio device event structure (event.adevice.*)
   *}

  TSDL_AudioDeviceEvent = record
    type_: cuint32;        // ::SDL_AUDIODEVICEADDED, or ::SDL_AUDIODEVICEREMOVED
    timestamp: cuint32;
    which: cuint32;        // The audio device index for the ADDED event (valid until next SDL_GetNumAudioDevices() call), SDL_AudioDeviceID for the REMOVED event
    iscapture: cuint8;     // zero if an output device, non-zero if a capture device.
    padding1: cuint8;
    padding2: cuint8;
    padding3: cuint8;
  end;


  {**
   *  Touch finger event structure (event.tfinger.*)
   *}

  TSDL_TouchFingerEvent = record
    type_: cuint32;         // SDL_FINGERMOTION or SDL_FINGERDOWN or SDL_FINGERUP
    timestamp: cuint32;
    touchId: TSDL_TouchID;  // The touch device id
    fingerId: TSDL_FingerID;
    x: cfloat;              // Normalized in the range 0...1
    y: cfloat;              // Normalized in the range 0...1
    dx: cfloat;             // Normalized in the range 0...1
    dy: cfloat;             // Normalized in the range 0...1
    pressure: cfloat;       // Normalized in the range 0...1
  end;

  {**
   *  Multiple Finger Gesture Event (event.mgesture.*)
   *}
  TSDL_MultiGestureEvent = record
    type_: cuint32;        // SDL_MULTIGESTURE
    timestamp: cuint32;
    touchId: TSDL_TouchID; // The touch device index
    dTheta: cfloat;
    dDist: cfloat;
    x: cfloat;
    y: cfloat;
    numFingers: cuint16;
    padding: cuint16;
  end;


  {* (event.dgesture.*) *}
  TSDL_DollarGestureEvent = record
    type_: cuint32;         // SDL_DOLLARGESTURE
    timestamp: cuint32;
    touchId: TSDL_TouchID;  // The touch device id
    gestureId: TSDL_GestureID;
    numFingers: cuint32;
    error: cfloat;
    x: cfloat;              // Normalized center of gesture
    y: cfloat;              // Normalized center of gesture
  end;


  {**
   *  An event used to request a file open by the system (event.drop.*)
   *  This event is disabled by default, you can enable it with SDL_EventState()
   *  If you enable this event, you must free the filename in the event.
   *}

  TSDL_DropEvent = record
    type_: cuint32;      // SDL_DROPFILE
    timestamp: cuint32;
    _file: PAnsiChar;   // The file name, which should be freed with SDL_free()
  end;

  {**
   *  The "quit requested" event
   *}

  TSDL_QuitEvent = record
    type_: cuint32;        // SDL_QUIT
    timestamp: cuint32;
  end;

  {**
   *  A user-defined event type (event.user.*)
   *}

  TSDL_UserEvent = record
    type_: cuint32;       // SDL_USEREVENT through SDL_NUMEVENTS-1
    timestamp: cuint32;
    windowID: cuint32;    // The associated window if any
    code: cint32;        // User defined event code
    data1: Pointer;      // User defined data pointer
    data2: Pointer;      // User defined data pointer
  end;

  {**
   *  A video driver dependent system event (event.syswm.*)
   *  This event is disabled by default, you can enable it with SDL_EventState()
   *
   *  If you want to use this event, you should include SDL_syswm.h.
   *}

  PSDL_SysWMEvent = ^TSDL_SysWMEvent;
  TSDL_SysWMEvent = record
    type_: cuint32;       // SDL_SYSWMEVENT
    timestamp: cuint32;
    msg: PSDL_SysWMmsg;  // driver dependent data (defined in SDL_syswm.h)
  end;

  {**
   *  General event structure
   *}

  PSDL_Event = ^TSDL_Event;
  TSDL_Event = record
    case cint of
      0:  (type_: cuint32);

      SDL_COMMONEVENT:  (common: TSDL_CommonEvent);
      SDL_WINDOWEVENT:  (window: TSDL_WindowEvent);

      SDL_KEYUP,
      SDL_KEYDOWN:  (key: TSDL_KeyboardEvent);
      SDL_TEXTEDITING:  (edit: TSDL_TextEditingEvent);
      SDL_TEXTINPUT:  (text: TSDL_TextInputEvent);

      SDL_MOUSEMOTION:  (motion: TSDL_MouseMotionEvent);
      SDL_MOUSEBUTTONUP,
      SDL_MOUSEBUTTONDOWN:  (button: TSDL_MouseButtonEvent);
      SDL_MOUSEWHEEL:  (wheel: TSDL_MouseWheelEvent);
     
      SDL_JOYAXISMOTION:  (jaxis: TSDL_JoyAxisEvent);
      SDL_JOYBALLMOTION: (jball: TSDL_JoyBallEvent);
      SDL_JOYHATMOTION: (jhat: TSDL_JoyHatEvent);
      SDL_JOYBUTTONDOWN,
      SDL_JOYBUTTONUP: (jbutton: TSDL_JoyButtonEvent);
      SDL_JOYDEVICEADDED,
      SDL_JOYDEVICEREMOVED: (jdevice: TSDL_JoyDeviceEvent);

      SDL_CONTROLLERAXISMOTION: (caxis: TSDL_ControllerAxisEvent);
      SDL_CONTROLLERBUTTONUP,
      SDL_CONTROLLERBUTTONDOWN: (cbutton: TSDL_ControllerButtonEvent);
      SDL_CONTROLLERDEVICEADDED,
      SDL_CONTROLLERDEVICEREMOVED,
      SDL_CONTROLLERDEVICEREMAPPED: (cdevice: TSDL_ControllerDeviceEvent);

      SDL_AUDIODEVICEADDED,
      SDL_AUDIODEVICEREMOVED: (adevice: TSDL_AudioDeviceEvent);

      SDL_QUITEV: (quit: TSDL_QuitEvent);

      SDL_USEREVENT: (user: TSDL_UserEvent);
      SDL_SYSWMEVENT: (syswm: TSDL_SysWMEvent);

      SDL_FINGERDOWN,
      SDL_FINGERUP,
      SDL_FINGERMOTION: (tfinger: TSDL_TouchFingerEvent);
      SDL_MULTIGESTURE: (mgesture: TSDL_MultiGestureEvent);
      SDL_DOLLARGESTURE,SDL_DOLLARRECORD: (dgesture: TSDL_DollarGestureEvent);

      SDL_DROPFILE: (drop: TSDL_DropEvent);
  end;


  {* Function prototypes *}

  {**
   *  Pumps the event loop, gathering events from the input devices.
   *  
   *  This function updates the event queue and internal input device state.
   *  
   *  This should only be run in the thread that sets the video mode.
   *}
  procedure SDL_PumpEvents cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_PumpEvents' {$ENDIF} {$ENDIF};

const
  SDL_ADDEVENT = 0;
  SDL_PEEKEVENT = 1;
  SDL_GETEVENT = 2;

type
  TSDL_EventAction = Word;

  {**
   *  Checks the event queue for messages and optionally returns them.
   *
   *  If action is SDL_ADDEVENT, up to numevents events will be added to
   *  the back of the event queue.
   *
   *  If action is SDL_PEEKEVENT, up to numevents events at the front
   *  of the event queue, within the specified minimum and maximum type,
   *  will be returned and will not be removed from the queue.
   *
   *  If action is SDL_GETEVENT, up to numevents events at the front
   *  of the event queue, within the specified minimum and maximum type,
   *  will be returned and will be removed from the queue.
   *
   *  Result: The number of events actually stored, or -1 if there was an error.
   *
   *  This function is thread-safe.
   *}

  function SDL_PeepEvents(events: PSDL_Event; numevents: cint32; action: TSDL_EventAction; minType, maxType: TSDL_EventType): cint32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_PeepEvents' {$ENDIF} {$ENDIF};

  {**
   *  Checks to see if certain event types are in the event queue.
   *}

  function SDL_HasEvent(type_: TSDL_EventType): TSDL_Bool  cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasEvent' {$ENDIF} {$ENDIF};
  function SDL_HasEvents(minType, maxType: TSDL_EventType): TSDL_Bool cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_HasEvents' {$ENDIF} {$ENDIF};

  {**
   *  This function clears events from the event queue
   *}

  procedure SDL_FlushEvent(type_: TSDL_EventType) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_FlushEvent' {$ENDIF} {$ENDIF};
  procedure SDL_FlushEvents(minType, maxType: TSDL_EventType) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_FlushEvents' {$ENDIF} {$ENDIF};

  {**
   *  Polls for currently pending events.
   *
   *  1 if there are any pending events, or 0 if there are none available.
   *
   *  event - If not nil, the next event is removed from the queue and
   *               stored in that area.
   *}

  function SDL_PollEvent(event: PSDL_Event): cint32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_PollEvent' {$ENDIF} {$ENDIF};

  {**
   *  Waits indefinitely for the next available event.
   *  
   *  1, or 0 if there was an error while waiting for events.
   *   
   *  event - If not nil, the next event is removed from the queue and 
   *  stored in that area.
   *}

  function SDL_WaitEvent(event: PSDL_Event): cint32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_WaitEvent' {$ENDIF} {$ENDIF};

  {**
   *  Waits until the specified timeout (in milliseconds) for the next
   *  available event.
   *  
   *  1, or 0 if there was an error while waiting for events.
   *  
   *  event - If not nil, the next event is removed from the queue and
   *  stored in that area.
   *}
 
  function SDL_WaitEventTimeout(event: PSDL_Event; timeout: cint32): cint32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_WaitEventTimeout' {$ENDIF} {$ENDIF};

  {**
   *  Add an event to the event queue.
   *  
   *  1 on success, 0 if the event was filtered, or -1 if the event queue
   *  was full or there was some other error.
   *}

  function SDL_PushEvent(event: PSDL_Event): cint32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_PumpEvents' {$ENDIF} {$ENDIF};

type
  PSDL_EventFilter = ^TSDL_EventFilter;
  {$IFNDEF GPC}
    TSDL_EventFilter = function(userdata: Pointer; event: PSDL_Event): cint; cdecl;
  {$ELSE}
    TSDL_EventFilter = function( userdata: Pointer; event: PSDL_Event ): cint;
  {$ENDIF}

  {**
   *  Sets up a filter to process all events before they change internal state and
   *  are posted to the internal event queue.
   *
   *  If the filter returns 1, then the event will be added to the internal queue.
   *  If it returns 0, then the event will be dropped from the queue, but the 
   *  internal state will still be updated.  This allows selective filtering of
   *  dynamically arriving events.
   *
   *  Be very careful of what you do in the event filter function, as 
   *  it may run in a different thread!
   *  
   *  There is one caveat when dealing with the SDL_QUITEVENT event type.  The
   *  event filter is only called when the window manager desires to close the
   *  application window.  If the event filter returns 1, then the window will
   *  be closed, otherwise the window will remain open if possible.
   *
   *  If the quit event is generated by an interrupt signal, it will bypass the
   *  internal queue and be delivered to the application at the next event poll.
   *}
 
  procedure SDL_SetEventFilter(filter: TSDL_EventFilter; userdata: Pointer) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_SetEventFilter' {$ENDIF} {$ENDIF};

  {**
   *  Return the current event filter - can be used to "chain" filters.
   *  If there is no event filter set, this function returns SDL_FALSE.
   *}

  function SDL_GetEventFilter(var filter: PSDL_EventFilter; var userdata: PPointer): TSDL_Bool cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_GetEventFilter' {$ENDIF} {$ENDIF};

  {**
   *  Add a function which is called when an event is added to the queue.
   *}
 
  procedure SDL_AddEventWatch(filter: TSDL_EventFilter; userdata: Pointer) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_AddEventWatch' {$ENDIF} {$ENDIF};

  {**
   *  Remove an event watch function added with SDL_AddEventWatch()
   *}
 
  procedure SDL_DelEventWatch(filter: TSDL_EventFilter; userdata: Pointer) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_DelEventWatch' {$ENDIF} {$ENDIF};

  {**
   *  Run the filter function on the current event queue, removing any
   *  events for which the filter returns 0.
   *}

  procedure SDL_FilterEvents(filter: TSDL_EventFilter; userdata: Pointer) cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_FilterEvents' {$ENDIF} {$ENDIF};

const

  SDL_QUERY   =   -1;
  SDL_IGNORE  =    0;
  SDL_DISABLE =    0;
  SDL_ENABLE  =  1;

  {**
   *  This function allows you to set the state of processing certain events.
   *   - If state is set to SDL_IGNORE, that event will be automatically
   *     dropped from the event queue and will not event be filtered.
   *   - If state is set to SDL_ENABLE, that event will be processed
   *     normally.
   *   - If state is set to SDL_QUERY, SDL_EventState() will return the
   *     current processing state of the specified event.
   *}

  function SDL_EventState(type_: TSDL_EventType; state: cint32): cuint8 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_EventState' {$ENDIF} {$ENDIF};

  function SDL_GetEventState(type_: TSDL_EventType): cuint8;

  {**
   *  This function allocates a set of user-defined events, and returns
   *  the beginning event number for that set of events.
   *
   *  If there aren't enough user-defined events left, this function
   *  returns (Uint32)-1
   *}

  function SDL_RegisterEvents(numevents: cint32): cuint32 cdecl; external SDL_LibName {$IFDEF DELPHI} {$IFDEF MACOS} name '_SDL_RegisterEvents' {$ENDIF} {$ENDIF};
