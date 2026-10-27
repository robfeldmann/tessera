# ``TesseraRuntime``

The application contract that Tessera's hosts drive.

## Overview

``Application`` is the one declaration this module makes: a reference type that owns its model and describes its interface as a view. A host, such as the developer-tools harness, constructs an application, renders its `body`, and delivers input events to it.

Import `Tessera` to adopt it: `Tessera` re-exports this module, so one import declares a conforming type.

## Topics

### The application contract

- ``Application``
