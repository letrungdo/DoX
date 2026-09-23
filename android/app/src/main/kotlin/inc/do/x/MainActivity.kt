package vn.dox.app

import com.ryanheise.audioservice.AudioServiceActivity

// AudioServiceActivity rather than FlutterActivity: the Music page keeps
// playing in the background through audio_service, whose media service and
// this activity have to share one Flutter engine.
class MainActivity : AudioServiceActivity()
