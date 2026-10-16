# Networking and protocols

This document covers the code that client and servers share for talking
to each other:

- **FSO.Server.Protocol** (`TSOClient/FSO.Server.Protocol`): packet
  definitions and the Mina.NET codec for the binary protocols.
- **FSO.Server.Clients** (`TSOClient/FSO.Server.Clients`): the client
  side of the HTTP services and the TCP connection.
- **FSO.Common.DataService** (`TSOClient/FSO.Server.DataService`): the
  data service, which keeps avatars, lots, and the city in sync.
- **FSO.Common.DatabaseService** (`TSOClient/FSO.Common.DatabaseService`):
  request and response wrappers for database queries over the wire.
- **FSO.Common.Domain** (`TSOClient/FSO.Common.Domain`): small domain
  services both sides use, such as lot pricing and the shard list.

FreeSO kept TSO's own protocol names and much of its wire format, so the
original game client could in principle talk to these servers. The
server README says the API matches the Maxis protocol for login and shard
selection.

## How it works (2017)

### Two transports

1. **HTTP** for login and city selection. [`AuthClient`](../../TSOClient/FSO.Server.Clients/AuthClient.cs)
   and [`CityClient`](../../TSOClient/FSO.Server.Clients/CityClient.cs) use
   RestSharp. Responses are XML in TSO's original formats (the types in
   `CitySelector/`).
2. **TCP** for everything in game, framed by **Aries** and carried by
   Mina.NET. [`AriesClient`](../../TSOClient/FSO.Server.Clients/AriesClient.cs)
   is the client end. The client keeps two: one named `City` and one named
   `Lot` (see `NetworkModule` in the client).

### Logging in

| Step | Call | Result |
| --- | --- | --- |
| 1 | `AuthLogin` on the game entry URL (`GlobalSettings.GameEntryUrl`), with user name and password as query parameters | An auth ticket. |
| 2 | `cityselector/app/InitialConnectServlet` | Checks the client version; can require an update. |
| 3 | `cityselector/app/AvatarDataServlet` | The account's avatars. |
| 4 | `cityselector/shard-status.jsp` | City (shard) list and status. |
| 5 | `cityselector/app/ShardSelectorServlet` | The chosen city's address and a one-time shard ticket. |
| 6 | TCP connect to the city server | Server sends Aries `RequestClientSession`. |
| 7 | Client sends `RequestClientSessionResponse` | Its `Password` field carries the shard ticket. The server looks it up, deletes it, and claims the avatar for this session. |

After step 7 the session is authenticated and may send Voltron and
Electron packets. `AbstractAriesServer.MessageReceived` rejects anything
else before that point. The client drives these steps with state machines
called regulators (see [client.md](./client.md#regulators)).

Joining a lot repeats the idea: the client sends Electron
`FindLotRequest` to the city server, which picks a lot server and answers
with `FindLotResponse` (address and ticket). The client then opens the
`Lot` Aries connection and authenticates the same way.

### Aries framing

[`AriesProtocolDecoder`](../../TSOClient/FSO.Server.Protocol/Aries/AriesProtocolDecoder.cs)
reads a 12-byte little-endian header: packet type, timestamp, payload
size. Then:

| Aries type | Payload |
| --- | --- |
| 0 | One or more **Voltron** packets |
| 1000 | One or more **Electron** packets |
| 1001 | One or more **Gluon** packets |
| 21, 22, 1002 to 1005 | Aries session and challenge packets |

Voltron-style payloads are a sequence of big-endian sub-packets, each a
16-bit type and a 32-bit size (including its 6-byte header). The packet
class is found by type code and created with `Activator.CreateInstance`,
then fills itself through `IoBufferDeserializable.Deserialize`.

### Packet families

| Family | Folder | Used between | Purpose |
| --- | --- | --- | --- |
| Aries | [`Aries/Packets`](../../TSOClient/FSO.Server.Protocol/Aries/Packets/) | all | Session setup and challenge-response. |
| Voltron | [`Voltron/Packets`](../../TSOClient/FSO.Server.Protocol/Voltron/Packets/) | client and city | TSO's original messages: chat, find player, ignore list, announcements, and the data service and database wrappers. `VoltronPacketType` lists about 780 lines of original TSO type codes, most not implemented. |
| Electron | [`Electron/Packets`](../../TSOClient/FSO.Server.Protocol/Electron/Packets/) | client and city or lot | FreeSO's own messages: create a Sim, find and purchase lots, roommates, instant messages, moderation, and the VM transport (`FSOVMCommand`, `FSOVMTickBroadcast`, `FSOVMDirectToClient`, `FSOVMProtocolMessage`). |
| Gluon | [`Gluon/Packets`](../../TSOClient/FSO.Server.Protocol/Gluon/Packets/) | server and server | Health pings, lot capacity, task requests, claim transfers, shard shutdown, and lot client termination. |

Lot simulation traffic is the bytes produced by the SimAntics net
drivers (see [simantics.md](./simantics.md#multiplayer-deterministic-lockstep)),
wrapped in the `FSOVM*` Electron packets.

### Server-to-server authentication

Gluon connections authenticate with a challenge-response in
[`ChallengeResponse`](../../TSOClient/FSO.Server.Protocol/Utils/ChallengeResponse.cs):
the host sends a random salt and an iteration count (4,000 to 5,000), and
the caller answers with PBKDF2 (`Rfc2898DeriveBytes`, SHA-1) over the
shared secret, followed by HMAC-SHA1.

### TLS

[`SslClientFilter`](../../TSOClient/FSO.Server.Protocol/Utils/SslClientFilter.cs)
is a custom Mina TLS filter. It authenticates the server against the
hard-coded host name `auth.east.ea.com` (the original EA server). In
`AriesClient.Connect` the lines that add it are commented out, so the client connects in plain text. The server
adds Mina's `SslFilter` with `SslProtocols.Tls` (TLS 1.0) only when a
certificate is configured. In practice the game traffic, including the
shard ticket, is not encrypted.

### The data service

[`DataService`](../../TSOClient/FSO.Server.DataService/DataService.cs) is a
typed, observable cache of game objects (`Avatar`, `Lot`, `City`,
`Relationship`, `Bookmark`, and others in `Model/`), shared by client
and server:

- The model is defined by TSO's `datadefinition.dat`
  ([`TSODataDefinition`](../../TSOClient/tso.files/formats/tsodata/TSODataDefinition.cs)):
  structs, fields, and "derived structs" (masked subsets of fields,
  `MaskedStruct`) that say which fields are sent in which situation.
- Each C# model class is marked with `[DataServiceModel]` and its
  properties with attributes such as `[Key]`, `[Persist]`, and
  `[ClientSourced]`. `DataServiceModelTypeSerializer` uses reflection to
  map properties to struct fields by name.
- Providers fetch objects: on the server from the database
  (`EagerDataServiceProvider`, `LazyDataServiceProvider`), on the client
  from server updates (`ReceiveOnlyServiceProvider`, for example
  `ClientAvatarProvider`).
- Changes travel as `cTSOTopicUpdateMessage`s inside
  `DataServiceWrapperPDU`. `DataService.ApplyUpdate` checks the sender
  through an `ISecurityContext` before applying them.
- Model classes implement `INotifyPropertyChanged`, and the client UI
  binds to them by dotted path (see [common.md](./common.md#utilities)).

### The database service

[`DatabaseService`](../../TSOClient/FSO.Common.DatabaseService/DatabaseService.cs)
sends `DBRequestWrapperPDU` requests (top 100 lists, load avatar by ID,
search) and returns a `Task<T>` that completes when the matching response
arrives, matched by message ID. `DBRequestType` and `DBResponseType` list
TSO's original request codes.

### Serialization

All binary packets use Mina.NET's `IoBuffer` with the `cTSO*` serializers
from [FSO.Common](./common.md#wire-serialization).
[`cTSOSerializer`](../../TSOClient/FSO.Server.Protocol/Voltron/DataService/cTSOSerializer.cs)
is created eagerly as a singleton, because packets look it up statically
instead of through dependency injection.

## Modern .NET rewrite

### Keep the wire format, replace the plumbing

The packet layouts are the compatibility surface between client, city,
and lot servers. Keep them byte-for-byte, and replace the libraries
around them:

| 2017 | Replacement |
| --- | --- |
| Mina.NET (forked) `IoBuffer`, filters, codecs | `System.IO.Pipelines` with `SequenceReader<byte>` for decoding and `IBufferWriter<byte>` for encoding |
| `AsyncSocketConnector` and acceptors | `Socket` with `ConnectAsync`/`AcceptAsync`, or Kestrel's connection middleware (`UseConnectionHandler<T>`) on the server |
| Custom `SslClientFilter`, Mina `SslFilter` | `SslStream` over the socket, TLS 1.2 or 1.3 |
| RestSharp | `HttpClient` from `IHttpClientFactory`, with `System.Xml.Serialization` or `XDocument` for the XML responses |
| `Activator.CreateInstance` by packet code | A static table of factory delegates or a source generator |
| Ninject-resolved serializer singletons | Services registered in `Microsoft.Extensions.DependencyInjection` |

### Security fixes the rewrite must include

- **Turn on TLS.** Make TLS mandatory for client-to-server and
  server-to-server connections, and validate the certificate against the
  configured server host name, not a hard-coded one.
- **Credentials out of URLs.** `AuthClient` puts the password in the
  query string, where web server and proxy logs record it. Send it in a
  POST body over HTTPS. (The HTTP base URL defaults to `https://` in
  `NetworkModule`.)
- **Bound frame sizes.** The decoder trusts the 32-bit payload size and
  waits for that many bytes. An inner Voltron size below 6 underflows the
  `uint`. Reject frames over a configured maximum and any inner size
  below its header, and close the connection.
- **Gluon secret.** PBKDF2 with SHA-1 and 4,000 iterations is weak by
  current standards. Inside a private network, mutual TLS between servers
  is simpler and stronger.
- **Tickets.** Shard and lot tickets are bearer tokens. Keep them
  single-use (they already are) and short-lived, and send them only over
  TLS.

### Data service

- Replace reflection over attributes with a source generator that emits
  a serializer per model class. That's faster, works with trimming and
  native AOT, and fails at build time when a property doesn't match a
  struct field.
- Keep `datadefinition.dat` as the source of field IDs if compatibility
  with TSO's wire format matters. Otherwise generate the definition from
  the C# models and drop the file dependency.

### Tests

The protocol is the easiest place to get strong tests:

- Round-trip every packet type (serialize, then deserialize, then
  compare).
- Feed the decoder split and merged buffers to check framing.
- Feed it malformed headers (huge sizes, short inner sizes) and check it
  closes the connection rather than allocating or throwing.
