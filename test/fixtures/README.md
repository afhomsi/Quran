# Test fixtures

`tanzil_simple_clean.json.gz` is the Quran text in plain spelling without
harakat ("simple clean"), one string per ayah, 6236 in all. The recitation
tests use it to stand in for what a speech recognizer writes.

It comes from the Tanzil project and is used under the Creative Commons
Attribution 3.0 license, unchanged:

> Tanzil Quran Text (Simple Clean), Copyright (C) 2007-2025 Tanzil Project.
> License: Creative Commons Attribution 3.0.
> This copy of the Quran text is carefully produced, highly verified and
> continuously monitored by a group of specialists in Tanzil Project.
> Source: https://tanzil.net

It was taken from the npm package `@ghoran/text`, which bundles the same
Tanzil text.
