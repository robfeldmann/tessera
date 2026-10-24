# ``TesseraRuntime``

The application contract that Tessera's hosts drive.

## Overview

``Application`` is the one declaration this module makes today: a reference type that owns its model and describes its interface as a view. Hosts, such as the application runtime that arrives with Phase 5 and the developer-tools harness, construct an application, render its `body`, and deliver input events to it.

Import `Tessera` to adopt it: `Tessera` re-exports this module, so one import declares a conforming type.

## Topics

### The application contract

- ``Application``
