// Deliberate plan 035 Step 2.3 probe: compiles only on Swift 6.4. Reverted after CI shows
// the baseline legs failing and the 6.4 legs passing.
#if compiler(<6.4)
  #error("plan 035 Step 2.3 probe: this construct needs Swift 6.4")
#endif
