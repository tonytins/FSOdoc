# `feature/server-rebuild`: the modern server (August 2015 – May 2017)

**Status:** merged; part of the snapshot. The branch reached master in pull request #62
(May 16, 2017) with 266 commits: 148 by ddfczm, 95 by RHY3756547, 22 by TheArchitectFreeSO, and one
by mitja. Its later pull requests (#63, #64) carried only fixes to two EOD plugins.

## What it built

This branch built the server architecture the snapshot has, from an empty project up: separate city, lot, API, and task servers sharing a
database, speaking TSO's own protocols (Aries, Voltron, the data service) closely enough for the
client's original UI flows to work. [server.md](../server.md) and [protocol.md](../protocol.md)
describe the result; this page covers how it came together.

### 2015: foundations (ddfczm)

- **Project setup:** Ninject for dependency injection, Dapper for database access, NLog for
  logging, Mina.NET for networking, Newtonsoft for JSON, CommandLineParser for switches.
- **Accounts:** password hashing, an auth controller, admin JWT tokens, all over an HTTP API built
  on Nancy.
- **Login flow:** the initial connect servlet, shard (city) selection, connecting to the city, and
  a debugging UI for network traffic.
- **The data service:** the `DataServiceWrapperPDU` serializer, rebuilt to handle arrays and nested
  structs, then wired into the client with data binding, so UI fields update when server data does.
- **Characters and lots:** CAS writes avatars to the database; person pages and avatar search; lot
  purchase and renaming; lot tooltips from server data.
- **Lot hosting:** lot-to-city negotiation, a background-processing setup on lot servers, and
  "claims" so an avatar or lot is held by one server at a time (logging in twice logs the first
  session out).
- **Content without packing slips:** a refactor so the content system no longer needs generated
  XML files.

### 2016–2017: the city comes alive (RHY3756547, ddfczm)

- **City data service** and improved lot connections; thread-safe immutable lists in the data
  service.
- **EODs** (the custom object UIs): a lobby system, Paper Chase, double-tall panels, a single-user
  archetype; dressers and store racks with try-on; later Band, Timer, War Game, Trunk, Game Comp
  Draw a Card, and server-side slot machines (TheArchitectFreeSO).
- **Top 100 and bonuses:** a general task server, top 100 lot calculation in SQL, daily property
  and visitor bonuses, and their dialogs.
- **Client polish:** bookmarks, the house button with cached lot thumbnails, recorded lot visits,
  job lot balancing, top 100 filters.
- **Operations:** a shared server secret, user registration (throttled to one per day), the
  updater and patcher, and the "Room-map refactor" and push-tail interaction mode in the VM.

## In the snapshot

Everything above is the snapshot's server. NSOClient doesn't port the server (it isn't engine-free),
but the protocol and data service it defines are what any NSOClient-based client would need to
talk to a FreeSO server.
