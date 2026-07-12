# An Actuel branded Christmas Light Strip controller

## Prerequisities

* typescript
* ts-node
* yarn
* an Actuel branded Christmas Light Stript with RGB diodes (no white-only diodes!)

## Run

```shell
$ git clone https://github.com/Zoltan-Balazs/Christmas-RGB-Lights.git
$ yarn install
$ yarn start
```

## In case the device's bluetooth connection is stuck:

```shell
$ yarn destuck
```

## Mobile app

`app/` has a Flutter companion app (Android + iOS) that talks to the same
BLE strip. See `app/README.md`, and `app/ios/README-sideload.md` for
building/sideloading on iOS from NixOS.
